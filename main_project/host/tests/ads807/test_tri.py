"""TRI1 integration with an independent, deterministic duplex firmware model."""
from collections import deque
from pathlib import Path
import struct
import threading
import time
import zlib

import numpy as np
import pytest

from ads807.protocol import Continuity, Decoder, Frame
from ads807.runtime import Controller
from ads807.sources import SourceConfig
from ads807.transport import TransferTimeout
from ads807.gui import Window, wire


def packet(kind=1, sequence=0, epoch=1, index=0, config=1, flags=0x300,
           rf=100_000_000, payload=None, auxiliary=0):
    if payload is None:
        payload = np.zeros((111, 2), dtype="<i2").tobytes()
    count = len(payload)//(4 if kind == 1 else 2) if kind != 3 else 48
    step = round((rf-87_000_000)*2**32/43_500_000) if rf else 0
    words = (0x31495254, 0x00400001, kind, sequence, epoch, index, count,
             43_500_000, 500_000, rf, step, flags, auxiliary, config,
             4096 if kind == 2 else rf, 40 if kind == 1 else 0)
    body = struct.pack("<16I", *words)+payload.ljust(444, b"\0")
    return body+struct.pack("<I", zlib.crc32(body))


def test_mixed_frames_and_low_confidence_do_not_break_iq():
    decoder = Decoder()
    continuity = Continuity()
    stream = (packet(sequence=10)+packet(3, 11, payload=bytes(48))
              +packet(2, 12, payload=bytes(444), auxiliary=7)
              +packet(sequence=13, index=111, flags=0x100))
    decoded = []
    for offset in range(0, len(stream), 71):
        decoded.extend(decoder.feed(stream[offset:offset+71]))
    iq = [f for f in decoded if isinstance(f, Frame)]
    assert len(decoded) == 4 and len(iq) == 2
    assert not continuity.accept(iq[0])
    assert not continuity.accept(iq[1])
    assert continuity.gaps == decoder.transport_gaps == 0
    assert iq[0].samples.shape == (111, 2)


def test_global_frame_gap_and_configuration_change_are_observable():
    decoder = Decoder()
    continuity = Continuity()
    continuity.accept(decoder.feed(packet(sequence=0xffffffff))[0])
    assert not continuity.accept(decoder.feed(packet(sequence=0, index=111))[0])
    assert continuity.accept(decoder.feed(packet(sequence=2, index=222))[0])
    assert decoder.transport_gaps == continuity.gaps == 1
    assert continuity.accept(decoder.feed(packet(sequence=3, index=333, config=2))[0])
    assert continuity.missing_samples == 0


def test_crc_failure_resynchronizes_and_marks_next_iq():
    decoder = Decoder()
    decoder.feed(packet())
    corrupt = bytearray(packet(sequence=1, index=111))
    corrupt[100] ^= 1
    result = decoder.feed(corrupt+packet(sequence=2, index=222))
    assert len(result) == 1 and result[0].transport_gap
    assert decoder.crc_errors == 1


