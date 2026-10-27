"""Replay decoder/measurement failure tests; no USB device is opened."""
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from argparse import Namespace
from collections import deque
from dataclasses import replace
import zlib

import numpy as np

from ads807.legacy.receiver_ads807.replay import waveform, Decoder, validate_capture, run_device
from ads807.protocol import encode_frame
from ads807.legacy.receiver_ads807.soak import Monitor, measure, run as run_soak


def capture(kind="am"):
    _, info = waveform(kind)
    count = 112 * 16
    time = np.arange(count) / 500_000
    phase_step = round((98_000_000 - 87_000_000) / 43_500_000 * 2**32)
    lo = 87_000_000 + phase_step * 43_500_000 / 2**32
    phase = math.tau * (info["actual_rf_hz"] - lo) * time
    amplitude = np.full(count, 2000.)
    message = math.tau * info["modulation_hz"] * time
    if kind == "am":
        amplitude *= 1 + .5 * np.cos(message)
    else:
        phase += 25_000 / info["modulation_hz"] * np.sin(message)
    iq = np.rint(np.column_stack((amplitude * np.cos(phase), amplitude * np.sin(phase))))
    data = b"".join(encode_frame(iq[n:n + 112], sequence=n // 112, index=n, rf_hz=98_000_000)
                    for n in range(0, count, 112))
    return data, info


class ReplayTests(unittest.TestCase):
    def test_am_fm_production_classifier(self):
        for kind in ("am", "fm"):
            data, info = capture(kind)
            _, result = validate_capture(data, info)
            self.assertEqual(result["measurement"]["kind"], kind.upper())

    def test_arbitrary_read_boundaries(self):
        data, _ = capture()
        decoder = Decoder()
        records = []
        for start in range(0, len(data), 137):
            records.extend(decoder.feed(data[start:start + 137]))
        self.assertEqual(len(records), 16)
        self.assertFalse(decoder.buffer)
        self.assertEqual(decoder.crc_errors, 0)

    def test_missing_frame(self):
        data, info = capture()
        with self.assertRaisesRegex(ValueError, "discontinuity"):
            validate_capture(data[:512] + data[1024:], info)

    def test_crc_corruption(self):
        data, info = capture()
        broken = bytearray(data)
        broken[70] ^= 1
        with self.assertRaisesRegex(ValueError, "CRC"):
            validate_capture(broken, info)

    def test_wrong_configuration(self):
        data, _ = capture()
        broken = bytearray(data[:512])
        struct.pack_into("<I", broken, 28, 56_000_000)
        struct.pack_into("<I", broken, 508, zlib.crc32(broken[:508]))
        with self.assertRaisesRegex(ValueError, "configuration"):
            Decoder().feed(broken)

    def test_partial_capture(self):
        data, info = capture()
        with self.assertRaisesRegex(ValueError, "partial"):
            validate_capture(data[:-1], info)

    def test_truth_is_not_classification(self):
        data, info = capture("am")
        info["kind"] = "fm"
        with self.assertRaisesRegex(ValueError, "classification mismatch"):
            validate_capture(data, info)

    def test_waveform_boundaries(self):
        for kind in ("am", "fm"):
            samples, _ = waveform(kind)
            self.assertEqual(len(samples), 8192)
            self.assertTrue(all(0 <= value <= 4095 for value in samples))
        with self.assertRaises(ValueError):
            waveform("fm", deviation=float("nan"))
        with self.assertRaises(ValueError):
            waveform("fm", length=256)

    def test_stop_padding_does_not_corrupt_completed_capture(self):
        data, info = capture()

        class Device:
            def __init__(self):
                self.pending = deque()
                self.started = False
                self.closed = False

            def describe(self):
                return {"backend": "test double"}

            def write(self, address, frame, timeout):
                opcode = struct.unpack_from("<H", frame, 6)[0]
                sequence = struct.unpack_from("<I", frame, 8)[0]
                ack = bytearray(512)
                struct.pack_into("<7I", ack, 0, 0x31415052, 1, sequence, opcode, 8192, 8192, opcode == 3)
                struct.pack_into("<I", ack, 508, zlib.crc32(ack[:508]))
                if opcode == 4 and self.started:
                    broken_tail = bytearray(data[-512:])
                    broken_tail[60:] = bytes(452)
                    self.pending.append(bytes(broken_tail))
                self.pending.append(bytes(ack))
                if opcode == 3:
                    self.started = True
                    self.pending.append(data)
                return 512

            def read(self, address, size, timeout):
                return self.pending.popleft()

            def close(self):
                self.closed = True

        device = Device()
        with tempfile.TemporaryDirectory() as temporary:
            args = Namespace(vid=0x04B4, pid=0x1004, cyusb_dll=None,
                             timeout=1, frames=16, output=Path(temporary))
            with patch("ads807.legacy.receiver_ads807.replay.open_transport", return_value=device):
                result = run_device(args, waveform("am")[0], info)
            self.assertEqual(result["status"], "PASS")
            self.assertTrue(device.closed)


class SoakTests(unittest.TestCase):
    def frames(self):
        data, _ = capture()
        return [frame for kind, frame, _ in Decoder().feed(data)]

    def test_continuity_and_bounded_tail(self):
        monitor = Monitor()
        template = self.frames()[0]
        for sequence in range(700):
            monitor.observe(replace(template, sequence=sequence, index=sequence * 112))
        self.assertEqual(monitor.samples, 700 * 112)
        self.assertEqual(len(monitor.tail), 512)

    def test_uint32_wrap_is_continuous(self):
        monitor = Monitor()
        template = self.frames()[0]
        monitor.observe(template)
        monitor.previous = replace(template, sequence=0xFFFFFFFF, index=0xFFFFFF90)
        monitor.observe(replace(template, sequence=0, index=0))
        self.assertEqual(monitor.sample_wraps, 1)

    def test_frame_and_sample_gap_rejected(self):
        first, second = self.frames()[:2]
        for broken in (replace(second, sequence=2), replace(second, index=113)):
            monitor = Monitor()
            monitor.observe(first)
            with self.assertRaisesRegex(ValueError, "gap"):
                monitor.observe(broken)

    def test_overflow_clip_restart_and_tuning_rejected(self):
        first, second = self.frames()[:2]
        for broken in (replace(second, dropped=1), replace(second, flags=0x14),
                       replace(second, epoch=2), replace(second, phase_step=1)):
            monitor = Monitor()
            monitor.observe(first)
            with self.assertRaises(ValueError):
                monitor.observe(broken)

    def test_periodic_analysis_uses_measured_iq(self):
        for kind in ("am", "fm"):
            data, info = capture(kind)
            frames = [frame for name, frame, _ in Decoder().feed(data)]
            iq = np.concatenate([frame.samples for frame in frames])[66:]
            z = (iq[:, 0] + 1j * iq[:, 1]) / 32768
            lo = 87_000_000 + frames[0].phase_step * 43_500_000 / 2**32
            self.assertEqual(measure((z, lo), info)["kind"], kind.upper())
            with self.assertRaises(ValueError):
                measure((np.zeros(8192), lo), info)

    def test_disconnect_writes_fail_and_stops_replay(self):
        class Device:
            def __init__(self):
                self.pending = deque()
                self.closed = False
                self.operations = []

            def describe(self):
                return {"backend": "test double"}

            def write(self, address, frame, timeout):
                opcode = struct.unpack_from("<H", frame, 6)[0]
                sequence = struct.unpack_from("<I", frame, 8)[0]
                self.operations.append(opcode)
                ack = bytearray(512)
                struct.pack_into("<7I", ack, 0, 0x31415052, 1, sequence, opcode, 8192, 8192, opcode == 3)
                struct.pack_into("<I", ack, 508, zlib.crc32(ack[:508]))
                self.pending.append(bytes(ack))
                return 512

            def read(self, address, size, timeout):
                if self.pending:
                    return self.pending.popleft()
                raise RuntimeError("Disconnected test device")

            def close(self):
                self.closed = True

        device = Device()
        with tempfile.TemporaryDirectory() as temporary:
            args = Namespace(kind="am", rf=98_000_000, vid=0x04B4, pid=0x1004,
                             cyusb_dll=None, seconds=5, stall_timeout=1,
                             report_interval=1, output=Path(temporary))
            with patch("ads807.legacy.receiver_ads807.soak.open_transport", return_value=device):
                result = run_soak(args)
            self.assertEqual(result["status"], "FAIL")
            self.assertIn("Disconnected", result["reason"])
            self.assertTrue(result["stop_ack"])
            self.assertEqual(device.operations[-1], 4)
            self.assertTrue(device.closed)


if __name__ == "__main__":
    unittest.main()
