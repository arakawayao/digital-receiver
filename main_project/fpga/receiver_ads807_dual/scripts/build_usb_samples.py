"""Build the separate USB sample replay revision; never opens USB or programs FPGA."""
import argparse
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807_dual/usb_samples/build"
NAME = "receiver_usb_samples"


def main():
    global NAME, OUT
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("manual", "auto"), default="manual")
    args = parser.parse_args()
    if args.mode == "auto":
        NAME += "_auto"
        OUT = OUT.parent / "build_auto"
    OUT.mkdir(parents=True, exist_ok=True)
    summary = dict(status="FAIL", revision=NAME, fifo_samples=256, replay_samples=8192, steps={})
    try:
        for stage, arguments in (("map", [NAME]), ("fit", [NAME]),
                                 ("sta", ["-t", "scripts/timing.tcl", NAME]), ("asm", [NAME])):
            executable = f"D:/intelFPGA/18.1/quartus/bin64/quartus_{stage}.exe"
            with (OUT / (stage+".log")).open("w", encoding="utf-8") as stream:
                result = subprocess.run([executable, *arguments], cwd=ROOT, stdout=stream,
                                        stderr=subprocess.STDOUT, timeout=900)
            summary["steps"][stage] = result.returncode
            print(f"{stage}: {result.returncode}", flush=True)
            if result.returncode:
                raise RuntimeError(f"{stage} failed: {OUT}")
            if stage == "sta":
                slacks = {}
                for path in ROOT.glob(NAME+"_corner*_*.rpt"):
                    found = re.search(r"Worst case slack is ([\d.-]+)", path.read_text(errors="replace"))
                    if found:
                        slacks[path.stem] = float(found[1])
                summary["slacks_ns"] = slacks
                if len(slacks) != 12 or min(slacks.values()) < 0:
                    raise RuntimeError("Replay revision constrained timing failed")
        summary["status"] = "PASS"
    except Exception as error:
        summary["reason"] = str(error)
        raise
    finally:
        (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
