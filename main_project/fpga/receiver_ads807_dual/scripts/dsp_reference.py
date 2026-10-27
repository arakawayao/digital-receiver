"""Check capture/NCO, pruned CIC arithmetic and FIR against independent models."""
import argparse
from collections import deque
import importlib.util
import json
from pathlib import Path
import shutil

from cic_ip import compile_ip, run
from cic_model import PrunedCIC

ROOT = Path(__file__).resolve().parents[1]
source = ROOT.parent/"receiver_ads807/scripts/simulate.py"
spec = importlib.util.spec_from_file_location("ads807_reference", source)
reference = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reference)
reference.ROOT = ROOT
OUT = ROOT.parents[2]/".harness/receiver_ads807_dual/reference"


class ScheduledCIC:
    """Observe Avalon output timing; independently predict every sample value.

    The IP has variable latency with valid gaps. Its timestamp is observed,
    while sample order, value, backlog and continuous latency are asserted.
    """
    instances = []
    trace = []

    def __init__(self, r):
        assert r == 87
        self.channel = len(self.instances)
        self.instances.append(self)
        self.cycle = 0
        self.samples = 0
        self.model = PrunedCIC()
        self.pending = deque()
        self.output = (0, 0, 0)

    def tick(self, rst, valid, value):
        observed_valid, observed_data = self.trace[self.cycle][self.channel*2:self.channel*2+2]
        if not rst:
            assert len(self.pending) <= 1
            self.pending.clear()
            self.model = PrunedCIC()
            self.output = (0, 0, 0)
            assert not observed_valid
        else:
            if valid:
                result = self.model.push(value)
                if result is not None:
                    self.pending.append((self.cycle, result >> 3))
            if observed_valid:
                assert self.pending, (self.cycle, "unexpected CIC output")
                accepted, expected = self.pending.popleft()
                assert 20 <= self.cycle-accepted < 1000
                assert observed_data == expected, (self.cycle, self.channel, observed_data, expected)
                self.output = (1, expected, 0)
                self.samples += 1
            else:
                self.output = (0, self.output[1], 0)
            assert len(self.pending) <= 1
        self.cycle += 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT/"rtl").mkdir(exist_ok=True)
    for file in (ROOT/"rtl").glob("*.hex"):
        shutil.copyfile(file, OUT/"rtl"/file.name)
    run(args.modelsim/"vlib.exe", ["work"], OUT, "library")
    cic_libraries = compile_ip(args.modelsim, args.quartus, OUT)
    libraries = [args.quartus/"eda/sim_lib"/name for name in
                 ("altera_primitives.v", "220model.v", "altera_mf.v", "cycloneive_atoms.v")]
    sources = [ROOT/"rtl"/name for name in ("rx_capture.v", "rx_nco.v", "rx_cic.v", "rx_fir.v", "rx_dsp.v")]
    run(args.modelsim/"vlog.exe", ["-sv", *libraries, *sources, ROOT/"tests/tb_dsp.v"], OUT, "compile")
    rows, segments = reference.vectors(43500000)
    (OUT/"dsp_inputs.txt").write_text("".join(f"{r} {e} {raw} {step:08x} {c}\n"
        for r, e, raw, step, c in rows), encoding="ascii")
    log = run(args.modelsim/"vsim.exe", ["-c", *cic_libraries, "work.tb_dsp", "-do",
        "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], OUT, "dsp43500000")
    assert "DSP_PASS" in log
    ScheduledCIC.trace = [list(map(int, row.split())) for row in (OUT/"cic_outputs.txt").read_text().splitlines()]
    assert len(ScheduledCIC.trace) == len(rows)
    assert all(row[0] == row[2] for row in ScheduledCIC.trace), "I/Q valid misalignment"
    reference.CIC = ScheduledCIC
    summary = reference.validate_dsp(OUT/"dsp_outputs.txt", rows, 43500000, segments)
    summary["cic_samples_per_channel"] = [instance.samples for instance in ScheduledCIC.instances]
    summary["cic_bit_exact_model"] = "PASS"
    summary["avalon_timing"] = "Observed with independent sample/order/backlog checks; continuous latency tested separately"
    (OUT/"modules_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print("DSP_REFERENCE_PASS", json.dumps(summary["cic_samples_per_channel"]))


if __name__ == "__main__":
    main()
