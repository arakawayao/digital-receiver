"""Simulate ordered RAM replay and compile both parameterized receiver configurations."""
from pathlib import Path
import subprocess

from cic_ip import compile_ip

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807_dual/usb_samples/simulation"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cic_libraries = compile_ip(Path("D:/modeltech64_2020.4/win64"), Path("D:/intelFPGA/18.1/quartus"), OUT)
    libraries = Path("D:/intelFPGA/18.1/quartus/eda/sim_lib")
    commands = [("vlib", ["work"]),
                ("vlog", [*[str(libraries/name) for name in
                            ("altera_primitives.v", "220model.v", "altera_mf.v", "cycloneive_atoms.v")],
                          *map(str, sorted((ROOT/"rtl").glob("*.v"))),
                          str(ROOT/"ip/rx_pll_ads807.v"), str(ROOT/"ip/rx_ifclk.v"),
                          str(ROOT/"tests/tb_sample_replay.v"), str(ROOT/"tests/tb_sample_control.v")]),
                ("vsim", ["-c", *cic_libraries, "work.tb_sample_replay", "-do",
                          "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"]),
                ("vsim", ["-c", *cic_libraries, "work.tb_sample_control", "-gUSB_MODE=2", "-do",
                          "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"]),
                ("vsim", ["-c", *cic_libraries, "work.tb_sample_control", "-gUSB_MODE=1", "-do",
                          "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"])]
    for index, (tool, args) in enumerate(commands):
        result = subprocess.run(["D:/modeltech64_2020.4/win64/"+tool+".exe", *args], cwd=OUT,
                                capture_output=True, text=True, errors="replace", timeout=180)
        text = result.stdout+result.stderr
        (OUT/(str(index)+"_"+tool+".log")).write_text(text, encoding="utf-8")
        if result.returncode or "** Error" in text or "** Fatal" in text:
            raise RuntimeError(text[-4000:])
        if tool == "vsim" and not any(token in text for token in ("SAMPLE_REPLAY_PASS", "SAMPLE_CONTROL_PASS")):
            raise RuntimeError("Replay test did not finish")
        print(tool+": PASS", flush=True)


if __name__ == "__main__":
    main()
