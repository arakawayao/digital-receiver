"""43.5 MS/s RAM replay -> ADS807 DSP -> FCR1 v2 capture on EP4CE6."""
import argparse
from collections import deque
import csv
import json
import math
from pathlib import Path
import struct
import sys
import time
import zlib

from ...paths import HOST_ROOT

PROJECT = HOST_ROOT

from ..receiver_v2.usb_replay import command, upload_commands, STOP
from ..receiver_v2.usb_transport import open_transport, TransferTimeout
from ...protocol import Decoder as IQDecoder
from ...dsp import analyse
import numpy as np

RATE = 43_500_000
IQ_RATE = 500_000


def waveform(kind, rf=98_000_000, length=8192, depth=.5, deviation=25_000, amplitude=800):
    if kind not in ("am", "fm") or not 256 <= length <= 8192:
        raise ValueError("Use am/fm and 256..8192 samples")
    if not all(math.isfinite(value) for value in (rf, depth, deviation, amplitude)):
        raise ValueError("Waveform arguments must be finite")
    if not 88_000_000 <= rf <= 108_000_000 or not 0 < depth < 1 or deviation <= 0:
        raise ValueError("Invalid RF, AM depth or FM deviation")
    if amplitude <= 0 or amplitude * (1 + depth if kind == "am" else 1) > 2047:
        raise ValueError("ADC amplitude must be positive and must not clip")
    carrier_bin = round((rf - 87_000_000) * length / RATE)
    actual_rf = 87_000_000 + carrier_bin * RATE / length
    modulating_hz = RATE / length
    alias_hz = actual_rf - 87_000_000
    bandwidth = modulating_hz + (deviation if kind == "fm" else 0)
    if (not 88_000_000 <= actual_rf <= 108_000_000 or bandwidth > 90_000
            or min(alias_hz, RATE / 2 - alias_hz) < bandwidth):
        raise ValueError("Periodic waveform exceeds the RF/DDC guard bands")
    samples = []
    for index in range(length):
        message_phase = math.tau * index / length
        phase = math.tau * carrier_bin * index / length
        envelope = amplitude * (1 + depth * math.cos(message_phase)) if kind == "am" else amplitude
        if kind == "fm":
            phase += deviation / modulating_hz * math.sin(message_phase)
        samples.append(2048 + round(envelope * math.cos(phase)))
    info = dict(kind=kind, requested_rf_hz=rf, actual_rf_hz=actual_rf,
                adc_rate_hz=RATE, iq_rate_hz=IQ_RATE, length=length,
                modulation_hz=modulating_hz, am_depth=depth, fm_deviation_hz=deviation,
                carrier_amplitude_codes=amplitude,
                source="synthetic ADC12 RAM replay", device="EP4CE6F17C8",
                format="offset binary ADC12 in little-endian u16", protocol="FCR1 v2")
    return samples, info


class Decoder:
    """Bounded, mixed RPA1/FCR1 stream; CRC failures remain observable."""
    def __init__(self):
        self.buffer = bytearray()
        self.crc_errors = 0
        self.discarded = 0

    def feed(self, data):
        if len(self.buffer) + len(data) > 65_536:
            raise BufferError("Replay decoder exceeds 64 KiB")
        self.buffer.extend(data)
        records = []
        while self.buffer:
            positions = [self.buffer.find(magic) for magic in (b"RPA1", b"FCR1")]
            first = min((p for p in positions if p >= 0), default=-1)
            if first < 0:
                remove = max(0, len(self.buffer) - 3)
                self.discarded += remove
                del self.buffer[:remove]
                break
            self.discarded += first
            del self.buffer[:first]
            if len(self.buffer) < 512:
                break
            frame = bytes(self.buffer[:512])
            if zlib.crc32(frame[:508]) != struct.unpack_from("<I", frame, 508)[0]:
                self.crc_errors += 1
                self.discarded += 1
                del self.buffer[0]
                continue
            del self.buffer[:512]
            if frame[:4] == b"RPA1":
                words = struct.unpack_from("<7I", frame)
                if words[1] & 65535 != 1 or any(frame[28:508]):
                    raise ValueError("Invalid replay ACK header")
                records.append(("ack", words, frame))
            else:
                decoder = IQDecoder()
                decoded = decoder.feed(frame)
                if len(decoded) != 1 or decoder.header_errors:
                    raise ValueError("Unexpected IQ protocol/configuration: " + decoder.last_error)
                records.append(("iq", decoded[0], frame))
        return records