class FirmwareUSB:
    instances = []

    def __init__(self, *args, **kwargs):
        assert kwargs["duplex"]
        self.pending = deque()
        self.wire_lock = threading.RLock()
        self.commands = []
        self.seq = 0
        self.epoch = 0
        self.config = 0
        self.index = 0
        self.mode = 1
        self.flags = 1
        self.rf = 0
        self.hold = 500
        self.transient = False
        self.weak = False
        self.pump_started = False
        self.pipes_ready = False
        self.rng = np.random.default_rng(807)
        self.instances.append(self)

    def start_pump(self):
        assert not self.commands and self.pipes_ready
        self.pump_started = True

    def reset_endpoints(self):
        self.pump_started = False
        self.pipes_ready = True

    def frame(self, kind, payload, auxiliary=0, index=None, flags=None):
        result = packet(kind, self.seq, self.epoch, self.index if index is None else index,
                        self.config, self.flags if flags is None else flags,
                        self.rf, payload, auxiliary)
        self.seq = (self.seq+1) & 0xffffffff
        return result

    def write(self, raw):
        with self.wire_lock:
            self._write(raw)

    def _write(self, raw):
        assert len(raw) == 512 and raw[:4] == b"TCM1"
        assert zlib.crc32(raw[:508]) == struct.unpack_from("<I", raw, 508)[0]
        _, version, seq, op, arg, rf, r0, r1 = struct.unpack_from("<4s7I", raw)
        assert version == 2 and r0 == r1 == 0 and not any(raw[32:508])
        self.commands.append((op, arg, rf))
        if op == 2:
            assert arg in (1, 2)
            self.mode = arg
            self.flags = arg
            self.rf = 0
            self.epoch += 1
            self.config += 1
            self.index = 0
            if arg == 1:
                self.rf = 100_000_000
                self.flags |= 0x300
        elif op == 3:
            assert self.mode == 2
            assert arg == ((rf-87_000_000)*2**32+21_750_000)//43_500_000
            self.epoch += 1
            self.index = 0
            self.config += 1
            self.rf = rf
            self.flags |= 256
            self.transient = True
        elif op == 5:
            assert self.mode == 2
            self.flags = (self.flags & ~512) | (512 if arg else 0)
        elif op == 7:
            self.flags &= ~256
        elif op == 8:
            self.hold = arg
        assert op not in (4, 6), "Removed host search/track command was sent"
        step = round((self.rf-87_000_000)*2**32/43_500_000) if self.rf else 0
        ack = struct.pack("<12I", seq, op, 0, self.mode, self.rf, step, self.epoch,
                          self.config, self.index, self.flags, self.rf, self.hold)
        self.pending.append(self.frame(3, ack, seq))

    def read(self):
        time.sleep(.008)
        # ACK and IQ share one ordered wire even when OUT and IN run concurrently.
        with self.wire_lock:
            return self._read()

    def _read(self):
        if self.pending:
            output = b"".join(self.pending)
            self.pending.clear()
            return output
        if not self.flags & 256:
            raise TransferTimeout()
        count = 40*111
        t = (self.index+np.arange(count))/500_000
        if self.weak:
            z = .00001*(self.rng.normal(size=count)+1j*self.rng.normal(size=count))
        else:
            signal_rf = getattr(self, "signal_rf", 100_001_700)
            z = .35*(1+.6*np.cos(2*np.pi*1000*t))*np.exp(2j*np.pi*(signal_rf-self.rf)*t)
        iq = np.rint(np.column_stack((z.real, z.imag))*32768).astype("<i2")
        result = []
        for start in range(0, count, 111):
            flags = self.flags | (4096 if self.transient else 0)
            self.transient = False
            result.append(self.frame(1, iq[start:start+111].tobytes(), flags=flags))
            self.index += 111
        return b"".join(result)

    def close(self):
        pass


@pytest.mark.parametrize("mode", [1, 2])
def test_gui_runtime_two_modes_and_stop_ack(qtbot, monkeypatch, mode, tmp_path, qapp):
    import ads807.sources as sources
    monkeypatch.setattr(sources, "CyUSBReader", FirmwareUSB)
    qapp.setStyle("Fusion")
    qapp.setStyleSheet((Path(__file__).resolve().parents[2]/"ads807/theme.qss").read_text(encoding="utf-8"))
    controller = Controller()
    window = Window(tmp_path)
    wire(window, controller)
    qtbot.addWidget(window)
    window.show()
    window.tuning_mode.setCurrentIndex(window.tuning_mode.findData(mode))
    try:
        window.request_start()
        qtbot.waitUntil(lambda: window.kind_label.text() == "AM", timeout=8000)
        firmware = FirmwareUSB.instances[-1]
        assert firmware.pump_started
        assert controller.source.config.usb_managed_pump
        if mode != 1:
            qtbot.waitUntil(lambda: any(op == 5 for op, _, _ in firmware.commands), timeout=5000)
        qtbot.waitUntil(lambda: window.current is not None
                        and window.current["measurement"]["kind"] == "AM"
                        and len(window.current["audio"]) > 0
                        and np.max(np.abs(window.current["audio"])) > .05, timeout=5000)
        ops = [c[0] for c in firmware.commands]
        assert ops[:3] == [1, 2, 8]
        assert 4 not in ops
        assert (3 in ops) == (mode != 1)
        assert 6 not in ops
        assert (5 in ops) == (mode != 1)
        assert controller.processor.continuity.gaps == 0
        assert controller.processor.error == ""
        qtbot.waitUntil(lambda: controller.processor.display(20) is not None, timeout=3000)
        capture = controller.processor.capture()
        assert capture["transport_config"]["protocol"] == "TRI1"
        assert capture["source_config"]["tuning_mode"] == mode
        assert np.all(np.diff(capture["indices"]) == 1)
        qtbot.waitUntil(lambda: "100." in window.tuning_values.text(), timeout=3000)
        assert window.grab().save(str(tmp_path/f"tri_mode_{mode}.png"))
        if mode == 2:
            firmware.weak = True
            recoveries = controller.processor.recoveries
            qtbot.waitUntil(lambda: not controller.processor.tuning.view()["flags"] & 512, timeout=4000)
            qtbot.wait(650)
            assert controller.processor.recoveries == recoveries
            assert len([c for c in firmware.commands if c[0] == 3]) == 1
        controller.stop()
        qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
        assert firmware.commands[-1][0] == 7
        assert controller.processor.tuning.view()["flags"] & 256 == 0
        assert not controller.processor.tuning.is_alive()
        assert not controller.last_error
    finally:
        controller.shutdown()
        window.allow_close = True
        window.close()


