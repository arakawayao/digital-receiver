"""Run actual FPGA estimator/controller tests; no USB access or programming."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


HOST = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rtl-root", type=Path, required=True)
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    parser.add_argument("--output", type=Path, default=HOST/".harness/am_restart_validation")
    args = parser.parse_args()
    root = args.rtl_root.resolve()
    output = args.output.resolve()
    sources = [root/"rtl/rx_frequency.v", root/"rtl/rx_control.v",
               root/"rtl/receiver_top.v", root/"tests/tb_frequency.v",
               Path(__file__).with_name("tb_am_restart.v")]
    output.mkdir(parents=True, exist_ok=True)
    summary = {"status": "FAIL", "hardware_test": False, "checks": {},
               "scope": "50% AM 500 Hz, 98/103.7/99.5 MHz, 80/400/800 ADC codes; no IQ DSP/USB/audio",
               "sources": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}}

    def run(tool, arguments, label):
        result = subprocess.run([str(args.modelsim/(tool+".exe")), *map(str, arguments)],
                                cwd=output, capture_output=True, text=True, errors="replace", timeout=120)
        log = result.stdout+result.stderr
        (output/(label+".log")).write_text(log, encoding="utf-8")
        if result.returncode or "** Error" in log or "** Fatal" in log:
            raise RuntimeError(f"{label} failed; see {output/(label+'.log')}")
        return log

    try:
        # The model test must retain the same STOP reset wiring as the top level.
        top = sources[2].read_text(encoding="utf-8")
        if not re.search(r"\.rst_n\(sample_rst_n\s*&&\s*replay_loaded\s*&&\s*running\)", top):
            raise RuntimeError("Production detector does not reset while stopped")
        run("vlib", ["work"], "library")
        run("vlog", ["-sv", *sources[:2], *sources[3:]], "compile")
        for top_name, marker in (("tb_frequency", "FREQUENCY_PASS"), ("tb_am_restart", "AM_RESTART_PASS checks=13")):
            log = run("vsim", ["-c", "-wlf", top_name+".wlf", "work."+top_name,
                                "-do", "onbreak {quit -code 1}; run -all; quit -code 0"], top_name)
            if marker not in log:
                raise RuntimeError(f"Missing success marker for {top_name}")
            summary["checks"][top_name] = "PASS"
        summary["status"] = "PASS"
        print("AM restart RTL: PASS (9 retunes, 4 rejection cases; original frequency regression passed)")
    finally:
        (output/"summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
