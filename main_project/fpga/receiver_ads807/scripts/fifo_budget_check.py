"""Measure isolated Intel FIFO stall capacity; never access USB or program FPGA."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess


PROJECT = Path(__file__).resolve().parents[4]
OUTPUT = PROJECT / ".harness/tri_board_test/fifo_budget"
BASELINE = PROJECT / ".harness/tri_board_test/auto/project"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    result_path = OUTPUT / "result.json"
    result_path.write_text(json.dumps({"status": "RUNNING"}), encoding="utf-8")
    source = BASELINE / "rtl/rx_fifo_tri.v"
    original = source.read_text(encoding="ascii")
    if original.count(".lpm_numwords(256)") != 1 or original.count(".lpm_widthu(8)") != 1:
        raise ValueError("Expected actual 256-point replay FIFO baseline")
    fit_path = BASELINE / "output/receiver_ads807_tri.fit.rpt"
    fit = fit_path.read_text()
    used, available = map(int, re.search(r"; M9Ks\s*;\s*(\d+) / (\d+)", fit).groups())
    libraries = args.quartus / "eda/sim_lib"
    cases = []
    for depth in (256, 512):
        root = OUTPUT / str(depth)
        root.mkdir(exist_ok=True)
        variant = original.replace(".lpm_numwords(256)", f".lpm_numwords({depth})")
        variant = variant.replace(".lpm_widthu(8)", f".lpm_widthu({depth.bit_length()-1})")
        (root / "rx_fifo_tri.v").write_text(variant, encoding="ascii")

        def run(tool, arguments, label):
            process = subprocess.run([str(args.modelsim / (tool + ".exe")), *map(str, arguments)],
                                     cwd=root, capture_output=True, text=True, errors="replace", timeout=180)
            output = process.stdout + process.stderr
            (root / (label + ".log")).write_text(output, encoding="utf-8")
            if process.returncode or "** Error" in output or "** Fatal" in output:
                raise RuntimeError(output[-4000:])
            return output

        run("vlib", ["work"], "library")
        run("vlog", [libraries / "220model.v", libraries / "altera_mf.v", root / "rx_fifo_tri.v",
                     PROJECT / "main_project/fpga/receiver_ads807/tests/tb_fifo_budget.v"], "compile")
        output = run("vsim", ["-c", "work.tb_fifo_budget", f"-gDEPTH={depth}", "-do",
                              "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], "simulation")
        if "FIFO_BUDGET_PASS" not in output:
            raise ValueError("Simulation completion marker missing")
        rows = re.findall(r"FIFO_BUDGET (depth=\d+ pause_us=\d+ produced_during_pause=\d+ dropped_during_pause=\d+ total_dropped=\d+ delivered=\d+ gaps=\d+)", output)
        if len(rows) != 6:
            raise ValueError("Expected six pause lengths per depth")
        cases.extend({key: int(value) for key, value in re.findall(r"(\w+)=(\d+)", row)} for row in rows)
        print(f"depth={depth}: six pause/recovery checks passed", flush=True)
    result = dict(status="PASS", scope="isolated FIFO simulation; injected loss is expected; no hardware",
                  iq_rate_hz=500000, width_bits=288, baseline_source=str(source),
                  baseline_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                  fit_report=str(fit_path), fit_report_sha256=hashlib.sha256(fit_path.read_bytes()).hexdigest(),
                  fitted_m9k=used, device_m9k=available, fifo_m9k_256=8,
                  estimated_total_m9k_512=used-8+16,
                  note="512-point M9K estimate, not a synthesized/fitted 512-point design", cases=cases)
    result_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2), flush=True)


if __name__ == "__main__":
    main()
