"""FCR1 v2 as emitted by receiver_ads807/rtl/rx_packet.v."""
from dataclasses import dataclass
import struct
import zlib

import numpy as np

from .interfaces import protocol as tri

BLOCK = 512
HEADER = 60
CAPACITY = 112
ADC_RATE = 43_500_000
IQ_RATE = 500_000
MASK = 0xFFFFFFFF


@dataclass(frozen=True)
class Frame:
    sequence: int
    epoch: int
    index: int
    count: int
    dropped: int
    adc_rate: int
    iq_rate: int
    rf_hz: int
    phase_step: int
    flags: int
    shift: int
    samples: np.ndarray
    raw: bytes
    protocol: str = "FCR1"
    config_id: int = 0
    estimated_rf: int = 0
    transport_gap: bool = False

    @property
    def clipped(self):
        return bool(self.flags & (1 << 11 if self.protocol == "TRI1" else 4))

    @property
    def transient(self):
        return bool(self.flags & (1 << 12 if self.protocol == "TRI1" else 8))


class Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.crc_errors = 0
        self.header_errors = 0
        self.discarded_bytes = 0
        self.frames = 0
        self.last_error = ""
        self.tri_sequence = None
        self.transport_gaps = 0
        self.pending_gap = False

    def feed(self, data):
        if len(self.buffer)+len(data) > 1_048_576:
            raise BufferError("协议接收缓冲超过 1 MiB")
        self.buffer.extend(data)
        result = []
        while self.buffer:
            positions = [self.buffer.find(magic) for magic in (b"FCR1", b"TRI1")]
            pos = min((p for p in positions if p >= 0), default=-1)
            if pos < 0:
                remove = max(0, len(self.buffer) - 3)
                self.discarded_bytes += remove
                del self.buffer[:remove]
                break
            self.discarded_bytes += pos
            del self.buffer[:pos]
            if len(self.buffer) < BLOCK:
                break
            packet = bytes(self.buffer[:BLOCK])
            if zlib.crc32(packet[:508]) != struct.unpack_from("<I", packet, 508)[0]:
                self.crc_errors += 1
                self.last_error = "CRC32 校验失败"
                self.pending_gap = True
                self.discarded_bytes += 1
                del self.buffer[0]
                continue
            if packet[:4] == b"TRI1":
                try:
                    parsed = tri.Decoder().feed(packet)[0]
                    h = parsed.words
                    used = h[6]*4 if h[2] == 1 else h[6]*2 if h[2] == 2 else 48
                    if (h[11] & ~0x3F03 or h[11] & 3 == 3
                            or any(packet[64+used:508])):
                        raise ValueError("TRI1 flags 或填充错误")
                    if h[2] == 1 and (not h[11] & 256 or not 88_000_000 <= h[9] <= 108_000_000
                                     or h[10] >= 0x80000000):
                        raise ValueError("TRI1 I/Q 调谐参数错误")
                    if h[2] == 2:
                        parsed.adc()
                except ValueError as error:
                    self.header_errors += 1
                    self.last_error = str(error)
                    self.pending_gap = True
                    del self.buffer[:BLOCK]
                    continue
                if self.tri_sequence is not None and h[3] != (self.tri_sequence+1) & MASK:
                    self.transport_gaps += 1
                    self.pending_gap = True
                self.tri_sequence = h[3]
                if parsed.kind == 1:
                    samples = np.frombuffer(packet, dtype="<i2", count=h[6]*2, offset=64).reshape(-1, 2).copy()
                    parsed = Frame(h[3], h[4], h[5], h[6], h[12], h[7], h[8], h[9], h[10],
                                   h[11], h[15], samples, packet, "TRI1", h[13], h[14], self.pending_gap)
                    self.pending_gap = False
                result.append(parsed)
                self.frames += 1
                del self.buffer[:BLOCK]
                continue
            h = struct.unpack_from("<15I", packet)
            valid = (h[1] == 0x003C0002 and 1 <= h[5] <= CAPACITY
                     and h[7] == ADC_RATE and h[8] == IQ_RATE
                     and 88_000_000 <= h[9] <= 108_000_000
                     and h[10] < 0x80000000
                     and h[11] & ~0x1F == 0 and h[11] & 0x10
                     and not h[11] & 2 and h[12:15] == (40, CAPACITY, 0)
                     and not any(packet[HEADER + h[5]*4:508]))
            if not valid:
                self.header_errors += 1
                self.last_error = f"拒绝不匹配的 ADS807 帧：v={h[1]&65535}, ADC={h[7]}, IQ={h[8]}, flags={h[11]:#x}"
                self.discarded_bytes += 1
                del self.buffer[0]
                continue
            samples = np.frombuffer(packet, dtype="<i2", count=h[5]*2, offset=HEADER).reshape(-1, 2).copy()
            result.append(Frame(*h[2:13], samples, packet))
            self.frames += 1
            del self.buffer[:BLOCK]
        return result


class Continuity:
    def __init__(self):
        self.previous = None
        self.gaps = 0
        self.epoch_changes = 0
        self.missing_samples = 0
        self.clipped_frames = 0
        self.index_wraps = 0

    def accept(self, frame):
        previous = self.previous
        reset = False
        if previous is not None:
            if frame.epoch != previous.epoch:
                self.epoch_changes += 1
                reset = True
            else:
                expected_index = (previous.index + previous.count) & MASK
                if ((frame.protocol == "FCR1" and frame.sequence != (previous.sequence + 1) & MASK)
                        or frame.transport_gap
                        or frame.index != expected_index):
                    self.gaps += 1
                    delta = (frame.index - expected_index) & MASK
                    if delta < 0x80000000:
                        self.missing_samples += delta
                    reset = True
                if frame.index < previous.index:
                    self.index_wraps += 1
                    reset = True
                if (frame.phase_step, frame.rf_hz, frame.config_id, frame.protocol) != (previous.phase_step, previous.rf_hz, previous.config_id, previous.protocol):
                    reset = True
        if frame.clipped:
            self.clipped_frames += 1
        self.previous = frame
        return reset


def encode_frame(samples, sequence=0, epoch=1, index=0, rf_hz=100_000_000,
                 dropped=0, flags=0x10):
    """Build synthetic/replay transport data; never called to repair USB data."""
    samples = np.asarray(samples)
    if samples.ndim != 2 or samples.shape[1] != 2 or not 1 <= len(samples) <= CAPACITY:
        raise ValueError("Expected 1..112 I/Q pairs")
    if not np.isfinite(samples).all() or np.any(samples < -32768) or np.any(samples > 32767):
        raise ValueError("I/Q outside signed16 range")
    packet = bytearray(BLOCK)
    phase = round((rf_hz - 87_000_000) / ADC_RATE * 2**32)
    struct.pack_into("<4s14I", packet, 0, b"FCR1", 0x003C0002,
                     sequence & MASK, epoch & MASK, index & MASK, len(samples), dropped,
                     ADC_RATE, IQ_RATE, rf_hz, phase, flags, 40, CAPACITY, 0)
    packet[HEADER:HEADER + len(samples)*4] = samples.astype("<i2").tobytes()
    struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
    return bytes(packet)
