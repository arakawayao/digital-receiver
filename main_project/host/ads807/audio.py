"""Bounded mono audio buffer, silence on underrun, explicit overflow counters."""
from collections import deque
import threading
import time

import numpy as np

from .dsp import AUDIO_RATE


class AudioOutput:
    def __init__(self):
        self.lock = threading.Lock()
        self.chunks = deque()
        self.frames = 0
        self.capacity = AUDIO_RATE//4
        # DSP publishes about 40 ms per block. Allow several batches of jitter
        # before the 20 ms audio callback starts consuming them.
        self.prebuffer_frames = AUDIO_RATE*120//1000
        self.stream = None
        self.enabled = False
        self.volume = .35
        self.underruns = 0
        self.overruns = 0
        self.device_errors = 0
        self.last_device_status = ""
        self.error = ""
        self.primed = False
        self.startup_silence_frames = 0
        self.device_info = {}
        self.fallback_reason = ""
        self._reset_diagnostics()

    def _reset_diagnostics(self):
        self.received_frames = self.played_frames = self.discarded_frames = 0
        self.missing_frames = 0
        self.last_push = self.last_callback = None
        self.max_push_gap_ms = self.max_callback_gap_ms = self.max_callback_work_ms = 0.0
        self.clear_reasons = {}

    def configure_buffer(self, latency):
        # Cover the device's callback batching plus two 40 ms DSP blocks.
        # Keep another 250 ms (or one device batch + 120 ms) of bounded headroom.
        latency = max(0.0, float(latency))
        self.prebuffer_frames = round(AUDIO_RATE*max(.12, latency+.08))
        self.capacity = self.prebuffer_frames + round(AUDIO_RATE*max(.25, latency+.12))

    def clear(self, reset_stats=False, reason="reset"):
        with self.lock:
            self.chunks.clear()
            self.frames = 0
            self.primed = False
            if reset_stats:
                self.underruns = self.overruns = self.device_errors = 0
                self.startup_silence_frames = 0
                self.last_device_status = ""
                self._reset_diagnostics()
            else:
                self.clear_reasons[reason] = self.clear_reasons.get(reason, 0)+1
            self.last_push = None

    def push(self, values):
        if not self.enabled:
            return
        values = np.asarray(values, dtype=np.float32).copy()
        if not len(values):
            return
        now = time.perf_counter()
        with self.lock:
            if self.last_push is not None:
                self.max_push_gap_ms = max(self.max_push_gap_ms, (now-self.last_push)*1000)
            self.last_push = now
            self.received_frames += len(values)
            dropped = max(0, self.frames+len(values)-self.capacity)
            if dropped:
                self.overruns += 1
                self.discarded_frames += dropped
            if len(values) > self.capacity:
                values = values[-self.capacity:]
            excess = max(0, self.frames+len(values)-self.capacity)
            while excess and self.chunks:
                chunk = self.chunks.popleft()
                count = min(excess, len(chunk))
                self.frames -= count
                excess -= count
                if count < len(chunk):
                    self.chunks.appendleft(chunk[count:])
            self.chunks.append(values)
            self.frames += len(values)

    def render(self, frames):
        result = np.zeros(frames, np.float32)
        written = 0
        with self.lock:
            if not self.primed:
                if self.frames < self.prebuffer_frames:
                    self.startup_silence_frames += frames
                    return result
                self.primed = True
            while self.chunks and written < frames:
                current = self.chunks.popleft()
                count = min(len(current), frames-written)
                result[written:written+count] = current[:count]
                written += count
                self.frames -= count
                if count < len(current):
                    self.chunks.appendleft(current[count:])
            if written < frames:
                self.underruns += 1
                self.missing_frames += frames-written
                self.primed = False
            self.played_frames += written
        return np.clip(result*self.volume, -.95, .95)

    def _callback(self, outdata, frames, time_info, status):
        started = time.perf_counter()
        if self.last_callback is not None:
            self.max_callback_gap_ms = max(self.max_callback_gap_ms, (started-self.last_callback)*1000)
        self.last_callback = started
        if status:
            self.device_errors += 1
            self.last_device_status = str(status)
        outdata[:, 0] = self.render(frames)
        self.max_callback_work_ms = max(self.max_callback_work_ms, (time.perf_counter()-started)*1000)

    def snapshot(self):
        with self.lock:
            return {"underruns": self.underruns, "overruns": self.overruns,
                    "device_errors": self.device_errors, "device_status": self.last_device_status,
                    "enabled": self.enabled, "buffer_ms": self.frames/AUDIO_RATE*1000,
                    "prebuffer_ms": self.prebuffer_frames/AUDIO_RATE*1000,
                    "capacity_ms": self.capacity/AUDIO_RATE*1000,
                    "startup_silence_frames": self.startup_silence_frames,
                    "received_frames": self.received_frames, "played_frames": self.played_frames,
                    "discarded_frames": self.discarded_frames, "missing_frames": self.missing_frames,
                    "max_push_gap_ms": self.max_push_gap_ms,
                    "max_callback_gap_ms": self.max_callback_gap_ms,
                    "max_callback_work_ms": self.max_callback_work_ms,
                    "clear_reasons": dict(self.clear_reasons), "device": dict(self.device_info),
                    "fallback_reason": self.fallback_reason}

    @staticmethod
    def select_device(sd, device):
        if device is not None:
            return device
        default = sd.query_devices(kind="output")
        apis = sd.query_hostapis()
        for index, candidate in enumerate(sd.query_devices()):
            if (candidate["max_output_channels"] and candidate["name"] == default["name"]
                    and apis[candidate["hostapi"]]["name"] == "Windows WASAPI"):
                try:
                    sd.check_output_settings(device=index, channels=1, dtype="float32", samplerate=AUDIO_RATE)
                    return index
                except sd.PortAudioError:
                    continue
        return None

    def start(self, device=None):
        if self.stream is not None:
            return
        import sounddevice as sd
        self.clear(reason="device_start")
        self.error = ""
        self.fallback_reason = ""
        try:
            selected = self.select_device(sd, device)
            options = dict(samplerate=AUDIO_RATE, channels=1, dtype="float32",
                           blocksize=960, latency="high", callback=self._callback)
            try:
                self.stream = sd.OutputStream(device=selected, **options)
            except sd.PortAudioError as error:
                if device is not None or selected is None:
                    raise
                self.fallback_reason = str(error)
                self.stream = sd.OutputStream(device=None, **options)
            info = sd.query_devices(self.stream.device, "output")
            api = sd.query_hostapis(info["hostapi"])
            self.device_info = {"index": int(self.stream.device), "name": info["name"],
                                "hostapi": api["name"], "latency_ms": float(self.stream.latency)*1000,
                                "sample_rate_hz": float(self.stream.samplerate)}
            self.configure_buffer(self.stream.latency)
            self.enabled = True
            self.stream.start()
        except Exception as error:
            self.enabled = False
            if self.stream is not None:
                self.stream.close()
                self.stream = None
            self.error = str(error)
            raise

    def stop(self):
        self.enabled = False
        if self.stream is not None:
            self.stream.stop()
            self.stream.close()
            self.stream = None
        self.clear(reason="device_stop")