def test_tri_file_replay_never_sends_commands(qtbot, tmp_path):
    firmware = FirmwareUSB(duplex=True)
    firmware.mode, firmware.rf, firmware.flags = 2, 100_000_000, 0x302
    path = tmp_path/"transport.fcr"
    path.write_bytes(b"".join(firmware.read() for _ in range(20)))
    controller = Controller()
    try:
        controller.start(SourceConfig("文件回放", path=str(path)))
        qtbot.waitUntil(lambda: controller.processor.result.kind == "AM", timeout=5000)
        assert controller.processor.tuning is None
        assert controller.processor.stats()["tuning"]["mode"] == 2
        assert controller.processor.continuity.gaps == 0
    finally:
        controller.shutdown()


def test_manual_restart_retunes_persistent_device_without_removing_am(qtbot, monkeypatch):
    import ads807.sources as sources

    device = FirmwareUSB(duplex=True)
    monkeypatch.setattr(sources, "CyUSBReader", lambda *args, **kwargs: device)
    controller = Controller()
    logs = []
    controller.log.connect(logs.append)
    try:
        for rf in (98_000_000, 103_700_000, 99_500_000):
            # The physical FPGA, counters and AM generator persist while the
            # host workers are replaced. Only the generator carrier changes.
            device.signal_rf = rf+1700
            before = len(device.commands)
            controller.start(SourceConfig("USB", tuning_mode=2, rf_hz=rf))
            qtbot.waitUntil(lambda: controller.processor.result.kind == "AM"
                            and controller.processor.display(20) is not None, timeout=6000)
            view = controller.processor.display(20)
            assert abs(view["measurement"]["carrier_hz"]-device.signal_rf) < 100
            assert np.max(np.abs(view["audio"])) > .05
            commands = device.commands[before:]
            assert [op for op, _, _ in commands[:4]] == [1, 2, 8, 3]
            assert commands[3][2] == rf
            assert any(f"本次手动载频 {rf/1e6:.6f} MHz" in line for line in logs)
            assert controller.processor.decoder.crc_errors == 0
            assert controller.processor.continuity.gaps == 0
            controller.stop()
            qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
            assert device.commands[-1][0] == 7
            assert not controller.last_error
    finally:
        controller.shutdown()


