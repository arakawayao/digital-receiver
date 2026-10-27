"""USB uploaded ADC12 AM/FM samples through the dual project's test revisions."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import time

from .dual_control_test import ControlSession, PROJECT, ENGINEERING
from .transport import CyUSBReader, TransferTimeout
from .interfaces import protocol
from .legacy.receiver_ads807.replay import waveform


def sample_pairs(samples):
    if len(samples) != 8192 or any(not 0 <= value <= 4095 for value in samples):
        raise ValueError("Replay requires exactly 8192 ADC12 offset-binary samples")
    return [samples[n] | samples[n+1] << 12 for n in range(0, 8192, 2)]


def upload(session, samples, progress=lambda value: None):
    pairs = sample_pairs(samples)
    for begin in range(0, len(pairs), 32):
        pending = []
        for address in range(begin, begin+32):
            session.sequence = (session.sequence+1) & 0xffffffff
            pending.append(session.sequence)
            session.reader.write(protocol.command(session.sequence, 9, pairs[address], address))
        deadline = time.monotonic()+2
        while pending:
            if time.monotonic() > deadline:
                raise TimeoutError("Sample upload ACK timeout; no retry")
            try:
                data = session.reader.read(size=32768, timeout=100)
            except TransferTimeout:
                continue
            for frame in session.decoder.feed(data):
                sequence = frame.words[3]
                if session.last_frame is not None and sequence != (session.last_frame+1) & 0xffffffff:
                    raise ValueError("Sample upload TRI1 sequence gap")
                session.last_frame = sequence
                session.frame_count += 1
                if frame.kind != 3 or not pending:
                    raise ValueError("Unexpected frame while stopped sample upload")
                ack = frame.ack()
                if ack["sequence"] != pending.pop(0) or ack["opcode"] != 9 or ack["error"]:
                    raise ValueError("Sample upload rejected/mismatched ACK: "+str(ack))
            if session.decoder.crc_errors or session.decoder.discarded:
                raise ValueError("Sample upload CRC/discarded bytes")
        progress(begin+32)
    return dict(samples=8192, write_commands=len(pairs), crc_errors=session.decoder.crc_errors,
                discarded_bytes=session.decoder.discarded, frames=session.frame_count)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--mode", choices=("manual", "auto", "both"), default="both")
    args = parser.parse_args()
    if args.seconds < 5:
        parser.error("--seconds must be >=5")
    from PyQt6.QtCore import QObject, QThread, QTimer, pyqtSignal
    from PyQt6.QtWidgets import QApplication
    from .gui import Window, wire
    from .runtime import Controller
    from .sources import SourceConfig
    from .preview import Preview

    output = PROJECT / ".harness/receiver_ads807_dual/usb_samples/board" / datetime.now().strftime("%Y%m%d_%H%M%S")
    output.mkdir(parents=True)
    cases = []
    for mode in (2, 1):
        if args.mode != "both" and mode != (2 if args.mode == "manual" else 1):
            continue
        name = "receiver_usb_samples" + ("_auto" if mode == 1 else "")
        firmware = ENGINEERING / "usb_samples"
        build = firmware / ("build_auto" if mode == 1 else "build") / "summary.json"
        summary = json.loads(build.read_text(encoding="utf-8"))
        if summary["status"] != "PASS":
            raise RuntimeError("Sample firmware build/timing not passed: "+str(build))
        sof = firmware / (name+".sof")
        for kind in ("am", "fm"):
            for amplitude in (800, 80):
                samples, info = waveform(kind, amplitude=amplitude)
                info.update(protocol="TRI1", source="USB uploaded ADC12 test RAM; physical ADC absent")
                cases.append(dict(name=f"mode{mode}_{kind}_{amplitude}", mode=mode,
                                  samples=samples, info=info, sof=str(sof),
                                  sof_sha256=hashlib.sha256(sof.read_bytes()).hexdigest()))

    class UploadJob(QThread):
        completed = pyqtSignal(object)
        progress = pyqtSignal(str)

        def __init__(self, case):
            super().__init__()
            self.case = case

        def run(self):
            reader = None
            value = dict(ok=False)
            try:
                reader = CyUSBReader(duplex=True)
                reader.close()
                reader = None
                case = self.case
                sof = Path(case["sof"])
                if hashlib.sha256(sof.read_bytes()).hexdigest() != case["sof_sha256"]:
                    raise ValueError("SOF changed")
                result = subprocess.run(["D:/intelFPGA/18.1/quartus/bin64/quartus_pgm.exe", "-c",
                                         "USB-Blaster [USB-0]", "-m", "JTAG", "-o", "p;"+str(sof)+"@1"],
                                        capture_output=True, text=True, errors="replace", timeout=60)
                (output/(case["name"]+"_program.log")).write_text(result.stdout+result.stderr, encoding="utf-8")
                if result.returncode or "Configuration succeeded" not in result.stdout:
                    raise RuntimeError("Sample revision programming failed")
                reader = CyUSBReader(duplex=True)
                startup = bytearray()
                while len(startup) < 65536:
                    try:
                        startup.extend(reader.read(size=32768, timeout=100))
                    except TransferTimeout:
                        break
                else:
                    raise BufferError("Startup data exceeded 64 KiB")
                (output/(case["name"]+"_startup.bin")).write_bytes(startup)
                reader.start_pump()
                session = ControlSession(reader)
                session.request(protocol.STOP)
                samples = case["samples"]
                raw = struct.pack("<8192H", *samples)
                (output/(case["name"]+"_adc12.bin")).write_bytes(raw)
                info = {**case["info"], "samples_sha256": hashlib.sha256(raw).hexdigest()}
                (output/(case["name"]+"_input.json")).write_text(json.dumps(info, indent=2), encoding="utf-8")
                result = upload(session, samples, lambda n: self.progress.emit(f"样本上传 {n*2}/8192") if n % 256 == 0 else None)
                reader.close()
                reader = None
                value = dict(ok=True, upload=result)
            except Exception as error:
                value = dict(ok=False, error=str(error))
            finally:
                if reader is not None:
                    try:
                        reader.close()
                    except Exception as error:
                        value = dict(ok=False, error=str(error))
                self.completed.emit(value)

    class Matrix(QObject):
        start = pyqtSignal(object)
        stop = pyqtSignal()

        def __init__(self, window, controller):
            super().__init__(window)
            self.window, self.controller = window, controller
            self.start.connect(controller.start)
            self.stop.connect(controller.stop)
            self.position = 0
            self.results = []
            self.phase = "next"
            self.job = None
            self.current = None
            self.timer = QTimer(self)
            self.timer.timeout.connect(self.tick)
            self.timer.start(200)
            window.stop_requested.connect(self.cancel)

        def save(self, status):
            value = dict(status=status, scope="USB upload then circular RAM playback -> dual DSP -> TRI1 USB -> production host; no physical ADC/audio",
                         seconds_per_case=args.seconds, fifo_samples=256, replay_samples=8192,
                         completed=self.results, phase=self.phase,
                         current={k: v for k, v in self.current.items() if k != "samples"} if self.current else None)
            (output/"result.json").write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")

        def cancel(self):
            if self.phase not in ("done", "failed"):
                self.phase = "failed"
                self.save("STOPPED")

        def failed(self, reason):
            window.append_log("测试停止："+reason)
            self.results.append(dict(name=self.current["name"], status="FAIL", reason=reason))
            self.stop.emit()
            self.phase = "failed"
            self.save("FAIL")
            window.status.setText("测试失败，已停止")

        def uploaded(self, value):
            if self.phase != "uploading":
                return
            if not value["ok"]:
                self.failed(value["error"])
                return
            self.upload_result = value["upload"]
            case = self.current
            self.start.emit(SourceConfig(mode="USB", tuning_mode=case["mode"],
                                         rf_hz=round(case["info"]["actual_rf_hz"]), usb_managed_pump=True))
            window.source_badge.setText(f"新工程 USB RAM 回放 · 模式{case['mode']} · {case['info']['kind'].upper()} · {case['info']['carrier_amplitude_codes']}码")
            window.start_action.setEnabled(False)
            self.deadline = time.monotonic()+20
            self.stable = None
            self.checks = 0
            self.next_check = 0
            self.phase = "running"
            self.save("RUNNING")

        def tick(self):
            if self.phase in ("done", "failed", "uploading"):
                return
            if self.phase == "stopping":
                if controller.busy():
                    return
                errors = [w.error for w in (controller.source, controller.processor) if w and w.error]
                if errors:
                    self.failed("STOP/cleanup: "+str(errors))
                    return
                self.position += 1
                self.phase = "next"
            if self.phase == "next":
                if self.position == len(cases):
                    self.phase = "done"
                    self.save("PASS")
                    window.status.setText("AM/FM 回放测试完成")
                    window.append_log("PASS · "+str(output))
                    return
                self.current = cases[self.position]
                self.phase = "uploading"
                window.status.setText("下载并上传 "+self.current["name"])
                window.append_log(f"第 {self.position+1}/{len(cases)} 组：{self.current['name']}")
                self.job = UploadJob(self.current)
                self.job.completed.connect(self.uploaded)
                self.job.progress.connect(window.status.setText)
                self.job.start()
                self.save("RUNNING")
                return
            processor = controller.processor
            if processor is None:
                return
            stats = processor.stats()
            error = stats["source_error"] or stats["processing_error"]
            timing = stats.get("usb_timing") or {}
            error = error or timing.get("managed_error")
            bad = {key: stats[key] for key in ("crc_errors", "header_errors", "discarded_bytes", "continuity_gaps",
                   "missing_samples", "fpga_dropped", "queue_dropped_bytes", "clipped_frames", "transport_gaps") if stats[key]}
            if error or bad or timing.get("managed_queue_dropped_bytes"):
                self.failed(str(error or bad or timing))
                return
            now = time.monotonic()
            result = processor.result.to_dict()
            expected = self.current["info"]["kind"].upper()
            if self.stable is None:
                if result["kind"] != expected:
                    if now > self.deadline:
                        self.failed("20秒内未得到预期识别："+str(result))
                    return
                self.stable = now
                self.initial_samples = processor.processed
            if stats["last_valid_age_s"] is None or stats["last_valid_age_s"] > 1:
                self.failed("有效 I/Q 断流超过1秒")
                return
            if now >= self.next_check:
                invalid = result["kind"] != expected or abs(result["carrier_hz"]-self.current["info"]["actual_rf_hz"]) > 12000
                invalid |= expected == "AM" and abs((result["am_depth"] or 0)-.5) > .05
                invalid |= expected == "FM" and abs((result["fm_deviation_hz"] or 0)-25000) > 2500
                if invalid:
                    self.failed("信号测量不符合测试参数："+str(result))
                    return
                self.checks += 1
                self.next_check = now+1
            if now-self.stable >= args.seconds:
                rate = (processor.processed-self.initial_samples)/(now-self.stable)
                if rate < 490000:
                    self.failed(f"有效处理速率不足：{rate:.1f} IQ/s")
                    return
                self.results.append(dict(name=self.current["name"], status="PASS", upload=self.upload_result,
                                         elapsed_s=now-self.stable, iq_rate_hz=rate, measurement=result,
                                         checks=self.checks, stats=stats))
                window.grab().save(str(output/(self.current["name"]+".png")))
                self.stop.emit()
                self.phase = "stopping"
                self.save("RUNNING")

    app = QApplication(sys.argv[:1])
    app.setStyle("Fusion")
    app.setStyleSheet(Path(__file__).with_name("theme.qss").read_text(encoding="utf-8"))
    controller = Controller()
    window = Window()
    wire(window, controller)
    matrix = Matrix(window, controller)
    window.start_action.setEnabled(False)
    window.source_badge.setText("新工程 USB 样本回放 · 准备测试")
    window.show()
    preview = Preview(window)
    print(f"PREVIEW_URL=http://127.0.0.1:{preview.port}\nOUTPUT={output}", flush=True)
    result = app.exec()
    matrix.timer.stop()
    if matrix.job is not None:
        matrix.job.wait()
    controller.shutdown()
    preview.close()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
