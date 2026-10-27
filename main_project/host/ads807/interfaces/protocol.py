"""TCM1 commands and TRI1 records, shared by CLI, GUI and RTL checks."""
from dataclasses import dataclass
import struct
import zlib

import numpy as np

QUERY = 1
MODE = 2
TUNE = 3
QUALITY = 5
STOP = 7
HOLD = 8
FPGA_AUTO = 1
MANUAL = 2
RATE = 43_500_000
COMMAND_VERSION = 2


def command(sequence, opcode, argument=0, rf_hz=0):
    values = (sequence, opcode, argument, rf_hz)
    if any(not isinstance(v, int) or not 0 <= v <= 0xffffffff for v in values):
        raise ValueError("Command fields must be unsigned 32-bit integers")
    if opcode == TUNE:
        # Keep integer rounding identical to the former FPGA divider.
        argument = ((rf_hz - 87_000_000) * (1 << 32) + RATE // 2) // RATE
        if not 0 <= argument <= 0xffffffff:
            raise ValueError("TUNE phase step must fit an unsigned 32-bit integer")
        values = (sequence, opcode, argument, rf_hz)
    packet = bytearray(512)
    struct.pack_into("<4s7I", packet, 0, b"TCM1", COMMAND_VERSION, *values, 0, 0)
    struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
    return bytes(packet)


@dataclass(frozen=True)
class Frame:
    words: tuple
    raw: bytes

    @property
    def kind(self):
        return self.words[2]

    def ack(self):
        if self.kind != 3:
            raise ValueError("Expected ACK record")
        names = ("sequence", "opcode", "error", "mode", "tuned_rf", "phase_step",
                 "epoch", "config_id", "sample_index", "flags", "estimated_rf", "hold_ms")
        return dict(zip(names, struct.unpack_from("<12I", self.raw, 64)))

    def adc(self):
        # Historical RAW files remain readable; new firmware never produces RAW.
        if self.kind != 2:
            raise ValueError("Expected historical RAW record")
        samples = np.frombuffer(self.raw, dtype="<u2", count=self.words[6], offset=64)
        if np.any(samples > 4095):
            raise ValueError("RAW ADC code exceeds 12 bits")
        return samples.copy()


class Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.crc_errors = 0
        self.discarded = 0

    def feed(self, data):
        if len(self.buffer)+len(data) > 1_048_576:
            raise BufferError("TRI1 buffer exceeds 1 MiB")
        self.buffer.extend(data)
        result = []
        while len(self.buffer) >= 4:
            start = self.buffer.find(b"TRI1")
            if start < 0:
                start = len(self.buffer)-3
            if start:
                self.discarded += start
                del self.buffer[:start]
            if len(self.buffer) < 512:
                break
            raw = bytes(self.buffer[:512])
            if zlib.crc32(raw[:508]) != struct.unpack_from("<I", raw, 508)[0]:
                self.crc_errors += 1
                self.discarded += 1
                del self.buffer[0]
                continue
            words = struct.unpack_from("<16I", raw)
            kind, count = words[2], words[6]
            if (words[1] != 0x00400001 or words[7:9] != (RATE, 500_000)
                    or kind not in (1, 2, 3)
                    or kind == 1 and not 1 <= count <= 111
                    or kind == 2 and not 1 <= count <= 222
                    or kind == 3 and count != 48
                    or words[15] != (40 if kind == 1 else 0)):
                raise ValueError("Invalid TRI1 header")
            result.append(Frame(words, raw))
            del self.buffer[:512]
        return result
