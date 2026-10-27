"""Upload once, continuously receive/check free-running FPGA replay until the deadline."""
import argparse
from collections import deque
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
import json
import math
from pathlib import Path
import queue
import struct
import sys
import threading
import time

import numpy as np

from ...paths import HOST_ROOT

PROJECT = HOST_ROOT
from .replay import Decoder, waveform, RATE, IQ_RATE
from ..receiver_v2.usb_replay import command, upload_commands, STOP
from ..receiver_v2.usb_transport import open_transport, TransferTimeout
from ...dsp import analyse

MASK = 0xFFFFFFFF


class Monitor:
    """Constant-space, wrap-aware continuity validation for every received sample."""
    def __init__(self):
        self.frames = 0
        self.samples = 0
        self.first = None
        self.previous = None
        self.sample_wraps = 0
        self.tail = deque(maxlen=512)

    def observe(self, frame):
        previous = self.previous
        if previous is None:
            if frame.sequence != 0 or frame.index != 0:
                raise ValueError("Initial frame/sample index is not zero")
            self.first = frame
        else:
            if frame.sequence != (previous.sequence + 1) & MASK:
                raise ValueError("Frame sequence gap/repeat")
            if frame.index != (previous.index + previous.count) & MASK:
                raise ValueError("IQ sample index gap/repeat")
            if (frame.epoch, frame.phase_step, frame.rf_hz) != (previous.epoch, previous.phase_step, previous.rf_hz):
                raise ValueError("Unexpected epoch/tuning change or FPGA stream restart")
            if frame.index < previous.index:
                self.sample_wraps += 1
        if frame.dropped or frame.clipped:
            raise ValueError(f"FPGA dropped={frame.dropped}, clipped={frame.clipped}")
        self.frames += 1
        self.samples += frame.count
        self.previous = frame
        self.tail.append(frame)

    def analysis_input(self):
        if self.samples < 8192 + 66:
            return None
        samples = np.concatenate([frame.samples for frame in list(self.tail)[-80:]])[-8192:]
        z = (samples[:, 0].astype(float) + 1j * samples[:, 1]) / 32768
        lo = 87_000_000 + self.previous.phase_step * RATE / 2**32
        return z, lo


def measure(values, info):
    result = analyse(*values)
    if result.kind.lower() != info["kind"]:
        raise ValueError("Periodic IQ classification failed: " + str(result.to_dict()))
    if abs(result.carrier_hz - info["actual_rf_hz"]) > 12_000:
        raise ValueError("Periodic carrier error exceeds 12 kHz")
    if info["kind"] == "am" and abs(result.am_depth - info["am_depth"]) > .05:
        raise ValueError("Periodic AM depth error exceeds 0.05")
    if info["kind"] == "fm" and abs(result.fm_deviation_hz - info["fm_deviation_hz"]) > max(1500, .1 * info["fm_deviation_hz"]):
        raise ValueError("Periodic FM deviation exceeds prototype tolerance")
    return result.to_dict()


def write_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False), encoding="utf-8")
    temporary.replace(path)


