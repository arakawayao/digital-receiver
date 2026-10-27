"""Generate/validate Intel CIC II; --pruned --simulate --install reproduces the project IP."""
import argparse
from collections import deque
import json
import math
from pathlib import Path
import random
import re
import shutil
import subprocess

from cic_model import PrunedCIC

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807_dual/cic_ip"


def run(executable, arguments, target, label, timeout=600):
    result = subprocess.run([str(executable), *map(str, arguments)], cwd=target,
                            capture_output=True, text=True, errors="replace", timeout=timeout)
    log = result.stdout + result.stderr
    (target / (label + ".log")).write_text(log, encoding="utf-8")
    if result.returncode or "** Error" in log or "** Fatal" in log:
        raise RuntimeError(log[-5000:])
    print(label + ": passed", flush=True)
    return log


def compile_ip(modelsim, quartus, simulation, generated=None):
    qip = (generated or ROOT/"ip/cic_intel/sim") / "rx_cic_intel_core.qip"
    library = "rx_cic_intel_core"
    run(modelsim/"vlib.exe", [library], simulation, "library_ip")
    for vendor_library, sources in (("altera_mf", ("altera_mf_components.vhd", "altera_mf.vhd")),
                                    ("lpm", ("220pack.vhd", "220model.vhd"))):
        run(modelsim/"vlib.exe", [vendor_library], simulation, "library_" + vendor_library)
        for name in sources:
            run(modelsim/"vcom.exe", ["-2008", "-work", vendor_library, quartus/"eda/sim_lib"/name],
                simulation, Path(name).stem)
    pattern = r'-name (VHDL_FILE|SYSTEMVERILOG_FILE|VERILOG_FILE) \[file join \$::quartus\(qip_path\) "([^"]+)"\]'
    for kind, relative in re.findall(pattern, qip.read_text()):
        if relative.startswith("aldec/"):
            continue
        source = qip.parent / relative
        tool = "vcom.exe" if kind == "VHDL_FILE" else "vlog.exe"
        options = ["-2008"] if kind == "VHDL_FILE" else ["-sv"]
        run(modelsim/tool, [*options, "-work", library, source], simulation, source.stem)
    return ["-L", library, "-L", "altera_mf"]