def validate_capture(data, info):
    decoder = Decoder()
    records = []
    for offset in range(0, len(data), 32768):
        records.extend(decoder.feed(data[offset:offset + 32768]))
    if decoder.crc_errors or decoder.discarded or decoder.buffer:
        raise ValueError("Capture has CRC errors, discarded bytes or a partial frame")
    frames = [value for kind, value, _ in records if kind == "iq"]
    if not frames or any(kind != "iq" for kind, _, _ in records):
        raise ValueError("Capture must contain only IQ frames")
    first = frames[0]
    if first.sequence != 0 or first.index != 0:
        raise ValueError("Capture must start at frame and sample zero")
    next_index = 0
    for sequence, frame in enumerate(frames):
        if (frame.sequence != sequence or frame.index != next_index
                or frame.epoch != first.epoch or frame.dropped or frame.clipped
                or frame.phase_step != first.phase_step or frame.rf_hz != first.rf_hz):
            raise ValueError("IQ discontinuity, configuration change, overflow or clipping")
        next_index += frame.count
    iq = np.concatenate([frame.samples for frame in frames])
    z = (iq[:, 0].astype(float) + 1j * iq[:, 1]) / 32768
    lo = 87_000_000 + first.phase_step * RATE / 2**32
    measurement = analyse(z[66:], lo)
    result = dict(status="PASS", frames=len(frames), samples=len(iq),
                  source=info["source"], crc_errors=0, dropped=0,
                  measurement=measurement.to_dict())
    # The production classifier sees IQ/LO only; truth is used after measurement.
    if measurement.kind.lower() != info["kind"]:
        raise ValueError("AM/FM classification mismatch: " + str(result))
    if abs(measurement.carrier_hz - info["actual_rf_hz"]) > 12_000:
        raise ValueError("Carrier error exceeds 12 kHz prototype check")
    if info["kind"] == "am" and abs(measurement.am_depth - info["am_depth"]) > .05:
        raise ValueError("AM depth error exceeds 0.05 prototype check")
    if info["kind"] == "fm" and abs(measurement.fm_deviation_hz - info["fm_deviation_hz"]) > max(1500, .1 * info["fm_deviation_hz"]):
        raise ValueError("FM deviation error exceeds prototype check")
    return iq, result


