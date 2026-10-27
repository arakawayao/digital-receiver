"""Receiver services; Qt signals mediate all commands from the view."""
from collections import deque
from dataclasses import asdict, replace
import queue
import json
from pathlib import Path
import threading
import time

import numpy as np
from PyQt6.QtCore import QObject, QThread, QTimer, pyqtSignal, pyqtSlot

from .audio import AudioOutput
from .dsp import (AUDIO_RATE, DEMODULATION_MODES, FM_DEEMPHASIS_OPTIONS,
                  Demodulator, Measurement, analyse, spectrum)
from .protocol import ADC_RATE, IQ_RATE, Continuity, Decoder, Frame
from .records import save_capture
from .sources import Acquisition
from .tuning import MODE_NAMES, TuningSession

PROCESS_BLOCK_SAMPLES = 20_000


class ReceiveRouter(threading.Thread):
    """Keep control replies flowing while the bounded DSP queue is busy."""
    def __init__(self, ingress, source, decoder, tuning):
        super().__init__(name="ads807-receive-router", daemon=True)
        self.ingress, self.source = ingress, source
        self.decoder, self.tuning = decoder, tuning
        # 512 * 32 KiB is about 4.6 s at 500 kIQ/s; bounded so a stalled
        # DSP cannot grow memory without limit while normal FFT jitter is absorbed.
        self.batches = queue.Queue(maxsize=512)
        self.stop_event = threading.Event()
        self.error = ""
        self.dropped_bytes = 0
        self.dropped_samples = 0
        self.pending_gap = False
        self.decode_timing = (0, 0.0, 0.0, 0.0)

    def route(self, data):
        started = time.perf_counter(), time.thread_time()
        frames = self.decoder.feed(data)
        wall, cpu = time.perf_counter()-started[0], time.thread_time()-started[1]
        calls, total_wall, total_cpu, maximum = self.decode_timing
        self.decode_timing = calls+1, total_wall+wall, total_cpu+cpu, max(maximum, wall)
        if not frames:
            return
        for frame in frames:
            if self.tuning:
                self.tuning.offer(frame)
        marked = False
        if self.pending_gap:
            for index, frame in enumerate(frames):
                if isinstance(frame, Frame):
                    frames[index] = replace(frame, transport_gap=True)
                    marked = True
                    break
        try:
            self.batches.put_nowait(frames)
            if marked:
                self.pending_gap = False
        except queue.Full:
            self.dropped_bytes += sum(len(frame.raw) for frame in frames)
            self.dropped_samples += sum(frame.count for frame in frames if isinstance(frame, Frame))
            self.pending_gap = True

    def run(self):
        try:
            while not self.stop_event.is_set():
                try:
                    data = self.ingress.get(timeout=.05)
                except queue.Empty:
                    if self.source.ended:
                        break
                    continue
                self.route(data)
        except Exception as error:
            self.error = str(error)


