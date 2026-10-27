from collections import deque
import struct
import zlib

import pytest

from ads807.dual_control_test import ControlSession
from ads807.dual_sample_test import sample_pairs, upload


class UploadReader:
    def __init__(self, wrong=False):
        self.writes = []
        self.pending = deque()
        self.wrong = wrong

    def write(self, packet):
        self.writes.append(packet)
        self.pending.append(packet)

    def read(self, **kwargs):
        frames = []
        while self.pending:
            packet = self.pending.popleft()
            sequence = struct.unpack_from("<I", packet, 8)[0]
            frame = bytearray(512)
            count = len(self.writes)-len(self.pending)-1
            struct.pack_into("<16I", frame, 0, int.from_bytes(b"TRI1", "little"), 0x00400001,
                             3, count, 0, 0, 48, 43500000, 500000, 0, 0, 2, sequence, 0, 0, 0)
            struct.pack_into("<12I", frame, 64, sequence+int(self.wrong), 9, 0, 2, 0, 0, 0, 0, 0, 2, 0, 500)
            struct.pack_into("<I", frame, 508, zlib.crc32(frame[:508]))
            frames.append(frame)
        return b"".join(frames)


def test_upload_packing_and_all_acknowledgements():
    samples = list(range(4096))*2
    reader = UploadReader()
    result = upload(ControlSession(reader), samples)
    assert result["samples"] == 8192 and result["write_commands"] == 4096
    assert result["crc_errors"] == 0 and result["frames"] == 4096
    for address, packet in enumerate(reader.writes):
        opcode, pair, index = struct.unpack_from("<3I", packet, 12)
        assert (opcode, index) == (9, address)
        assert pair & 4095 == samples[address*2]
        assert pair >> 12 == samples[address*2+1]


def test_upload_ack_mismatch_does_not_retry():
    reader = UploadReader(wrong=True)
    with pytest.raises(ValueError, match="mismatched ACK"):
        upload(ControlSession(reader), [2048]*8192)
    assert len(reader.writes) == 32


@pytest.mark.parametrize("samples", [[2048]*8191, [-1]*8192, [4096]*8192])
def test_upload_rejects_invalid_adc_samples(samples):
    with pytest.raises(ValueError):
        sample_pairs(samples)
