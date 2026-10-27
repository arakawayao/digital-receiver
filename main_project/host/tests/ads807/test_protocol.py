import struct
import zlib

import numpy as np
import pytest

from ads807.protocol import Continuity, Decoder, encode_frame


def rewrite(packet, offset, value):
    packet = bytearray(packet)
    struct.pack_into("<I", packet, offset, value)
    struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
    return bytes(packet)


def frame(sequence=0, index=0, epoch=1, **kwargs):
    return Decoder().feed(encode_frame(np.array([[-32768, 32767], [0, -1]]),
                                      sequence, epoch, index, **kwargs))[0]


@pytest.mark.parametrize("split", [1, 3, 4, 59, 60, 117, 508, 511])
def test_arbitrary_usb_boundaries(split):
    packet = encode_frame(np.array([[-32768, 32767], [0, -1]]))
    decoder = Decoder()
    assert decoder.feed(packet[:split]) == []
    frames = decoder.feed(packet[split:])
    assert len(frames) == 1
    assert frames[0].samples.tolist() == [[-32768, 32767], [0, -1]]
    assert frames[0].shift == 40
    assert frames[0].adc_rate == 43500000
    assert decoder.discarded_bytes == 0


def test_recover_after_noise_crc_and_truncated_magic():
    packet = encode_frame(np.zeros((112, 2)))
    corrupt = bytearray(packet)
    corrupt[90] ^= 0x80
    decoder = Decoder()
    frames = []
    raw = b"junkFCR" + bytes(corrupt) + b"tail" + packet + packet
    for offset in range(0, len(raw), 113):
        frames.extend(decoder.feed(raw[offset:offset+113]))
    assert len(frames) == 2
    assert decoder.crc_errors == 1
    assert len(decoder.buffer) == 0
    assert decoder.discarded_bytes > 512


@pytest.mark.parametrize("offset,value", [(4, 0x003C0003), (20, 0), (20, 113),
    (28, 32000000), (28, 56000000), (32, 50000), (36, 3000000),
    (40, 0xFFFFFFFF), (44, 0x12), (44, 0), (44, 0x30), (48, 42), (52, 111), (56, 1)])
def test_reject_valid_crc_but_wrong_configuration(offset, value):
    packet = encode_frame(np.zeros((2, 2)))
    decoder = Decoder()
    assert decoder.feed(rewrite(packet, offset, value)) == []
    assert decoder.header_errors == 1


def test_reject_nonzero_padding():
    packet = encode_frame(np.zeros((2, 2)))
    decoder = Decoder()
    assert not decoder.feed(rewrite(packet, 100, 12))
    assert decoder.header_errors == 1


def test_independently_packed_rtl_layout():
    packet = bytearray(512)
    header = [0x31524346, 0x003C0002, 7, 3, 500, 1, 9,
              43500000, 500000, 100000000, 1283587950, 0x15, 40, 112, 0]
    struct.pack_into("<15I", packet, 0, *header)
    struct.pack_into("<hh", packet, 60, -1234, 2345)
    struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
    decoded = Decoder().feed(packet)[0]
    assert (decoded.sequence, decoded.epoch, decoded.index, decoded.dropped, decoded.flags) == (7, 3, 500, 9, 0x15)
    assert decoded.samples.tolist() == [[-1234, 2345]]


def test_continuity_history_is_not_a_current_gap():
    continuity = Continuity()
    assert not continuity.accept(frame(index=100, dropped=500, flags=0x11))
    assert not continuity.accept(frame(sequence=1, index=102, dropped=500, flags=0x11))
    assert continuity.gaps == 0
    assert continuity.accept(frame(sequence=3, index=108, dropped=504, flags=0x11))
    assert (continuity.gaps, continuity.missing_samples) == (1, 4)
    assert continuity.accept(frame(epoch=2))
    assert continuity.epoch_changes == 1


def test_uint32_wrap_without_false_missing():
    continuity = Continuity()
    continuity.accept(frame(sequence=0xFFFFFFFF, index=0xFFFFFFFE))
    assert continuity.accept(frame(sequence=0, index=0))
    assert continuity.gaps == 0
    assert continuity.missing_samples == 0
    assert continuity.index_wraps == 1