class Processing(QThread):
    def __init__(self, ingress, source, audio):
        super().__init__()
        self.ingress, self.source, self.audio_output = ingress, source, audio
        self.stop_event = threading.Event()
        self.lock = threading.Lock()
        self.decoder, self.continuity = Decoder(), Continuity()
        self.demodulator = Demodulator()
        self.demodulation_mode = "auto"
        self.active_demodulation_mode = "auto"
        self.demodulation = {"mode": "auto", "kind": None, "forced": False}
        self.deemphasis = 0
        self.fft_size = 8192
        self.history = deque(maxlen=100)
        self.raw = deque(maxlen=9000)
        self.pending = []
        self.pending_count = 0
        self.result = Measurement()
        self.current_kind = "无有效信号"
        self.candidate = None
        self.candidate_count = 0
        self.classification_holds = 0
        self.latest = None
        self.latest_version = 0
        self.last_valid = 0.0
        self.error = ""
        self.processed = 0
        self.started = time.monotonic()
        self.recoveries = 0
        self.epoch = 0
        self.last_header = None
        self.stale = False
        self.stage_timing = {}
        self.next_analysis = 0.0
        self.analysis_interval = .1
        self.spectral_view = (np.empty(0), np.empty(0))
        self.tuning = TuningSession(source) if source.config.mode == "USB" and source.config.usb_protocol == "TRI1" else None
        self.receiver = ReceiveRouter(ingress, source, self.decoder, self.tuning)

    def request_stop(self):
        self.stop_event.set()
        if self.tuning:
            self.tuning.stop_event.set()

    def reset_segment(self):
        self.pending.clear()
        self.pending_count = 0
        self.demodulator.reset()
        self.current_kind = "无有效信号"
        self.candidate = None
        self.candidate_count = 0
        self.audio_output.clear(reason="segment_reset")
        self.next_analysis = 0.0
        self.spectral_view = (np.empty(0), np.empty(0))
        with self.lock:
            self.history.clear()
            self.raw.clear()
            self.latest = None
            self.latest_version += 1

    def run(self):
        import os
        profile_path = os.environ.get("ADS807_PROCESSING_PROFILE")
        profile = None
        if profile_path:
            import cProfile
            profile = cProfile.Profile()
            profile.enable()
        try:
            self.receiver.start()
            if self.tuning:
                self.tuning.start()
            while not self.stop_event.is_set():
                if self.receiver.error or self.source.error:
                    raise RuntimeError(self.receiver.error or self.source.error)
                if self.tuning and self.tuning.error:
                    raise RuntimeError(self.tuning.error)
                try:
                    decoded = self.receiver.batches.get(timeout=.1)
                except queue.Empty:
                    replay_done = self.source.config.mode == "文件回放" and self.source.ended
                    if self.last_valid and time.monotonic()-self.last_valid > .6 and not self.stale and not replay_done:
                        self.reset_segment()
                        self.result = Measurement(reason="有效帧超时 / 失锁 / 断连")
                        self.stale = True
                    continue
                for frame in decoded:
                    if not isinstance(frame, Frame):
                        with self.lock:
                            self.raw.append(frame.raw)
                        continue
                    if self.continuity.accept(frame):
                        self.reset_segment()
                        self.recoveries += 1
                    self.stale = False
                    self.last_valid = time.monotonic()
                    self.epoch = frame.epoch
                    self.last_header = frame
                    with self.lock:
                        self.raw.append(frame.raw)
                    skip = (frame.count if frame.transient else 0) if frame.protocol == "TRI1" else (max(0, 66-frame.index) if frame.transient else 0)
                    samples = frame.samples[skip:]
                    if not len(samples):
                        continue
                    self.pending.append((frame.index+skip, samples, frame.clipped))
                    self.pending_count += len(samples)
                    if self.pending_count >= PROCESS_BLOCK_SAMPLES:
                        stage_start = time.perf_counter(), time.thread_time()
                        self.process_pending(frame)
                        self.record_stage("dsp", stage_start)
        except Exception as error:
            self.error = str(error)
        finally:
            if self.tuning:
                self.tuning.stop_event.set()
                self.tuning.join(2.5)
                self.error = self.error or self.tuning.error
            self.receiver.stop_event.set()
            self.receiver.join()
            if self.error:
                self.reset_segment()
                self.result = Measurement(reason=self.error)
                self.stale = True
            self.source.stop()
            if profile is not None:
                profile.disable()
                profile.dump_stats(profile_path)

    def record_stage(self, name, started):
        wall = time.perf_counter()-started[0]
        cpu = time.thread_time()-started[1]
        previous = self.stage_timing.get(name, (0, 0.0, 0.0, 0.0))
        self.stage_timing[name] = (previous[0]+1, previous[1]+wall, previous[2]+cpu,
                                   max(previous[3], wall))

    def process_pending(self, frame):
        mode = self.demodulation_mode
        if mode != self.active_demodulation_mode:
            self.demodulator.reset()
            self.audio_output.clear(reason="demodulation_mode_change")
            with self.lock:
                self.history.clear()
                self.latest = None
            self.active_demodulation_mode = mode
            self.next_analysis = 0.0
        indices = np.concatenate([np.arange(p[0], p[0]+len(p[1]), dtype=np.int64) for p in self.pending])
        samples = np.concatenate([p[1] for p in self.pending])
        z = (samples[:, 0].astype(np.float64) + 1j*samples[:, 1])/32768
        clipped = any(p[2] for p in self.pending)
        self.pending.clear()
        self.pending_count = 0
        lo = 87_000_000 + frame.phase_step*ADC_RATE/2**32
        now = time.perf_counter()
        if clipped or self.candidate_count < 3 or now >= self.next_analysis:
            self.measure(z, lo, clipped)
            self.spectral_view = spectrum(z, nfft=self.fft_size)
            self.next_analysis = now+self.analysis_interval
        result = self.result
        self.demodulator.deemphasis = self.deemphasis
        kind = result.kind if mode == "auto" else mode
        if not np.isfinite(z).all():
            kind = "无有效信号"
        audio = self.demodulator.process(z, kind)
        demodulation = {"mode": mode, "kind": kind, "forced": mode != "auto"}
        self.audio_output.push(audio)
        freq, power = self.spectral_view
        self.processed += len(z)
        with self.lock:
            self.demodulation = demodulation
            self.history.append((indices, z, audio))
            self.latest = {"measurement": result.to_dict(), "demodulation": demodulation,
                           "freq": freq, "power": power}
            self.latest_version += 1

    def measure(self, z, lo, clipped):
        result = analyse(z, lo, clipped)
        candidate = result.kind
        if self.candidate == candidate:
            self.candidate_count += 1
        else:
            self.candidate, self.candidate_count = candidate, 1
        if candidate in ("未知", "无有效信号") or self.candidate_count >= 3:
            if self.current_kind != candidate and self.active_demodulation_mode == "auto":
                self.audio_output.clear(reason="classification_change")
                with self.lock:
                    self.history.clear()
            self.current_kind = candidate
        if self.current_kind != result.kind:
            if self.current_kind in ("AM", "FM") and candidate in ("AM", "FM"):
                # Preserve filter continuity until a different valid modulation
                # is confirmed. Unknown, clipping and signal loss never hold.
                self.classification_holds += 1
                result = Measurement(kind=self.current_kind, confidence=0.0,
                                     reason=f"候选 {candidate} {self.candidate_count}/3；保持 {self.current_kind} 解调，参数待确认",
                                     level_dbfs=result.level_dbfs, occupied_hz=result.occupied_hz)
            else:
                result = Measurement(kind="未知", reason="调制识别稳定性确认中", level_dbfs=result.level_dbfs)
        self.result = result

    def stats(self):
        audio = self.audio_output.snapshot()
        return {"frames": self.decoder.frames, "bytes": self.source.total_bytes,
                "crc_errors": self.decoder.crc_errors, "header_errors": self.decoder.header_errors,
                "discarded_bytes": self.decoder.discarded_bytes,
                "continuity_gaps": self.continuity.gaps, "missing_samples": self.continuity.missing_samples,
                "epoch_changes": self.continuity.epoch_changes, "index_wraps": self.continuity.index_wraps,
                "clipped_frames": self.continuity.clipped_frames,
                "fpga_dropped": self.last_header.dropped if self.last_header else 0,
                "queue_dropped_bytes": self.source.queue_dropped_bytes+self.receiver.dropped_bytes,
                "source_queue_dropped_bytes": self.source.queue_dropped_bytes,
                "dsp_queue_dropped_bytes": self.receiver.dropped_bytes,
                "queue_depth": self.ingress.qsize(), "queue_capacity": self.ingress.maxsize,
                "dsp_queue_depth": self.receiver.batches.qsize(),
                "dsp_queue_capacity": self.receiver.batches.maxsize,
                "dsp_dropped_samples": self.receiver.dropped_samples,
                "audio_underruns": audio["underruns"],
                "audio_overruns": audio["overruns"],
                "audio_device_errors": audio["device_errors"],
                "audio_device_status": audio["device_status"],
                "audio_output_enabled": audio["enabled"],
                "audio_startup_silence_frames": audio["startup_silence_frames"],
                "audio_buffer_ms": audio["buffer_ms"],
                "audio_prebuffer_ms": audio["prebuffer_ms"],
                "audio_diagnostics": audio,
                "audio_counter_scope": "acquisition_session",
                "elapsed_s": time.monotonic()-self.started,
                "last_valid_age_s": time.monotonic()-self.last_valid if self.last_valid else None,
                "decoder_message": self.decoder.last_error, "epoch": self.epoch,
                "source": self.source.config.mode, "source_error": self.source.error,
                "processing_error": self.error,
                "analysis_interval_s": self.analysis_interval,
                "demodulation": dict(self.demodulation),
                "classification": {"confirmed": self.current_kind, "candidate": self.candidate,
                                   "candidate_count": self.candidate_count,
                                   "held_analyses": self.classification_holds},
                "processing_timing": {name: dict(calls=value[0], wall_s=value[1], cpu_s=value[2], max_wall_ms=value[3]*1000)
                                      for name, value in dict(self.stage_timing, decode=self.receiver.decode_timing).items()},
                "transport_gaps": self.decoder.transport_gaps,
                "usb_timing": self.source.usb_timing.snapshot() if self.source.usb_timing is not None else None,
                "tuning": self.tuning.view() if self.tuning else self.replay_tuning()}

    def replay_tuning(self):
        if self.last_header and self.source.config.mode == "USB" and self.source.config.usb_protocol == "RPL1":
            h = self.last_header
            return {"message": "FPGA 自主估频 / USB RAM 回放", "mode": 1,
                    "tuned_rf": h.rf_hz, "flags": 0x301, "epoch": h.epoch,
                    "config_id": 0, "estimated_rf": h.rf_hz}
        if self.last_header and self.last_header.protocol == "TRI1":
            h = self.last_header
            return {"message": "文件回放（不发送控制）", "mode": h.flags & 3,
                    "tuned_rf": h.rf_hz, "flags": h.flags, "epoch": h.epoch,
                    "config_id": h.config_id, "estimated_rf": h.estimated_rf}
        return {"message": "旧格式回放 / 合成数据", "mode": None, "tuned_rf": 0, "flags": 0}

    def display(self, window_ms):
        with self.lock:
            if not self.history or self.latest is None:
                return None
            keep = max(1, int(window_ms*IQ_RATE/1000))
            blocks = list(self.history)[-min(len(self.history), int(keep/10_000)+2):]
            z = np.concatenate([b[1] for b in blocks])[-keep:]
            indices = np.concatenate([b[0] for b in blocks])[-keep:]
            audio = np.concatenate([b[2] for b in blocks])[-round(keep*AUDIO_RATE/IQ_RATE):]
            return {**self.latest, "iq": z, "indices": indices, "audio": audio,
                    "version": self.latest_version}

    def capture(self):
        with self.lock:
            if not self.history:
                raise ValueError("没有可保存的连续数据")
            blocks = list(self.history)
            return {"iq": np.concatenate([b[1] for b in blocks]),
                    "indices": np.concatenate([b[0] for b in blocks]),
                    "audio": np.concatenate([b[2] for b in blocks]),
                    "raw": b"".join(self.raw), "measurement": self.result.to_dict(),
                    "source": self.source.config.mode, "stats": self.stats(),
                    "source_config": asdict(self.source.config),
                    "transport_config": {"protocol": self.last_header.protocol,
                                         "version": 1 if self.last_header.protocol == "TRI1" else 2,
                                         "adc_rate_hz": self.last_header.adc_rate,
                                         "iq_rate_hz": self.last_header.iq_rate,
                                         "cic_shift": self.last_header.shift,
                                         "flags": self.last_header.flags,
                                         "rf_setting_hz": self.last_header.rf_hz,
                                         "estimated_rf_hz": self.last_header.estimated_rf,
                                         "config_id": self.last_header.config_id,
                                         "phase_step": self.last_header.phase_step,
                                         "last_sequence": self.last_header.sequence},
                    "epoch": self.epoch, "deemphasis": self.deemphasis,
                    "demodulation": dict(self.demodulation)}