def test_auto_without_lock_reports_fpga_state_without_retuning(qtbot, monkeypatch):
    import ads807.sources as sources

    class NoAutoLock(FirmwareUSB):
        def _write(self, raw):
            super()._write(raw)
            if struct.unpack_from("<I", raw, 12)[0] == 2:
                self.flags = 1
                self.rf = 0

    monkeypatch.setattr(sources, "CyUSBReader", NoAutoLock)
    controller = Controller()
    logs = []
    controller.log.connect(logs.append)
    try:
        controller.start(SourceConfig("USB", tuning_mode=1))
        qtbot.waitUntil(lambda: any("FPGA 尚未获得调谐参数" in line for line in logs), timeout=5000)
        device = FirmwareUSB.instances[-1]
        assert sum(op == 1 for op, _, _ in device.commands) >= 2
        assert [op for op, _, _ in device.commands[:3]] == [1, 2, 8]
        assert not any(op in (3, 4, 5, 6) for op, _, _ in device.commands)
        assert "尚未启动 I/Q" in controller.processor.tuning.view()["message"]
        assert controller.processor.display(20) is None
        assert not controller.last_error
        controller.stop()
        qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
        assert device.commands[-1][0] == 7
    finally:
        controller.shutdown()


def test_missing_iq_manual_holds_setting_without_host_search(qtbot, monkeypatch):
    import ads807.sources as sources
    class NoIQ(FirmwareUSB):
        def read(self):
            if self.pending or not self.flags & 256:
                return super().read()
            time.sleep(.008)
            raise TransferTimeout()
    monkeypatch.setattr(sources, "CyUSBReader", NoIQ)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB", tuning_mode=2, hold_ms=100))
        qtbot.waitUntil(lambda: controller.source.connected, timeout=2000)
        firmware = FirmwareUSB.instances[-1]
        qtbot.waitUntil(lambda: any(op == 5 and arg == 0 for op, arg, _ in firmware.commands), timeout=5000)
        qtbot.wait(650)
        assert sum(op == 3 for op, _, _ in firmware.commands) == 1
        assert not any(op in (4, 6) for op, _, _ in firmware.commands)
        assert controller.processor.error == ""
        assert controller.processor.display(20) is None
        assert any(op == 5 and arg == 0 for op, arg, _ in firmware.commands)
        controller.stop()
        qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
        assert not controller.last_error
    finally:
        controller.shutdown()


def test_removed_host_auto_configuration_is_rejected():
    with pytest.raises(ValueError, match="FPGA"):
        SourceConfig("USB", tuning_mode=0)


@pytest.mark.parametrize("field,value,diagnostic", [
    ("error", 2, "v2"),
    ("mode", 1, "mode"),
    ("tuned_rf", 99_000_000, "tuned_rf"),
    ("phase_step", 1, "phase_step"),
    ("flags", 2, "调谐使能"),
])
def test_tune_ack_version_and_readback_are_checked(field, value, diagnostic):
    from types import SimpleNamespace
    from ads807.interfaces import protocol as tri
    from ads807.tuning import TuningSession

    sent = []
    source = SimpleNamespace(config=SourceConfig(tuning_mode=2), error="", ended=False)
    session = TuningSession(source)

    def send(raw):
        sent.append(raw)
        seq = struct.unpack_from("<I", raw, 8)[0]
        ack = dict(sequence=seq, opcode=tri.TUNE, error=0, mode=2,
                   tuned_rf=98_000_000, phase_step=1_086_083_684, epoch=1,
                   config_id=1, sample_index=0, flags=0x102, estimated_rf=0, hold_ms=500)
        ack[field] = value
        payload = struct.pack("<12I", *ack.values())
        session.offer(tri.Decoder().feed(packet(3, payload=payload))[0])

    source.send = send
    with pytest.raises(RuntimeError, match=diagnostic):
        session.request(tri.TUNE, rf_hz=98_000_000)
    assert len(sent) == 1
    assert session.command_count == 0


def test_rejected_tune_is_reported_and_not_retried(qtbot, monkeypatch):
    import ads807.sources as sources
    class RejectedTune(FirmwareUSB):
        def write(self, raw):
            with self.wire_lock:
                super().write(raw)
                if struct.unpack_from("<I", raw, 12)[0] == 3:
                    reply = bytearray(self.pending.pop())
                    struct.pack_into("<I", reply, 72, 4)
                    struct.pack_into("<I", reply, 508, zlib.crc32(reply[:508]))
                    self.pending.append(bytes(reply))
    monkeypatch.setattr(sources, "CyUSBReader", RejectedTune)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB", tuning_mode=2))
        qtbot.waitUntil(lambda: controller.state == "错误", timeout=5000)
        assert "error=4" in controller.last_error
        qtbot.waitUntil(lambda: not controller.processor.isRunning(), timeout=4000)
        assert sum(c[0] == 3 for c in FirmwareUSB.instances[-1].commands) == 1
        assert controller.processor.display(20) is None
    finally:
        controller.shutdown()