def simulate(target, modelsim, quartus, generated=None):
    generated = generated or target/"sim"
    simulation = target / "simulation"
    simulation.mkdir(parents=True, exist_ok=True)
    rng = random.Random(807)
    vectors = []
    for scenario in range(8):
        vectors.extend([(0, 0, 0)] * (3 + scenario))
        if scenario == 6:
            continuous_end = len(vectors)
        for cycle in range(18000):
            valid = scenario != 6 or rng.random() > .3
            if scenario == 7:
                valid = cycle % 400 < 200
            if scenario == 0:
                value = 8388607
            elif scenario == 1:
                value = -8388608
            elif scenario == 2:
                value = 8388607 if cycle == 0 else 0
            elif scenario == 3:
                value = 8388607 if cycle % 2 else -8388608
            elif scenario == 4:
                value = round(4000000 * math.cos(2 * math.pi * 80000 * cycle / 43500000))
            else:
                value = rng.randrange(-8388608, 8388608)
            vectors.append((1, int(valid), value))
        vectors.extend([(1, 0, 0)] * 120)
    (simulation/"inputs.txt").write_text("".join(f"{r} {v} {x}\n" for r, v, x in vectors), encoding="ascii")
    run(modelsim/"vlib.exe", ["work"], simulation, "library_work")
    libraries = compile_ip(modelsim, quartus, simulation, generated)
    run(modelsim/"vlog.exe", ["-sv", ROOT/"rtl/rx_cic.v",
        ROOT/"tests/cic_ip/cic_ip_probe.v", ROOT/"tests/cic_ip/tb_cic_ip_probe.v"],
        simulation, "compile_probe")
    top = (generated/"rx_cic_intel_core.sv").read_text()
    width = int(re.search(r"parameter OUT_WIDTH\s*=\s*(\d+)", top)[1])
    log = run(modelsim/"vsim.exe", ["-c", *libraries, "work.tb_cic_ip_probe",
        f"-gOUT_WIDTH={width}", "-do",
        "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"],
        simulation, "simulate_probe")
    assert "CIC_PROBE_PASS" in log
    rows = [list(map(int, row.split())) for row in (simulation/"probe.txt").read_text().splitlines()]
    assert len(rows) == len(vectors)
    errors = []
    integrators = [0] * 5
    delays = [0] * 5
    pending = deque()
    count = 0
    pruned = PrunedCIC(width) if width != 57 else None
    bit_errors = []
    for cycle, ((reset, valid, value), row) in enumerate(zip(vectors, rows)):
        if not reset:
            integrators = [0] * 5
            delays = [0] * 5
            pending.clear()
            count = 0
            pruned = PrunedCIC(width) if width != 57 else None
        elif valid:
            bit_expected = pruned.push(value) if pruned else None
            for stage in range(5):
                value += integrators[stage]
                integrators[stage] = value
            if count == 0:
                for stage in range(5):
                    previous = value
                    value -= delays[stage]
                    delays[stage] = previous
                pending.append((cycle, value, bit_expected))
            count = (count + 1) % 87
        assert row[0] == cycle
        assert not (reset and valid) or row[1], (cycle, "input backpressure")
        if row[2]:
            assert pending, (cycle, "unexpected output")
            accepted, expected, bit_expected = pending.popleft()
            assert 20 <= cycle - accepted < 1000, (cycle, accepted)
            if cycle < continuous_end:
                assert cycle - accepted == 20, (cycle, accepted)
            if pruned:
                bit_errors.append(row[3] - bit_expected)
            ideal = expected if width == 57 else expected >> 40
            actual = row[3] if width == 57 else row[3] >> (width - 17)
            errors.append(actual - ideal)
    assert len(pending) <= 1, ("undelivered outputs", pending)
    summary = dict(status="PASS", cycles=len(vectors), samples=len(errors),
                   max_error_lsb=max(map(abs, errors)),
                   rms_error_lsb=math.sqrt(sum(e*e for e in errors)/len(errors)),
                   input_backpressure=False, continuous_latency_cycles=20, first_sample_index=0,
                   held_at_end=len(pending))
    if bit_errors:
        summary["bit_exact_max_error"] = max(map(abs, bit_errors))
    (target/"simulation.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    assert summary["max_error_lsb"] <= (0 if width == 57 else 1 if width == 20 else 4), summary
    assert not bit_errors or max(map(abs, bit_errors)) == 0, summary


def generate(quartus, rounding="NONE", width=20):
    variant = "full" if rounding == "NONE" else "pruned"
    target = OUT / variant
    parameters = dict(FILTER_TYPE="decimator", STAGES=5, D_DELAY=1, VRC_EN=0,
                      RCF_FIX=87, INTERFACES=1, CH_PER_INT=1, IN_WIDTH=24,
                      REQ_OUT_WIDTH=width, ROUND_TYPE=rounding,
                      REQ_INT_MEM="logic_element", REQ_DIF_MEM="logic_element")
    for fileset, folder in (("QUARTUS_SYNTH", "synth"), ("SIM_VERILOG", "sim")):
        output = target / folder
        output.mkdir(parents=True, exist_ok=True)
        command = [str(quartus/"sopc_builder/bin/ip-generate.exe"),
                   "--component-name=altera_cic_ii", "--output-name=rx_cic_intel_core",
                   f"--output-directory={output}", f"--file-set={fileset}",
                   "--language=VERILOG", "--part=EP4CE6F17C8", "--standard-reports",
                   "--remove-qsys-generate-warning"]
        command.extend(f"--component-parameter={key}={value}" for key, value in parameters.items())
        with (target/f"generate_{folder}.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        if result.returncode:
            raise RuntimeError(f"CIC generation failed: {target}")
        print(f"{variant}/{folder}: generated", flush=True)
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    parser.add_argument("--pruned", action="store_true")
    parser.add_argument("--skip-generate", action="store_true")
    parser.add_argument("--simulate", action="store_true")
    parser.add_argument("--install", action="store_true", help="Copy the validated 20-bit IP into ip/cic_intel")
    parser.add_argument("--installed", action="store_true", help="Validate the checked-in/generated project IP")
    parser.add_argument("--synthesize", action="store_true")
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    args = parser.parse_args()
    target = OUT / ("pruned" if args.pruned else "full")
    if args.installed:
        assert args.pruned and not args.install and not args.synthesize
    if not args.skip_generate and not args.installed:
        generate(args.quartus, "H_PRUNE" if args.pruned else "NONE")
    if args.simulate:
        simulate(target, args.modelsim, args.quartus, ROOT/"ip/cic_intel/sim" if args.installed else None)
    if args.synthesize:
        run(args.quartus/"bin64/quartus_sh.exe", ["-t", ROOT/"tests/cic_ip/probe.tcl", target], target, "project")
        run(args.quartus/"bin64/quartus_map.exe", ["probe"], target, "map")
    if args.install:
        assert args.pruned and args.simulate, "Installation requires --pruned --simulate"
        for folder in ("synth", "sim"):
            top = (target/folder/"rx_cic_intel_core.sv").read_text()
            assert int(re.search(r"parameter OUT_WIDTH\s*=\s*(\d+)", top)[1]) == 20
        for folder in ("synth", "sim"):
            shutil.copytree(target/folder, ROOT/"ip/cic_intel"/folder, dirs_exist_ok=True)
        print("Validated 20-bit CIC installed", flush=True)


if __name__ == "__main__":
    main()