class SaveJob(QThread):
    saved = pyqtSignal(str)
    failed = pyqtSignal(str)

    def __init__(self, parent_path, processor):
        super().__init__()
        self.parent_path, self.processor = parent_path, processor

    def run(self):
        try:
            path = save_capture(self.parent_path, self.processor.capture())
            self.saved.emit(str(path))
        except Exception as error:
            self.failed.emit(str(error))


class AudioJob(QThread):
    failed = pyqtSignal(str)

    def __init__(self, output, enabled, device):
        super().__init__()
        self.output, self.enabled, self.device = output, enabled, device

    def run(self):
        try:
            if self.enabled:
                self.output.start(self.device)
            else:
                self.output.stop()
        except Exception as error:
            self.failed.emit(str(error))


class RecordScan(QThread):
    scanned = pyqtSignal(object)

    def __init__(self, path):
        super().__init__()
        self.path = Path(path)

    def run(self):
        rows = []
        try:
            paths = sorted(self.path.glob("capture_*/metadata.json"), reverse=True)[:300]
            for path in paths:
                try:
                    data = json.loads(path.read_text(encoding="utf-8"))
                    m = data.get("measurement", {})
                    carrier = m.get("carrier_hz")
                    modulation = m.get("kind", "未知")
                    demodulation = data.get("demodulation", {})
                    if demodulation.get("forced"):
                        modulation += " / " + DEMODULATION_MODES.get(demodulation.get("mode"), "强制解调")
                    rows.append({"values": [data.get("saved_at", ""), modulation,
                                           f"{carrier/1e6:.6f}" if carrier is not None else "—",
                                           data.get("source", "")], "path": str(path.parent/"transport.fcr")})
                except (OSError, ValueError, TypeError):
                    continue
        except OSError:
            pass
        self.scanned.emit(rows)