def save_capture(output, data, info):
    output.mkdir(parents=True, exist_ok=True)
    (output / "capture.bin").write_bytes(data)
    (output / "manifest.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    try:
        iq, result = validate_capture(data, info)
    except ValueError as error:
        (output / "result.json").write_text(json.dumps(dict(status="FAIL", reason=str(error)), indent=2), encoding="utf-8")
        raise
    with (output / "iq.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(("sample_index", "i", "q"))
        writer.writerows((n, int(i), int(q)) for n, (i, q) in enumerate(iq))
    (output / "result.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(result, indent=2, ensure_ascii=False), flush=True)
    return result


def run_device(args, samples, info):
    device = open_transport(args.vid, args.pid, "cyusb", dll=args.cyusb_dll)
    decoder = Decoder()
    pending = deque()
    start_sent = False
    sequence = 0

    def read_record(deadline, size=512):
        while time.monotonic() < deadline:
            if pending:
                return pending.popleft()
            try:
                pending.extend(decoder.feed(device.read(0x82, size, timeout=100)))
            except TransferTimeout:
                continue
        raise TimeoutError("EP2 IN receive/ACK timeout")

    def exchange(frame):
        if device.write(0x06, frame, timeout=3000) != 512:
            raise RuntimeError("Short EP6 OUT transfer; command state is unknown")
        requested = struct.unpack_from("<I", frame, 8)[0]
        opcode = struct.unpack_from("<H", frame, 6)[0]
        deadline = time.monotonic() + args.timeout
        while True:
            try:
                kind, words, _ = read_record(deadline)
            except TimeoutError as error:
                raise TimeoutError(f"ACK timeout: opcode={opcode}, sequence={requested}; command state unknown") from error
            if kind == "ack" and words[2] == requested:
                if words[1] >> 16 or words[3] != opcode:
                    raise RuntimeError("Replay command rejected: " + str(words))
                return

    try:
        print(json.dumps(device.describe(), indent=2), flush=True)
        exchange(command(STOP, sequence))
        print("Initial STOP acknowledged", flush=True)
        for frame in upload_commands(samples, 1):
            sequence = struct.unpack_from("<I", frame, 8)[0]
            if struct.unpack_from("<H", frame, 6)[0] == 3:
                start_sent = True
            exchange(frame)
            if sequence % 8 == 0:
                print(f"Upload command {sequence} acknowledged", flush=True)
        print("Upload acknowledged; receiving IQ...", flush=True)
        frames = []
        decoder.crc_errors = 0
        deadline = time.monotonic() + args.timeout
        while len(frames) < args.frames:
            kind, _, raw = read_record(deadline, 32768)
            if kind == "iq":
                frames.append(raw)
        capture_crc_errors = decoder.crc_errors
        exchange(command(STOP, sequence + 1))
        start_sent = False
        data = b"".join(frames)
        if capture_crc_errors:
            args.output.mkdir(parents=True, exist_ok=True)
            (args.output / "capture.bin").write_bytes(data)
            raise ValueError("CRC error observed during USB run")
        return save_capture(args.output, data, info)
    finally:
        if start_sent:
            try:
                exchange(command(STOP, sequence + 2))
            except Exception as error:
                print("Cleanup STOP failed; board state unknown: " + str(error), file=sys.stderr)
        device.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("generate", "probe", "run", "check"))
    parser.add_argument("--kind", choices=("am", "fm"), default="am")
    parser.add_argument("--rf", type=float, default=98_000_000)
    parser.add_argument("--length", type=int, default=8192)
    parser.add_argument("--depth", type=float, default=.5)
    parser.add_argument("--deviation", type=float, default=25_000)
    parser.add_argument("--frames", type=int, default=512)
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--vid", type=lambda value: int(value, 0), default=0x04B4)
    parser.add_argument("--pid", type=lambda value: int(value, 0), default=0x1004)
    parser.add_argument("--cyusb-dll", type=Path)
    parser.add_argument("--output", type=Path, default=PROJECT / ".harness/receiver_replay/live")
    args = parser.parse_args()
    if not 16 <= args.frames <= 4096 or not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("Use 16..4096 frames and a positive finite timeout")
    if args.action == "probe":
        device = open_transport(args.vid, args.pid, "cyusb", dll=args.cyusb_dll)
        try:
            print(json.dumps(device.describe(), indent=2))
        finally:
            device.close()
        return
    if args.action == "check":
        info = json.loads((args.output / "manifest.json").read_text(encoding="utf-8"))
        save_capture(args.output, (args.output / "capture.bin").read_bytes(), info)
        return
    samples, info = waveform(args.kind, args.rf, args.length, args.depth, args.deviation)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "manifest.json").write_text(json.dumps(info, indent=2), encoding="utf-8")
    if args.action == "generate":
        (args.output / "adc_u16le.bin").write_bytes(struct.pack("<" + "H" * len(samples), *samples))
        (args.output / "upload.bin").write_bytes(b"".join(upload_commands(samples)))
        print(json.dumps(info, indent=2))
    else:
        (args.output / "result.json").write_text('{"status": "RUNNING"}', encoding="utf-8")
        try:
            run_device(args, samples, info)
        except (Exception, KeyboardInterrupt) as error:
            (args.output / "result.json").write_text(json.dumps(dict(status="FAIL", reason=str(error)), indent=2), encoding="utf-8")
            raise


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, TimeoutError, BufferError) as error:
        raise SystemExit(str(error))
