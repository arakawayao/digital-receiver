"""Simulate each EP4CE6 fixed-authority ROM configuration before board use."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from main_project.fpga.receiver_ads807.host.replay import waveform
from main_project.fpga.receiver_ads807.host.soak import measure
from main_project.fpga.receiver_ads807_tri.host.protocol import command, Decoder, Snapshot

OUTPUT = PROJECT / ".harness/tri_board_test"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("auto", "fpga", "manual"))
    args = parser.parse_args()
    build = OUTPUT / args.mode / "project"
    root = OUTPUT / args.mode / "simulation"
    root.mkdir(parents=True, exist_ok=True)
    (OUTPUT / args.mode / "simulation.json").write_text(json.dumps({"status": "RUNNING"}), encoding="utf-8")
    for folder in ("rtl", "ip"):
        shutil.copytree(build / folder, root / folder, dirs_exist_ok=True)
    # Last assembled case is FM / 80 codes. Retain exactly its source ROM.
    samples, info = waveform("fm", length=4096, amplitude=80)
    mode = {"auto": 0, "fpga": 1, "manual": 2}[args.mode]
    operations = [(1, 0, 0), (2, mode, 0), (8, 500, 0),
                  (1 if mode == 1 else 3, 0, round(info["actual_rf_hz"]) if mode != 1 else 0),
                  (4, 0, 0), (7, 0, 0)]
    packets = b"".join(command(n+1, *values) for n, values in enumerate(operations))
    (root / "commands.hex").write_text("\n".join(f"{v:02x}" for v in packets), encoding="ascii")
    tools = Path("D:/modeltech64_2020.4/win64")

    def run(tool, arguments, label):
        process = subprocess.run([str(tools / (tool + ".exe")), *map(str, arguments)],
                                 cwd=root, capture_output=True, text=True, errors="replace", timeout=900)
        output = process.stdout + process.stderr
        (root / (label + ".log")).write_text(output, encoding="utf-8")
        if process.returncode or "** Error" in output or "** Fatal" in output:
            raise RuntimeError(output[-5000:])
        return output

    run("vlib", ["work"], "library")
    libraries = Path("D:/intelFPGA/18.1/quartus/eda/sim_lib")
    run("vlog", ["-sv", *[libraries / f for f in ("altera_primitives.v", "220model.v", "altera_mf.v", "cycloneive_atoms.v")],
                 *sorted((root / "ip").glob("*.v")), *sorted((root / "rtl").glob("*.v")),
                 PROJECT / "main_project/fpga/receiver_ads807/tests/tb_board_replay.v"], "compile")
    output = run("vsim", ["-c", "work.tb_board_replay", "-do", "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], "simulation")
    if "BOARD_REPLAY_PASS" not in output:
        raise ValueError("No simulation completion marker")
    actual = [int(v) for v in (root / "samples.txt").read_text().split()]
    # Address, ROM output, and capture registers create a fixed pipeline offset.
    offset = next((n for n in range(8) if actual[n:n+8192] == (samples * 3)[:8192]), None)
    if offset is None:
        raise ValueError("ROM playback does not match the reference ADC samples")
    decoder = Decoder()
    data = bytes(int(v, 16) for v in (root / "bytes.txt").read_text().split())
    frames = decoder.feed(data)
    # Simulation ends only after STOP; no packet truncation is permitted.
    if decoder.buffer or decoder.discarded:
        raise ValueError("Incomplete/corrupt TRI1 stream")
    acks = [frame.ack() for frame in frames if frame.kind == 3]
    if [ack["sequence"] for ack in acks] != list(range(1, 7)) or any(ack["error"] for ack in acks):
        raise ValueError("Command/ACK mismatch: " + str(acks))
    records = {}
    for line in (root / "iq.txt").read_text().splitlines():
        epoch, index, i, q = map(int, line.split())
        records[epoch, index] = (i, q)
    iq_frames = [f for f in frames if f.kind == 1]
    for frame in iq_frames:
        h = frame.words
        if h[12] or h[11] & 3 != mode:
            raise ValueError("FIFO overflow or wrong mode")
        for n, values in enumerate(frame.iq()):
            if records[h[4], h[5]+n] != values:
                raise ValueError("USB payload differs from DSP output")
    snapshot = Snapshot(5)
    for frame in frames:
        if frame.kind == 2:
            snapshot.add(frame)
    raw_offset = next((n for n in range(4096) if snapshot.values == (samples*2)[n:n+4096]), None)
    if raw_offset is None:
        raise ValueError("RAW snapshot differs from reference ROM")
    usable = [f for f in iq_frames if not f.words[11] & 0x1000]
    full_frames = sum(frame.words[6] == 111 for frame in usable)
    if not usable or full_frames / len(usable) < .8:
        raise ValueError(f"Continuous IQ packets are underfilled: {full_frames}/{len(usable)} full frames")
    iq = np.array([v for frame in usable for v in frame.iq()])
    lo = 87_000_000 + usable[-1].words[10]*43_500_000/2**32
    measurement = measure(((iq[:, 0] + 1j*iq[:, 1])/32768, lo), info)
    summary = dict(status="PASS", mode=args.mode, frames=len(frames), iq_samples=len(iq),
                   full_iq_frames=full_frames, usable_iq_frames=len(usable),
                   source_sha256={str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                                  for folder in ("rtl", "ip") for path in sorted((root / folder).rglob("*"))
                                  if path.is_file() and path.suffix in (".v", ".hex", ".mif")},
                   rom_pipeline_offset=offset, raw_offset=raw_offset, commands=len(acks), measurement=measurement)
    (OUTPUT / args.mode / "simulation.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
    main()
