"""Publish a board plan only after its actual build and simulation checks pass."""
import hashlib
import json
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / ".harness/tri_board_test"


def main():
    cases = []
    for mode in ("auto", "fpga", "manual"):
        values = json.loads((OUTPUT / mode / "cases.json").read_text())
        if len(values) != 4:
            raise ValueError("Incomplete mode cases: " + mode)
        if mode != "fpga":
            simulation = json.loads((OUTPUT / mode / "simulation.json").read_text())
            if simulation["status"] != "PASS":
                raise ValueError("Simulation not passed: " + mode)
            if simulation.get("full_iq_frames", 0) < .8 * simulation.get("usable_iq_frames", 1):
                raise ValueError("Continuous IQ packet fill check not passed: " + mode)
            fingerprints = simulation.get("source_sha256", {})
            if not fingerprints:
                raise ValueError("Simulation source evidence missing: " + mode)
            for relative, digest in fingerprints.items():
                if hashlib.sha256((OUTPUT / mode / "project" / relative).read_bytes()).hexdigest() != digest:
                    raise ValueError("Simulation/build source mismatch: " + mode + "/" + relative)
            if len({case["sha256"] for case in values}) != 4:
                raise ValueError("ROM cases must have distinct SOFs")
        for case in values:
            if hashlib.sha256(Path(case["sof"]).read_bytes()).hexdigest() != case["sha256"]:
                raise ValueError("SOF does not match its evidence: " + case["name"])
            if case["minimum_slack_ns"] < 0:
                raise ValueError("Negative STA slack")
            cases.append(case)
    temporary = OUTPUT / "ready.tmp"
    temporary.write_text(json.dumps({"status": "PASS", "cases": cases}, indent=2), encoding="utf-8")
    temporary.replace(OUTPUT / "ready.json")
    print("Offline checks passed; board plan published (12 cases)", flush=True)


if __name__ == "__main__":
    main()
