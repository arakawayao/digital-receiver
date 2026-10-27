"""Real Intel IP, USB pin model, command rejection and ADC-to-IQ replay checks."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
sys.path.insert(0, str(PROJECT))
from main_project.fpga.receiver_ads807.host.replay import waveform, Decoder, save_capture
from main_project.fpga.receiver_v2.host.usb_replay import command, upload_commands, BEGIN, START, STOP


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("am", "fm"))
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    output = PROJECT / ".harness/receiver_replay" / args.kind
    output.mkdir(parents=True, exist_ok=True)
    (output / "rtl").mkdir(exist_ok=True)
    for source in (ROOT / "rtl").glob("*.hex"):
        shutil.copyfile(source, output / "rtl" / source.name)
    samples, info = waveform(args.kind)
    bad_crc = bytearray(command(BEGIN, 1, 8192))
    bad_crc[-1] ^= 1
    packets = [command(STOP, 0), bytes(bad_crc), command(START, 2)]
    packets.extend(upload_commands(samples, 3))
    packets.append(command(STOP, len(packets)))
    (output / "commands.hex").write_text("\n".join(f"{value:02x}" for packet in packets for value in packet), encoding="ascii")
    (output / "pattern.hex").write_text("\n".join(f"{value:03x}" for value in samples), encoding="ascii")

    def run(tool, arguments, name, timeout=600):
        result = subprocess.run([str(args.modelsim / (tool + ".exe")), *map(str, arguments)],
            cwd=output, capture_output=True, text=True, errors="replace", timeout=timeout)
        text = result.stdout + result.stderr
        (output / (name + ".log")).write_text(text, encoding="utf-8")
        if result.returncode or "** Error" in text or "** Fatal" in text:
            raise RuntimeError(text[-6000:])
        print(name + ": passed", flush=True)
        return text

    run("vlib", ["work"], "library")
    libraries = [args.quartus / "eda/sim_lib" / name for name in
                 ("altera_primitives.v", "220model.v", "altera_mf.v", "cycloneive_atoms.v")]
    sources = [ROOT / "rtl" / (name + ".v") for name in
               ("receiver_replay_top", "rx_capture", "rx_frequency", "rx_nco", "rx_cic", "rx_fir", "rx_dsp", "rx_reset", "rx_packet")]
    sources += [ROOT.parent / "receiver_v2/rtl" / (name + ".v") for name in ("rx_usb_replay", "rx_fx2_duplex")]
    run("vlog", [*libraries, *sorted((ROOT / "ip").glob("*.v")), *sources,
                 ROOT / "tests/tb_usb_replay.v"], "compile")
    text = run("vsim", ["-c", "work.tb_usb_replay", f"+commands={len(packets)}", f"+length={len(samples)}",
        "-do", "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], "simulation")
    if "USB_REPLAY_PASS" not in text:
        raise RuntimeError("Missing testbench completion marker")
    data = bytes(int(value, 16) for value in (output / "usb_bytes.txt").read_text().split())
    decoder = Decoder()
    records = []
    for offset in range(0, len(data), 32768):
        records.extend(decoder.feed(data[offset:offset + 32768]))
    acks = [value for kind, value, _ in records if kind == "ack"]
    if len(acks) != len(packets) or [ack[2] for ack in acks] != list(range(len(packets))):
        raise ValueError("Command ACK sequence mismatch")
    if [ack[1] >> 16 for ack in acks] != [0, 1, 5] + [0] * (len(packets) - 3):
        raise ValueError("CRC/incomplete upload rejection mismatch")
    iq_frames = [raw for kind, _, raw in records if kind == "iq"]
    # STOP can truncate and pad the final in-flight frame, so validate the first
    # 16 complete frames acquired before STOP; earlier CRC errors are forbidden.
    first_stop = data.rfind(b"RPA1")
    first_iq = data.find(b"FCR1")
    iq_data = b"".join(iq_frames[:16])
    if first_iq < 0 or first_stop < first_iq:
        raise ValueError("No ADC-to-USB result")
    if Decoder().feed(data[:first_iq])[-1][0] != "ack":
        raise ValueError("Unexpected stream before START")
    result = save_capture(output, iq_data, info)
    dut_iq = [tuple(map(int, line.split())) for line in (output / "iq_samples.txt").read_text().splitlines()]
    delivered = []
    for kind, frame, _ in Decoder().feed(iq_data):
        delivered.extend((frame.index + k, int(i), int(q)) for k, (i, q) in enumerate(frame.samples))
    if delivered != dut_iq[:len(delivered)]:
        raise ValueError("USB payload differs from actual DUT IQ")
    result.update(acknowledgements=len(acks), rejected_bad_crc=True,
                  rejected_incomplete_start=True, payload_matches_dut=True,
                  hardware="not connected; simulation only")
    (output / "simulation.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
