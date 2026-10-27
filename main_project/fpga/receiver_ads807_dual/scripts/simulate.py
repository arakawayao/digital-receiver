"""Real Intel PLL/FIFO, two-mode FX2 pin transactions and independent payload checks."""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import zlib

from cic_ip import compile_ip

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
OUT = PROJECT / ".harness/receiver_ads807_dual/simulation"
sys.path.insert(0, str(PROJECT))
from main_project.fpga.receiver_ads807_dual.host.protocol import command, Decoder


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"rtl").mkdir(exist_ok=True)
    for file in (ROOT/"rtl").glob("*.hex"):
        shutil.copyfile(file, OUT/"rtl"/file.name)
    requests = [(1, 0, 0), (2, 2, 0), (3, 0, 98_000_000), (5, 1, 98_000_000),
                (8, 1, 0), (5, 0, 0), (3, 0, 88_000_000), (3, 0, 108_000_000),
                (3, 0, 108_000_001), (2, 0, 0), (4, 0, 0), (6, 0, 98_000_000),
                (7, 0, 0), (2, 1, 0), (1, 0, 0), (3, 0, 88_000_000),
                (3, 0, 88_000_000), (3, 0, 88_000_000),
                (3, 0, 98_000_000), (2, 2, 0), (3, 0, 98_000_000),
                (3, 0, 98_000_000), (3, 0, 98_000_000), (3, 0, 98_000_000)]
    packets = [bytearray(command(n, *req)) for n, req in enumerate(requests)]
    packets[15][508] ^= 1
    packets[16][40] = 1
    struct.pack_into("<I", packets[16], 508, zlib.crc32(packets[16][:508]))
    # Valid CRC with the old command version, then invalid NCO steps in version 2.
    struct.pack_into("<I", packets[18], 4, 1)
    struct.pack_into("<I", packets[18], 16, 0)
    for index, step in ((20, 0), (21, 2_073_432_489), (22, 98_734_879)):
        struct.pack_into("<I", packets[index], 16, step)
    for index in (18, 20, 21, 22):
        struct.pack_into("<I", packets[index], 508, zlib.crc32(packets[index][:508]))
    data = b"".join(packets)
    (OUT/"commands.hex").write_text("\n".join(f"{b:02x}" for b in data), encoding="ascii")

    def run(tool, arguments, label, timeout=600):
        result = subprocess.run([str(args.modelsim/(tool+".exe")), *map(str, arguments)],
                                cwd=OUT, capture_output=True, text=True, errors="replace", timeout=timeout)
        log = result.stdout+result.stderr
        (OUT/(label+".log")).write_text(log, encoding="utf-8")
        if result.returncode or "** Error" in log or "** Fatal" in log:
            raise RuntimeError(log[-5000:])
        print(label+": passed", flush=True)
        return log

    run("vlib", ["work"], "library")
    cic_libraries = compile_ip(args.modelsim, args.quartus, OUT)
    libraries = [args.quartus/"eda/sim_lib"/name for name in
                 ("altera_primitives.v", "220model.v", "altera_mf.v", "cycloneive_atoms.v")]
    run("vlog", ["-sv", *libraries, ROOT/"ip/rx_pll_ads807.v", ROOT/"ip/rx_ifclk.v",
                 *sorted((ROOT/"rtl").glob("*.v")), *sorted((ROOT/"tests").glob("*.v"))], "compile")
    for top in ("tb_capture", "tb_pll", "tb_frequency", "tb_mailbox", "tb_control", "tb_packet", "tb_dual"):
        log = run("vsim", ["-c", *cic_libraries, "-wlf", top+".wlf", "work."+top, "-do",
                           "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], top)
        assert top[3:].upper()+"_PASS" in log
    packet_raw = bytes(int(x, 16) for x in (OUT/"packet_bytes.txt").read_text().split())
    packet_decoder = Decoder()
    packet_records = packet_decoder.feed(packet_raw)
    assert not (packet_decoder.crc_errors or packet_decoder.discarded or packet_decoder.buffer)
    packet_writes = [int(x, 16) for x in (OUT/"packet_iq.txt").read_text().split()]
    cursor = 0
    packet_acks = []
    for number, record in enumerate(packet_records):
        h = record.words
        assert h[3] == number
        used = h[6]*4 if record.kind == 1 else 48
        assert not any(record.raw[64+used:508])
        if record.kind == 3:
            packet_acks.append(record.ack()["sequence"])
            assert struct.unpack_from("<12I", record.raw, 64) == (
                packet_acks[-1], 1, 0, 2, 98_000_000, 1_086_083_684, 3, 4, 77,
                0x302, 98_000_000, 500)
            assert (h[4], h[5], h[9], h[10], h[11], h[12], h[13], h[14]) == (
                3, 77, 98_000_000, 1_086_083_684, 0x302, packet_acks[-1], 4, 98_000_000)
            continue
        accumulated_clip = 0
        for offset in range(h[6]):
            value = packet_writes[cursor]
            fields = [(value >> shift) & 0xffffffff for shift in range(0, 288, 32)]
            assert fields[1] == (h[5]+offset) & 0xffffffff
            assert struct.unpack_from("<I", record.raw, 64+offset*4)[0] == fields[0]
            assert (h[4], h[9], h[10], h[13], h[14]) == (fields[3], fields[4], fields[5], fields[7], fields[8])
            assert (h[11] ^ fields[6]) & ~0x800 == 0
            accumulated_clip |= fields[6] & 0x800
            cursor += 1
        assert h[11] & 0x800 == accumulated_clip
    assert packet_acks == [42, 43] and cursor == len(packet_writes) == 336
    raw = bytes(int(x, 16) for x in (OUT/"dual_bytes.txt").read_text().split())
    complete = len(raw)//512*512
    decoder = Decoder()
    records = decoder.feed(raw[:complete])
    assert not decoder.crc_errors and not decoder.discarded and not decoder.buffer
    assert all(r.words[3] == n for n, r in enumerate(records))
    acks = [r.ack() for r in records if r.kind == 3]
    assert len(acks) == len(requests), len(acks)
    assert [a["sequence"] for a in acks] == list(range(len(requests)))
    assert [a["error"] for a in acks] == [0]*8+[4, 4, 3, 3, 0, 0, 0, 1, 2, 5, 2, 0, 4, 4, 4, 0]
    assert acks[2]["phase_step"] == round(11_000_000/43_500_000*2**32)
    assert acks[6]["phase_step"] == round(1_000_000/43_500_000*2**32)
    assert acks[7]["phase_step"] == round(21_000_000/43_500_000*2**32)
    assert acks[23]["phase_step"] == 1_086_083_684 and acks[23]["tuned_rf"] == 98_000_000
    writes = [int(x, 16) for x in (OUT/"dual_iq.txt").read_text().split()]
    expected = {(v >> 96 & 0xffffffff, v >> 224 & 0xffffffff, v >> 32 & 0xffffffff): v for v in writes}
    samples = 0
    modes = set()
    loss_seen = False
    for record in records:
        h = record.words
        assert record.kind in (1, 3)
        used = h[6]*4 if record.kind == 1 else 48
        assert not any(record.raw[64+used:508])
        assert zlib.crc32(record.raw[:508]) == struct.unpack_from("<I", record.raw, 508)[0]
        if record.kind != 1:
            continue
        modes.add(h[11] & 3)
        loss_seen |= h[12] > 0
        for offset in range(h[6]):
            value = expected[(h[4], h[13], h[5]+offset)]
            fields = [(value >> shift) & 0xffffffff for shift in range(0, 288, 32)]
            assert struct.unpack_from("<I", record.raw, 64+offset*4)[0] == fields[0]
            assert (h[4], h[9], h[10], h[13], h[14]) == (fields[3], fields[4], fields[5], fields[7], fields[8])
            assert (h[11] ^ fields[6]) & ~0x800 == 0
            samples += 1
    assert modes == {1, 2} and loss_seen and samples > 1000
    result = dict(status="PASS", frames=len(records), iq_samples=samples, acknowledgements=len(acks),
                  modes=sorted(modes), raw_frames=0, crc_and_fifo_payload="PASS",
                  manual_without_lock="PASS", automatic_and_manual_holdover="PASS",
                  fifo_overflow_observable="PASS", trailing_inflight_bytes=len(raw)-complete)
    (OUT/"summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
