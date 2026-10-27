import struct
import zlib

import pytest

from ads807.dual_control_test import ControlSession
from ads807.transport import TransferTimeout
from ads807.interfaces import protocol


@pytest.mark.parametrize("rf,step", [(88_000_000, 98_734_880),
                                    (98_000_000, 1_086_083_684),
                                    (108_000_000, 2_073_432_488),
                                    (98_000_001, 1_086_083_783)])
def test_tune_command_contains_host_step_and_new_version(rf, step):
    packet = protocol.command(42, protocol.TUNE, rf_hz=rf)
    assert struct.unpack_from("<6I", packet, 0) == (
        int.from_bytes(b"TCM1", "little"), 2, 42, 3, step, rf)
    assert not any(packet[24:508])
    assert struct.unpack_from("<I", packet, 508)[0] == zlib.crc32(packet[:508])


@pytest.mark.parametrize("opcode,argument,rf", [(protocol.MODE, 2, 0),
                                               (protocol.QUALITY, 1, 98_000_000),
                                               (protocol.HOLD, 500, 0),
                                               (9, 0xabcdef, 4095)])
def test_non_tune_command_keeps_arguments(opcode, argument, rf):
    packet = protocol.command(7, opcode, argument, rf)
    assert struct.unpack_from("<3I", packet, 12) == (opcode, argument, rf)


class Reader:
    def __init__(self, error=0, wrong_sequence=False, corrupt=False):
        self.error, self.wrong_sequence, self.corrupt = error, wrong_sequence, corrupt
        self.writes = []
        self.frame = 0

    def write(self, packet):
        self.writes.append(packet)

    def read(self, **kwargs):
        sequence, opcode = struct.unpack_from("<2I", self.writes[-1], 8)
        packet = bytearray(512)
        struct.pack_into("<16I", packet, 0, int.from_bytes(b"TRI1", "little"), 0x00400001,
                         3, self.frame, 0, 0, 48, protocol.RATE, 500000, 0, 0, 1, sequence, 0, 0, 0)
        struct.pack_into("<12I", packet, 64, sequence+int(self.wrong_sequence), opcode,
                         self.error, 1, 0, 0, 0, 0, 0, 1, 0, 500)
        struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
        self.frame += 1
        if self.corrupt:
            packet[508] ^= 1
        return bytes(packet)


def test_control_ack_and_expected_rejection_are_observable():
    updates = []
    reader = Reader(error=4)
    session = ControlSession(reader, update=updates.append)
    ack = session.request(protocol.MODE, 0, error=4)
    assert ack["error"] == 4 and updates[-1]["commands"] == 1
    assert len(reader.writes) == 1 and session.decoder.crc_errors == 0


@pytest.mark.parametrize("options,message", [({"wrong_sequence": True}, "ACK sequence"),
                                            ({"corrupt": True}, "CRC"),
                                            ({"error": 4}, "Unexpected ACK")])
def test_control_failure_does_not_resend(options, message):
    reader = Reader(**options)
    with pytest.raises(ValueError, match=message):
        ControlSession(reader).request(protocol.QUERY)
    assert len(reader.writes) == 1


def test_control_checks_global_sequence():
    reader = Reader()
    session = ControlSession(reader)
    session.request(protocol.QUERY)
    reader.frame += 1
    with pytest.raises(ValueError, match="global sequence"):
        session.request(protocol.QUERY)
    assert len(reader.writes) == 2


def test_timeout_does_not_resend(monkeypatch):
    from ads807 import dual_control_test
    reader = Reader()
    clock = iter([0, .5, 1, 1.5, 2])
    monkeypatch.setattr(dual_control_test.time, "perf_counter", lambda: next(clock))

    def read(**kwargs):
        raise TransferTimeout()

    reader.read = read
    with pytest.raises(TimeoutError, match="no retry"):
        ControlSession(reader).request(protocol.QUERY)
    assert len(reader.writes) == 1
