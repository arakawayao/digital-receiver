"""Run map/fit/multicorner STA. ADC/PCB I/O timing remains outside board sign-off."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807_dual/build"
NAME = "receiver_ads807_dual"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    summary = {"adc_rate_hz": 43500000, "adc_pins": "all_12_data_otr_and_clock_assigned", "steps": {}}
    commands = [("map", ["quartus_map.exe", NAME]),
                ("fit", ["quartus_fit.exe", NAME]),
                ("sta", ["quartus_sta.exe", "-t", "scripts/timing.tcl", NAME])]
    try:
        for stage, command in commands:
            command[0] = str(args.quartus / "bin64" / command[0])
            with (OUT / f"{stage}.log").open("w", encoding="utf-8") as log:
                result = subprocess.run(command, cwd=ROOT, stdout=log,
                    stderr=subprocess.STDOUT, timeout=900)
            summary["steps"][stage] = result.returncode
            print(f"{stage}: {result.returncode}", flush=True)
            if result.returncode:
                raise RuntimeError(f"{stage} failed; see {OUT}")
        clocks = (ROOT / f"{NAME}_clocks.rpt").read_text(errors="replace")
        for index, expected in ((0, 43.5), (1, 24.0)):
            matches = re.findall(rf";\s*[^;]*\|clk\[{index}\]\s*;\s*Generated\s*;\s*[\d.]+\s*;\s*([\d.]+)\s+MHz", clocks)
            assert len(matches) == 1 and abs(float(matches[0])-expected) < .01, matches
        slacks = {}
        for report in ROOT.glob(f"{NAME}_corner*_*.rpt"):
            match = re.search(r"Worst case slack is ([\d.-]+)", report.read_text(errors="replace"))
            if match:
                slacks[report.stem] = float(match[1])
        summary["constrained_corner_slacks_ns"] = slacks
        summary["constrained_timing_pass"] = len(slacks) == 12 and min(slacks.values()) >= 0
        summary["board_timing"] = "not signed off: no ADC/PCB I/O timing constraints"
        assert summary["constrained_timing_pass"], slacks
    finally:
        (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
