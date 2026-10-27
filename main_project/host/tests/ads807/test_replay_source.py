"""The autonomous board replay shares the real GUI ingress without TRI1 commands."""
from collections import deque
import queue
import struct
import threading
from unittest.mock import patch
import zlib

import numpy as np
import pytest

from ads807.protocol import encode_frame
from ads807.sources import Acquisition, SourceConfig


@pytest.mark.parametrize("managed", [False, True])
def test_replay_upload_capture_and_stop_share_one_reader(managed):
    ingress = queue.Queue(maxsize=128)
    source = Acquisition(SourceConfig(mode="USB", tuning_mode=1, usb_protocol="RPL1",
                                      replay_kind="fm", replay_amplitude=80, usb_managed_pump=managed), ingress)
    payload = encode_frame(np.zeros((112, 2)), sequence=0, index=0)

    class Reader:
        def __init__(self, *args, **kwargs):
            self.pending = deque()
            self.operations = []
            self.closed = False
            self.pump_started = False

        def start_pump(self):
            assert self.operations == [4, 1] + [2]*35
            self.pump_started = True

        def write(self, packet):
            opcode = struct.unpack_from("<H", packet, 6)[0]
            sequence = struct.unpack_from("<I", packet, 8)[0]
            self.operations.append(opcode)
            ack = bytearray(512)
            struct.pack_into("<7I", ack, 0, 0x31415052, 1, sequence, opcode, 8192, 8192, opcode == 3)
            struct.pack_into("<I", ack, 508, zlib.crc32(ack[:508]))
            # A native batch may include IQ on both sides of the START ACK.
            self.pending.append(payload + bytes(ack) + payload if managed and opcode == 3 else bytes(ack))

        def read(self, size=32768, timeout=100):
            if self.pending:
                return self.pending.popleft()
            source.stop()
            return payload

        def close(self):
            self.closed = True

    reader = Reader()
    with patch("ads807.sources.CyUSBReader", return_value=reader):
        source.run()
    assert source.error == ""
    assert source.ended and reader.closed
    assert reader.pump_started == managed
    assert reader.operations == [4, 1] + [2]*35 + [3, 4]
    assert source.total_bytes == len(payload)*(3 if managed else 1)
    if managed:
        assert ingress.get_nowait() == payload*2
    assert ingress.get_nowait() == payload


def test_control_write_does_not_pause_usb_reads():
    ingress = queue.Queue(maxsize=128)
    source = Acquisition(SourceConfig(mode="USB"), ingress)
    writing = threading.Event()
    read_during_write = threading.Event()

    class Reader:
        def write(self, packet):
            writing.set()
            if not read_during_write.wait(2):
                raise TimeoutError("IN request paused during OUT")
            source.stop()

        def read(self):
            if writing.wait(.05):
                read_during_write.set()
            return b"test"

        def close(self):
            assert read_during_write.is_set()

    source.send(bytes(512))
    with patch("ads807.sources.CyUSBReader", return_value=Reader()):
        source.run()
    assert read_during_write.is_set()
    assert source.error == ""


def test_replay_start_without_ack_keeps_iq_buffer_bounded():
    from ads807.legacy.receiver_v2.usb_replay import command, START
    source = Acquisition(SourceConfig(mode="USB", tuning_mode=1, usb_protocol="RPL1"), queue.Queue(128))
    source.replay_started = True
    payload = encode_frame(np.zeros((112, 2)), sequence=0, index=0)

    class Reader:
        def write(self, packet):
            pass

        def read(self, **kwargs):
            return payload*64

    with pytest.raises(BufferError, match="64 KiB"):
        source.replay_exchange(Reader(), command(START, 1))
    assert len(source.replay_pending) == 65536


def test_managed_receiver_failure_is_visible_without_sync_fallback():
    source = Acquisition(SourceConfig(mode="USB", usb_managed_pump=True), queue.Queue(128))
    calls = []

    class Reader:
        def start_pump(self):
            calls.append("start_pump")
            raise RuntimeError("Build USB pump: python -B -m ads807.build_usb_pump")

        def read(self):
            pytest.fail("Failed managed initialization must not fall back to synchronous reads")

        def write(self, packet):
            pytest.fail("No command may be sent before managed initialization succeeds")

        def close(self):
            calls.append("close")

    with patch("ads807.sources.CyUSBReader", return_value=Reader()):
        source.run()
    assert source.ended and not source.connected
    assert "build_usb_pump" in source.error
    assert calls == ["start_pump", "close"]


@pytest.mark.parametrize("recovery_ok", [True, False])
def test_tri_usb_recovers_before_starting_requests(recovery_ok):
    calls = []
    source = Acquisition(SourceConfig(mode="USB", usb_managed_pump=True), queue.Queue(128))

    class Reader:
        def reset_endpoints(self):
            calls.append("recover")
            if not recovery_ok:
                raise RuntimeError("USB端点恢复失败")

        def start_pump(self):
            calls.append("pump")

        def read(self):
            calls.append("read")
            source.stop()
            return b""

        def close(self):
            calls.append("close")

    with patch("ads807.sources.CyUSBReader", return_value=Reader()):
        source.run()
    assert source.ended and not source.connected
    if recovery_ok:
        assert calls == ["recover", "pump", "read", "close"]
        assert not source.error
    else:
        assert calls == ["recover", "close"]
        assert "USB端点恢复失败" in source.error
