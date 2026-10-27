"""Build the EP4CE6 replay revision and verify device, clocks and all STA slacks."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parents[2] / ".harness/receiver_replay"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    summary = dict(status="FAIL", device="EP4CE6F17C8", hardware="not tested")
    try:
        command = [str(args.quartus / "bin64/quartus_sh.exe"), "--flow", "compile", "receiver_replay"]
        with (OUTPUT / "build.log").open("w", encoding="utf-8") as log:
            subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=900)
        fit = (OUTPUT / "quartus/receiver_replay.fit.summary").read_text()
        if "Device : EP4CE6F17C8" not in fit or "Fitter Status : Successful" not in fit:
            raise ValueError("Wrong device or failed fitting")
        sta = (OUTPUT / "quartus/receiver_replay.sta.summary").read_text()
        slacks = [float(value) for value in re.findall(r"Slack\s*:\s*([\d.-]+)", sta)]
        if len(slacks) < 30 or min(slacks) < 0:
            raise ValueError("Missing/negative timing checks")
        report = (OUTPUT / "quartus/receiver_replay.sta.rpt").read_text()
        for index, rate in ((0, 43.5), (1, 24.0)):
            matches = re.findall(rf";\s*pll\|pll1\|clk\[{index}\]\s*;\s*Generated\s*;\s*[\d.]+\s*;\s*([\d.]+)\s+MHz", report)
            if len(matches) != 1 or abs(float(matches[0]) - rate) > .01:
                raise ValueError("PLL rate mismatch: " + str(matches))
        sof = OUTPUT / "quartus/receiver_replay.sof"
        if not sof.is_file():
            raise ValueError("Missing SOF")
        summary.update(status="PASS", minimum_slack_ns=min(slacks), timing_checks=len(slacks),
                       sof=str(sof), sha256=hashlib.sha256(sof.read_bytes()).hexdigest(),
                       board_timing="unmeasured PCB skew; LED intentionally unconstrained")
    finally:
        (OUTPUT / "build.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