def test_stop_without_ack_is_reported_as_unconfirmed(qtbot, monkeypatch):
    import ads807.sources as sources
    class LostStopAck(FirmwareUSB):
        def write(self, raw):
            with self.wire_lock:
                super().write(raw)
                if struct.unpack_from("<I", raw, 12)[0] == 7:
                    self.pending.pop()
    monkeypatch.setattr(sources, "CyUSBReader", LostStopAck)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB", tuning_mode=1))
        qtbot.waitUntil(lambda: controller.processor.processed > 30000, timeout=5000)
        controller.stop()
        qtbot.waitUntil(lambda: controller.state == "错误", timeout=5000)
        assert "命令 7" in controller.last_error and "ACK" in controller.last_error
        assert sum(c[0] == 7 for c in FirmwareUSB.instances[-1].commands) == 1
    finally:
        controller.shutdown()


def test_stop_ack_is_routed_while_dsp_is_blocked(qtbot, monkeypatch):
    import ads807.sources as sources
    from ads807.runtime import Processing
    entered = threading.Event()
    release = threading.Event()

    def blocked_dsp(self, frame):
        entered.set()
        if not release.wait(5):
            raise TimeoutError("Test did not release DSP")

    monkeypatch.setattr(sources, "CyUSBReader", FirmwareUSB)
    monkeypatch.setattr(Processing, "process_pending", blocked_dsp)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB", tuning_mode=2))
        qtbot.waitUntil(entered.is_set, timeout=3000)
        controller.stop()
        qtbot.waitUntil(lambda: not controller.processor.tuning.is_alive(), timeout=1500)
        assert controller.processor.isRunning()
        assert controller.source.isRunning()
        assert not controller.processor.tuning.error
        assert FirmwareUSB.instances[-1].commands[-1][0] == 7
        release.set()
        qtbot.waitUntil(lambda: controller.state == "已停止", timeout=3000)
        assert not controller.processor.receiver.is_alive()
    finally:
        release.set()
        controller.shutdown()


def test_dsp_failure_still_receives_stop_ack(qtbot, monkeypatch):
    import ads807.sources as sources
    from ads807.runtime import Processing

    def failing_dsp(self, frame):
        raise RuntimeError("simulated DSP failure")

    monkeypatch.setattr(sources, "CyUSBReader", FirmwareUSB)
    monkeypatch.setattr(Processing, "process_pending", failing_dsp)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB", tuning_mode=2))
        qtbot.waitUntil(lambda: controller.state == "错误", timeout=5000)
        qtbot.waitUntil(lambda: not controller.processor.isRunning(), timeout=3000)
        assert "simulated DSP failure" in controller.last_error
        assert not controller.processor.tuning.error
        assert FirmwareUSB.instances[-1].commands[-1][0] == 7
        assert not controller.processor.receiver.is_alive()
    finally:
        controller.shutdown()


def test_dsp_queue_overflow_preserves_ack_and_marks_iq_gap():
    import queue
    from ads807.audio import AudioOutput
    from ads807.runtime import Processing
    from ads807.sources import Acquisition
    ingress = queue.Queue(128)
    source = Acquisition(SourceConfig("USB"), ingress)
    processor = Processing(ingress, source, AudioOutput())
    router = processor.receiver
    router.batches = queue.Queue(1)
    router.route(packet(sequence=0))
    router.route(packet(sequence=1, index=111)+packet(3, sequence=2, payload=bytes(48)))
    assert processor.tuning.events.get_nowait().kind == 3
    assert router.dropped_samples == 111
    assert processor.stats()["queue_dropped_bytes"] == 1024
    continuity = Continuity()
    assert not continuity.accept(router.batches.get_nowait()[0])
    router.route(packet(sequence=3, index=222))
    assert continuity.accept(router.batches.get_nowait()[0])
    assert continuity.gaps == 1 and continuity.missing_samples == 111
    assert processor.decoder.transport_gaps == 0