def run(args):
    samples, info = waveform(args.kind, args.rf)
    args.output.mkdir(parents=True, exist_ok=True)
    write_json(args.output / "manifest.json", info)
    monitor = Monitor()
    decoder = Decoder()
    pending = deque()
    device = None
    reader = None
    started = False
    sequence = 0
    stop_event = threading.Event()
    ingress = queue.Queue(maxsize=128)
    reader_failure = []
    receiver = {"bytes": 0, "timeouts": 0, "queue_high_water": 0, "queue_overflows": 0}
    summary = dict(status="RUNNING", started_local=datetime.now().astimezone().isoformat(),
                   source=info["source"], kind=args.kind, requested_seconds=args.seconds,
                   elapsed_seconds=0, frames=0, samples=0, crc_errors=0, discarded_bytes=0,
                   analysis_checks=0, latest_measurement=None, stop_ack=False,
                   scope="RAM replay/DSP/USB/host receiver; no ADC, GUI or physical audio")
    write_json(args.output / "result.json", summary)

    def exchange(frame):
        requested = struct.unpack_from("<I", frame, 8)[0]
        opcode = struct.unpack_from("<H", frame, 6)[0]
        if device.write(0x06, frame, timeout=3000) != 512:
            raise RuntimeError("Short command write; FPGA state unknown")
        deadline = time.monotonic() + args.stall_timeout
        while time.monotonic() < deadline:
            if not pending:
                try:
                    pending.extend(decoder.feed(device.read(0x82, 512, timeout=100)))
                except TransferTimeout:
                    continue
            if pending:
                kind, words, _ = pending.popleft()
                if kind == "ack" and words[2] == requested:
                    if words[1] >> 16 or words[3] != opcode:
                        raise RuntimeError("FPGA rejected command: " + str(words))
                    return
        raise TimeoutError(f"ACK timeout opcode={opcode}, sequence={requested}; FPGA state unknown")

    def receive():
        try:
            while not stop_event.is_set():
                try:
                    data = device.read(0x82, 32768, timeout=100)
                except TransferTimeout:
                    receiver["timeouts"] += 1
                    continue
                if data:
                    receiver["bytes"] += len(data)
                    try:
                        ingress.put_nowait(data)
                    except queue.Full as error:
                        receiver["queue_overflows"] += 1
                        raise BufferError("Host ingress queue overflow; continuous stream failed") from error
                    receiver["queue_high_water"] = max(receiver["queue_high_water"], ingress.qsize())
        except Exception as error:
            reader_failure.append(error)

    started_at = None
    finished_at = None
    capture_errors = None
    last_arrival = None
    future = None
    history = deque(maxlen=720)
    worker = ThreadPoolExecutor(max_workers=1)

    def snapshot(status):
        elapsed = ((finished_at if finished_at is not None else time.monotonic()) - started_at
                   if started_at is not None else 0)
        summary.update(status=status, elapsed_seconds=elapsed, frames=monitor.frames,
                       samples=monitor.samples, signal_seconds=monitor.samples / IQ_RATE,
                       average_iq_rate_hz=monitor.samples / elapsed if elapsed else 0,
                       sample_index_wraps=monitor.sample_wraps,
                       crc_errors=capture_errors[0] if capture_errors else decoder.crc_errors,
                       discarded_bytes=capture_errors[1] if capture_errors else decoder.discarded,
                       receiver=dict(receiver), queue_depth=ingress.qsize())
        write_json(args.output / "result.json", summary)

    try:
        device = open_transport(args.vid, args.pid, "cyusb", dll=args.cyusb_dll)
        print(json.dumps(device.describe()), flush=True)
        exchange(command(STOP, 0))
        for frame in upload_commands(samples, 1):
            sequence = struct.unpack_from("<I", frame, 8)[0]
            if struct.unpack_from("<H", frame, 6)[0] == 3:
                started = True
            exchange(frame)
        if decoder.crc_errors or decoder.discarded:
            raise ValueError("CRC/discarded bytes during upload/START")
        print("Upload completed once. FPGA replay/DSP and USB reception remain continuous.", flush=True)
        started_at = time.monotonic()
        last_arrival = started_at
        while pending:
            kind, frame, _ = pending.popleft()
            if kind != "iq":
                raise ValueError("Unexpected ACK after START")
            monitor.observe(frame)
        next_analysis = started_at + 1
        next_report = started_at + args.report_interval
        reader = threading.Thread(target=receive, name="replay-usb-reader", daemon=True)
        reader.start()
        while True:
            now = time.monotonic()
            if reader_failure:
                raise reader_failure[0]
            if future is not None and future.done():
                summary["latest_measurement"] = future.result()
                summary["analysis_checks"] += 1
                future = None
            if args.seconds and now - started_at >= args.seconds:
                break
            try:
                records = decoder.feed(ingress.get(timeout=.05))
                last_arrival = time.monotonic()
            except queue.Empty:
                if now - last_arrival > args.stall_timeout:
                    raise TimeoutError("No IQ bytes received within stall timeout")
                records = []
            if decoder.crc_errors or decoder.discarded:
                raise ValueError("CRC error or discarded bytes during continuous capture")
            for kind, value, _ in records:
                if kind != "iq":
                    raise ValueError("Unexpected ACK during free-running test")
                monitor.observe(value)
            if now >= next_analysis and future is None:
                values = monitor.analysis_input()
                if values is not None:
                    future = worker.submit(measure, values, info)
                next_analysis = now + 1
            if now >= next_report:
                snapshot("RUNNING")
                history.append(dict(elapsed_seconds=summary["elapsed_seconds"], samples=monitor.samples,
                                    average_iq_rate_hz=summary["average_iq_rate_hz"], queue_depth=ingress.qsize()))
                write_json(args.output / "recent_progress.json", list(history))
                print(f"{summary['elapsed_seconds']:.1f}s frames={monitor.frames} IQ={monitor.samples} "
                      f"rate={summary['average_iq_rate_hz']:.0f}/s CRC={decoder.crc_errors} "
                      f"queue={ingress.qsize()} checks={summary['analysis_checks']}", flush=True)
                next_report = now + args.report_interval
        if future is not None:
            summary["latest_measurement"] = future.result()
            summary["analysis_checks"] += 1
            future = None
        if not monitor.frames or not summary["analysis_checks"]:
            raise ValueError("Insufficient continuous IQ or no completed parameter checks")
        elapsed = time.monotonic() - started_at
        if monitor.samples / elapsed < IQ_RATE * .98:
            raise ValueError("Delivered IQ rate below 98% of 500 kS/s; real-time check failed")
        summary["status"] = "PASS"
    except KeyboardInterrupt:
        summary["status"] = "STOPPED"
        summary["reason"] = "User interrupted; requested duration was not completed"
    except Exception as error:
        summary["status"] = "FAIL"
        summary["reason"] = str(error)
    finally:
        finished_at = time.monotonic()
        capture_errors = (decoder.crc_errors, decoder.discarded)
        # Stop the one USB reader before sending STOP; never issue concurrent IN reads.
        stop_event.set()
        if reader is not None:
            reader.join(timeout=2)
        if reader is not None and reader.is_alive():
            summary.update(status="FAIL", reason="USB reader did not stop; device state unknown")
        elif device is not None and started:
            try:
                exchange(command(STOP, sequence + 1))
                summary["stop_ack"] = True
            except Exception as error:
                summary.update(status="FAIL", cleanup_error=str(error))
        if reader_failure and summary["status"] == "PASS":
            summary.update(status="FAIL", reason=str(reader_failure[0]))
        if device is not None and (reader is None or not reader.is_alive()):
            device.close()
        worker.shutdown(wait=True, cancel_futures=True)
        # Bound storage to the last 512 frames; no full-stream recording.
        (args.output / "tail.fcr").write_bytes(b"".join(frame.raw for frame in monitor.tail))
        snapshot(summary["status"])
        print(json.dumps(summary, indent=2, ensure_ascii=False), flush=True)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kind", choices=("am", "fm"), default="am")
    parser.add_argument("--rf", type=float, default=98_000_000)
    parser.add_argument("--seconds", type=float, default=600, help="0 runs until Ctrl+C")
    parser.add_argument("--stall-timeout", type=float, default=5)
    parser.add_argument("--report-interval", type=float, default=5)
    parser.add_argument("--vid", type=lambda value: int(value, 0), default=0x04B4)
    parser.add_argument("--pid", type=lambda value: int(value, 0), default=0x1004)
    parser.add_argument("--cyusb-dll", type=Path)
    parser.add_argument("--output", type=Path, default=PROJECT / ".harness/receiver_replay/soak")
    args = parser.parse_args()
    if (not all(math.isfinite(v) for v in (args.seconds, args.stall_timeout, args.report_interval))
            or args.seconds < 0 or 0 < args.seconds < 5 or args.stall_timeout <= 0 or args.report_interval <= 0):
        parser.error("Use seconds=0 or >=5, and positive finite timeouts/intervals")
    result = run(args)
    raise SystemExit(0 if result["status"] == "PASS" else 130 if result["status"] == "STOPPED" else 1)


if __name__ == "__main__":
    main()