class DeviceScan(QThread):
    scanned = pyqtSignal(object)
    failed = pyqtSignal(str)

    def run(self):
        try:
            import sounddevice as sd
            apis = sd.query_hostapis()
            self.scanned.emit([(i, f"{d['name']} [{apis[d['hostapi']]['name']}]")
                               for i, d in enumerate(sd.query_devices()) if d["max_output_channels"]])
        except Exception as error:
            self.failed.emit(str(error))


class Controller(QObject):
    display_ready = pyqtSignal(object)
    stats_ready = pyqtSignal(object)
    state_changed = pyqtSignal(str)
    log = pyqtSignal(str)
    saved = pyqtSignal(str)
    audio_changed = pyqtSignal(bool)
    ready_to_close = pyqtSignal()
    records_ready = pyqtSignal(object)
    devices_ready = pyqtSignal(object)

    def __init__(self):
        super().__init__()
        self.source = self.processor = None
        self.save_job = self.audio_job = None
        self.record_scan = self.device_scan = None
        self.audio = AudioOutput()
        self.window_ms = 20
        self.fft_size = 8192
        self.deemphasis = 0
        self.demodulation_mode = "auto"
        self.paused = False
        self.stopping = False
        self.closing = False
        self.pending_config = None
        self.state = "就绪"
        self.last_stats = {}
        self.last_error = ""
        self.last_integrity = (0, 0, 0, 0, 0, 0)
        self.last_integrity_log = 0.0
        self.last_audio_integrity = (0, 0, 0)
        self.last_audio_log = 0.0
        self.tuning_diagnostic = ""
        self._last_version = -1
        self._last_display_emit = 0.0
        self.display_interval = .1
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.poll)
        self.timer.start(50)

    @pyqtSlot(object)
    def start(self, config):
        if self.stopping or (self.source and self.source.isRunning()):
            return
        if self.processor and self.processor.isRunning():
            self.pending_config = config
            self.stop()
            return
        self.audio.clear(reset_stats=True)
        ingress = queue.Queue(maxsize=128)
        self.source = Acquisition(config, ingress)
        self.processor = Processing(ingress, self.source, self.audio)
        self.processor.fft_size = self.fft_size
        self.processor.deemphasis = self.deemphasis
        self.processor.demodulation_mode = self.demodulation_mode
        self._last_version = -1
        self._last_display_emit = 0.0
        self.last_error = ""
        self.last_integrity = (0, 0, 0, 0, 0, 0)
        self.last_audio_integrity = (0, 0, 0)
        self.last_audio_log = 0.0
        self.tuning_diagnostic = ""
        self.paused = False
        self.processor.start()
        self.source.start()
        self.set_state("连接中" if config.mode == "USB" else "运行中")
        self.log.emit(f"启动 {config.mode} · 43.5 MS/s → 500 kIQ/s"
                      + (f" · TRI1 / {MODE_NAMES[config.tuning_mode]}" if config.mode == "USB" else ""))
        self.log.emit(f"解调模式：{DEMODULATION_MODES[self.demodulation_mode]}")
        if config.mode == "USB" and config.usb_protocol == "TRI1":
            self.log.emit("FM 识别 r5 · 导频辅助；AM/FM 切换连续三次确认，短时候选变化保持解调。")
            self.log.emit("音频缓冲 r3 · 默认设备优先同名 WASAPI；按设备延迟配置预缓冲与有界队列。")
            self.log.emit("USB 启动恢复 r1 · 先恢复 EP6/EP2 驱动端点，再发送启动命令。")
            self.log.emit("启动检查 v2026-10-26 · " +
                          (f"本次手动载频 {config.rf_hz/1e6:.6f} MHz；信号源改频后需同步修改此值。"
                           if config.tuning_mode == 2 else
                           "本次由 FPGA 重新估频；不复用上次锁定载频。"))

    def set_state(self, value):
        if self.state != value:
            self.state = value
            self.state_changed.emit(value)

    @pyqtSlot()
    def stop(self):
        if self.source and (not self.processor or not self.processor.isRunning()):
            self.source.stop()
        if self.processor:
            self.processor.request_stop()
        self.stopping = True
        self.audio.clear(reason="acquisition_stop")
        self.set_state("停止中")

    @pyqtSlot(float)
    def set_window(self, value):
        self.window_ms = value
        self._last_version = -1

    @pyqtSlot(bool)
    def set_paused(self, value):
        self.paused = value

    @pyqtSlot(float)
    def set_volume(self, value):
        self.audio.volume = value

    @pyqtSlot(int)
    def set_deemphasis(self, value):
        if value not in {option[0] for option in FM_DEEMPHASIS_OPTIONS}:
            raise ValueError("不支持的 FM 去加重时间")
        self.deemphasis = value
        if self.processor:
            self.processor.deemphasis = value

    @pyqtSlot(str)
    def set_demodulation(self, mode):
        if mode not in DEMODULATION_MODES:
            raise ValueError("未知解调模式")
        self.demodulation_mode = mode
        if self.processor:
            self.processor.demodulation_mode = mode
        self.log.emit(f"解调模式：{DEMODULATION_MODES[mode]}")

    @pyqtSlot(int)
    def set_fft(self, value):
        if value in (2048, 4096, 8192):
            self.fft_size = value
            if self.processor:
                self.processor.fft_size = value

    @pyqtSlot(str)
    def scan_records(self, path):
        if self.record_scan and self.record_scan.isRunning():
            return
        self.record_scan = RecordScan(path)
        self.record_scan.scanned.connect(self.records_ready)
        self.record_scan.start()

    @pyqtSlot()
    def scan_devices(self):
        if self.device_scan and self.device_scan.isRunning():
            return
        self.device_scan = DeviceScan()
        self.device_scan.scanned.connect(self.devices_ready)
        self.device_scan.failed.connect(lambda text: self.log.emit(f"音频设备查询失败：{text}"))
        self.device_scan.start()

    @pyqtSlot(bool, object)
    def set_audio(self, enabled, device):
        if self.audio_job and self.audio_job.isRunning():
            return
        self.audio_job = AudioJob(self.audio, enabled, device)
        self.audio_job.failed.connect(lambda text: self.log.emit(f"音频错误：{text}"))
        self.audio_job.finished.connect(self.audio_job_finished)
        self.audio_job.start()

    @pyqtSlot()
    def audio_job_finished(self):
        self.audio_changed.emit(self.audio.enabled)
        if self.audio.enabled:
            audio = self.audio.snapshot()
            device = audio["device"]
            self.log.emit(f"音频设备：{device.get('name', '')} [{device.get('hostapi', '')}]；"
                          f"设备延迟={device.get('latency_ms', 0):.0f} ms，"
                          f"预缓冲={audio['prebuffer_ms']:.0f} ms，容量={audio['capacity_ms']:.0f} ms。")
            if audio["fallback_reason"]:
                self.log.emit("WASAPI 打开失败，已回退同一系统默认设备：" + audio["fallback_reason"])

    @pyqtSlot(str)
    def save(self, parent_path):
        if not self.processor or self.save_job and self.save_job.isRunning():
            return
        self.save_job = SaveJob(parent_path, self.processor)
        self.save_job.saved.connect(self.saved)
        self.save_job.failed.connect(lambda text: self.log.emit(f"保存失败：{text}"))
        self.save_job.start()

    @pyqtSlot()
    def poll(self):
        if self.closing and not self.busy():
            self.timer.stop()
            self.ready_to_close.emit()
            return
        if self.stopping:
            if all(worker is None or not worker.isRunning() for worker in (self.source, self.processor)):
                self.stopping = False
                self.set_state("已停止")
                if self.pending_config is not None and not self.closing:
                    config, self.pending_config = self.pending_config, None
                    self.start(config)
                    return
        if not self.processor:
            return
        stats = self.processor.stats()
        self.last_stats = stats
        self.stats_ready.emit(stats)
        tuning = stats.get("tuning", {})
        if (not self.stopping and self.state != "已停止" and not self.source.ended
                and stats["elapsed_s"] > 2 and stats["last_valid_age_s"] is None
                and tuning.get("commands", 0) >= 3):
            if tuning.get("mode") == 1 and not tuning.get("flags", 0) & 256:
                diagnostic = "FPGA 尚未获得调谐参数，未产生 I/Q；请记录 AM 深度及输入电平，并用相同载频手动模式对照。"
            else:
                diagnostic = "已有调谐配置但未收到 I/Q；请核对信号源与本次设定载频，并检查 USB/FPGA 数据链路。"
            if diagnostic != self.tuning_diagnostic:
                self.tuning_diagnostic = diagnostic
                self.log.emit("启动检查：" + diagnostic)
        integrity = (stats["crc_errors"], stats["header_errors"], stats["continuity_gaps"],
                     stats["queue_dropped_bytes"], stats["clipped_frames"], stats["transport_gaps"])
        if integrity != self.last_integrity and time.monotonic()-self.last_integrity_log > 1:
            self.last_integrity = integrity
            self.last_integrity_log = time.monotonic()
            self.log.emit(f"校验：CRC={integrity[0]}，帧头={integrity[1]}，间断={integrity[2]}，"
                          f"主机丢弃={integrity[3]} 字节，削顶帧={integrity[4]}，全局序号异常={integrity[5]}。{stats['decoder_message']}")
        error = self.source.error or self.processor.error
        audio_integrity = (stats["audio_underruns"], stats["audio_overruns"], stats["audio_device_errors"])
        if (self.audio.enabled and not self.stopping and not self.source.ended
                and audio_integrity != self.last_audio_integrity
                and time.monotonic()-self.last_audio_log >= 5):
            self.last_audio_integrity = audio_integrity
            self.last_audio_log = time.monotonic()
            self.log.emit(f"音频：欠载={audio_integrity[0]}，溢出={audio_integrity[1]}，"
                          f"设备状态异常={audio_integrity[2]}，缓冲={stats['audio_buffer_ms']:.0f} ms；"
                          f"{stats['audio_device_status'] or '设备未报告异常状态'}")
            audio = stats["audio_diagnostics"]
            self.log.emit(f"音频诊断：交付最大间隔={audio['max_push_gap_ms']:.0f} ms，"
                          f"回调最大间隔={audio['max_callback_gap_ms']:.0f} ms，"
                          f"回调最大耗时={audio['max_callback_work_ms']:.1f} ms，"
                          f"丢弃={audio['discarded_frames']} 点，欠缺={audio['missing_frames']} 点，"
                          f"清空原因={audio['clear_reasons']}。")
        if error and error != self.last_error:
            self.log.emit(f"错误：{error}")
            self.last_error = error
            if self.processor.isRunning():
                self.processor.request_stop()
            else:
                self.source.stop()
            self.set_state("错误")
        elif not self.stopping and not error and self.state not in ("已停止", "停止中"):
            if self.source.ended:
                self.set_state("回放结束" if self.source.config.mode == "文件回放" else "已停止")
            elif stats["last_valid_age_s"] is None or stats["last_valid_age_s"] > .6:
                self.set_state("等待有效帧")
            else:
                self.set_state("运行中")
        # USB/DSP remain continuous; the plot is presentation-only and does
        # not need to redraw every processing block.  Limiting GUI updates to
        # 10 Hz prevents pyqtgraph from competing with the receive threads.
        if not self.paused and not error and time.monotonic()-self._last_display_emit >= self.display_interval:
            display = self.processor.display(self.window_ms)
            if display is not None and display["version"] != self._last_version:
                self._last_version = display["version"]
                self._last_display_emit = time.monotonic()
                self.display_ready.emit(display)
            elif display is None and self._last_version != self.processor.latest_version:
                self._last_version = self.processor.latest_version
                self._last_display_emit = time.monotonic()
                self.display_ready.emit(None)

    @pyqtSlot()
    def request_shutdown(self):
        self.closing = True
        self.stop()
        if not self.audio_job or not self.audio_job.isRunning():
            self.set_audio(False, None)

    def busy(self):
        return any(worker is not None and worker.isRunning()
                   for worker in (self.source, self.processor, self.save_job, self.audio_job,
                                  self.record_scan, self.device_scan))

    def shutdown(self):
        self.timer.stop()
        if self.source and (not self.processor or not self.processor.isRunning()):
            self.source.stop()
        if self.processor:
            self.processor.request_stop()
        for worker in (self.source, self.processor, self.save_job, self.audio_job, self.record_scan, self.device_scan):
            if worker:
                worker.wait()
        self.audio.stop()
