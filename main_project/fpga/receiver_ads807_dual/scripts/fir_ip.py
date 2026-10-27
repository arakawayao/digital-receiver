"""Isolated Intel FIR II evaluation; never changes the receiver RTL or QSF."""
import argparse
from collections import deque
import hashlib
import json
from pathlib import Path
import random
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807_dual/fir_ip"


def coefficients():
    path = ROOT / "rtl/fir_coeff.hex"
    values = [int(word, 16) for word in path.read_text().split()]
    values = [(value + 131072) % 262144 - 131072 for value in values]
    assert len(values) == 61 and values == values[::-1]
    return values


def run(executable, arguments, target, label, timeout=600):
    with (target / (label + ".log")).open("w", encoding="utf-8") as log:
        result = subprocess.run([str(executable), *map(str, arguments)], cwd=target,
                                stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"{label} failed; see {target / (label + '.log')}")
    contents = (target / (label + ".log")).read_text(errors="replace")
    if "** Error" in contents or "** Fatal" in contents:
        raise RuntimeError(contents[-5000:])
    print(label + ": passed", flush=True)
    return contents


def compile_ip(modelsim, quartus, simulation, generated):
    library = "rx_fir_intel_core"
    run(modelsim/"vlib.exe", ["work"], simulation, "library_work")
    run(modelsim/"vlib.exe", [library], simulation, "library_ip")
    for vendor_library, sources in (("altera_mf", ("altera_mf_components.vhd", "altera_mf.vhd")),
                                    ("lpm", ("220pack.vhd", "220model.vhd"))):
        run(modelsim/"vlib.exe", [vendor_library], simulation, "library_" + vendor_library)
        for name in sources:
            run(modelsim/"vcom.exe", ["-2008", "-work", vendor_library, quartus/"eda/sim_lib"/name],
                simulation, Path(name).stem)
    pattern = r'-name (VHDL_FILE|VERILOG_FILE) \[file join \$::quartus\(qip_path\) "([^"]+)"\]'
    for kind, relative in re.findall(pattern, (generated/"rx_fir_intel_core.qip").read_text()):
        if relative.endswith("_tb.vhd"):
            continue
        source = generated/relative
        tool = "vcom.exe" if kind == "VHDL_FILE" else "vlog.exe"
        options = ["-2008"] if kind == "VHDL_FILE" else ["-sv"]
        run(modelsim/tool, [*options, "-work", library, source], simulation, source.stem)
    return ["-L", library, "-L", "altera_mf", "-L", "lpm"]


def vectors():
    rng = random.Random(80761)
    rows = []
    cases = []
    for scenario in range(8):
        rows.extend([(0, 0, 0, 0, 0, 0, 0, 0, 0)] * 8)
        start = len(rows)
        for sample in range(160):
            if scenario == 0:
                i, q = (131071 if sample == 0 else 0), 0
            elif scenario == 1:
                i, q = 131071, -131072
            elif scenario == 2:
                i = 131071 if sample % 2 else -131072
                q = -i - 1
            elif scenario == 3:
                i, q = 0, (-131072 if sample == 0 else 0)
            elif scenario == 4:
                i, q = 0, 0
            else:
                i, q = rng.randrange(-131072, 131072), rng.randrange(-131072, 131072)
            clip = int(sample % 7 == 0)
            rows.append((1, 1, i, q, clip, 1, i, 1, 0))
            rows.append((1, 0, 0, 0, 0, 1, q, 0, 1))
            gap = rng.randrange(85, 180) if scenario == 6 else 85
            rows.extend([(1, 0, 0, 0, 0, 0, 0, 0, 0)] * gap)
        if scenario == 7:
            # Cancel an accepted pair while its convolution is in flight.
            rows.append((1, 1, 23456, -78901, 1, 1, 23456, 1, 0))
            rows.append((1, 0, 0, 0, 0, 1, -78901, 0, 1))
            rows.extend([(0, 0, 0, 0, 0, 0, 0, 0, 0)] * 8)
            for sample in range(80):
                rows.append((1, 1, 0, 0, 0, 1, 0, 1, 0))
                rows.append((1, 0, 0, 0, 0, 1, 0, 0, 1))
                rows.extend([(1, 0, 0, 0, 0, 0, 0, 0, 0)] * 85)
        rows.extend([(1, 0, 0, 0, 0, 0, 0, 0, 0)] * 150)
        cases.append(dict(scenario=scenario, start=start, end=len(rows)))
    return rows, cases


def sat16(value):
    return min(32767, max(-32768, (value + 65536) >> 17))


def simulate(target, modelsim, quartus):
    simulation = target/"simulation"
    simulation.mkdir(parents=True, exist_ok=True)
    (simulation/"rtl").mkdir(exist_ok=True)
    shutil.copyfile(ROOT/"rtl/fir_coeff.hex", simulation/"rtl/fir_coeff.hex")
    rows, cases = vectors()
    (simulation/"inputs.txt").write_text("".join(" ".join(map(str, row)) + "\n" for row in rows), encoding="ascii")
    libraries = compile_ip(modelsim, quartus, simulation, target/"sim")
    run(modelsim/"vlog.exe", ["-sv", ROOT/"rtl/rx_fir.v", ROOT/"tests/fir_ip/rx_fir_intel_eval.v",
        ROOT/"tests/fir_ip/tb_fir_ip.v"],
        simulation, "compile_probe")
    log = run(modelsim/"vsim.exe", ["-c", *libraries, "work.tb_fir_ip", "-do",
        "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"], simulation, "simulate_probe")
    assert "FIR_PROBE_PASS" in log
    events = {}
    for line in (simulation/"probe.txt").read_text().splitlines():
        fields = line.split()
        events.setdefault(int(fields[1]), []).append((fields[0], fields[2:]))
    coeff = coefficients()
    history = deque(maxlen=61)
    pending_raw = deque()
    pending_legacy = deque()
    pending_adapter = deque()
    latencies = {"raw": [], "legacy": [], "adapter": []}
    mismatches = []
    reset_transients = []
    warm_count = 0
    count = 0
    for cycle, row in enumerate(rows):
        reset, valid, i, q, clip, *_ = row
        if not reset:
            history.clear()
            pending_raw.clear()
            pending_legacy.clear()
            pending_adapter.clear()
            warm_count = 0
        elif valid:
            history.appendleft((i, q))
            sums = [sum(c*x[channel] for c, x in zip(coeff, history)) for channel in range(2)]
            for channel in range(2):
                pending_raw.append((cycle, channel, sums[channel], warm_count < 60))
            rounded = [(value+65536) >> 17 for value in sums]
            expected_clip = int(clip or any(value < -32768 or value > 32767 for value in rounded))
            pending_legacy.append((cycle, sat16(sums[0]), sat16(sums[1]), expected_clip))
            if warm_count >= 60:
                pending_adapter.append((cycle, sat16(sums[0]), sat16(sums[1]), expected_clip))
            warm_count += 1
        for kind, fields in events.get(cycle, []):
            if kind == "R":
                accepted, channel, expected, warming = pending_raw.popleft()
                actual_channel, sop, eop, error = map(int, fields[:4])
                assert (actual_channel, sop, eop, error) == (channel, 1-channel, channel, 0), (cycle, fields)
                latencies["raw"].append(cycle-accepted)
                if fields[4].lower().find("x") >= 0 or int(fields[4]) != expected:
                    destination = reset_transients if warming else mismatches
                    destination.append(dict(cycle=cycle, accepted=accepted, channel=channel,
                                            expected=expected, actual=fields[4]))
                count += 1
            else:
                queue = pending_legacy if kind == "L" else pending_adapter
                accepted, *expected = queue.popleft()
                assert list(map(int, fields)) == expected, (cycle, fields, expected)
                latencies["legacy" if kind == "L" else "adapter"].append(cycle-accepted)
    assert not pending_raw and not pending_legacy and not pending_adapter
    summary = dict(status="PASS_WITH_RESET_WARMUP" if not mismatches else "NUMERICAL_MISMATCH", cycles=len(rows),
                   raw_outputs=count, mismatches=len(mismatches), first_mismatches=mismatches[:10],
                   reset_transient_mismatches=len(reset_transients), first_reset_transients=reset_transients[:4],
                   adapter_pairs_checked=len(latencies["adapter"]), discarded_pairs_per_reset=60,
                   steady_state_input_pair_spacing_clocks=87, input_pair_rate_hz=500000,
                   latency_cycles={key: sorted(set(value)) for key, value in latencies.items()}, cases=cases)
    (target/"simulation.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    assert not mismatches, summary


def production_fingerprint():
    paths = list((ROOT/"rtl").rglob("*")) + list((ROOT/"ip").rglob("*"))
    paths += list(ROOT.glob("*.qsf")) + list(ROOT.glob("*.qpf")) + list(ROOT.glob("*.sdc"))
    paths += list(ROOT.glob("board*.tcl"))
    return {str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in sorted(paths) if path.is_file()}


def synthesize(target, quartus):
    comparison = {}
    for mode in ("legacy", "official"):
        build = target/"build"/mode
        build.mkdir(parents=True, exist_ok=True)
        (build/"rtl").mkdir(exist_ok=True)
        shutil.copyfile(ROOT/"rtl/fir_coeff.hex", build/"rtl/fir_coeff.hex")
        run(quartus/"bin64/quartus_sh.exe", ["-t", ROOT/"tests/fir_ip/probe.tcl", build, mode, target],
            build, "project")
        run(quartus/"bin64/quartus_map.exe", ["probe"], build, "map")
        run(quartus/"bin64/quartus_fit.exe", ["probe"], build, "fit", timeout=900)
        run(quartus/"bin64/quartus_sta.exe", ["-t", ROOT/"scripts/timing.tcl", "probe"], build, "sta")
        report = (build/"output/probe.fit.rpt").read_text(errors="replace")
        resources = {}
        for name, pattern in (("logic_elements", r"Total logic elements\s*;\s*([\d,]+)"),
                              ("registers", r"Total registers\s*;\s*([\d,]+)"),
                              ("m9k", r"M9Ks\s*;\s*([\d,]+)"),
                              ("multiplier_9bit", r"Embedded Multiplier 9-bit elements\s*;\s*([\d,]+)")):
            resources[name] = int(re.search(pattern, report)[1].replace(",", ""))
        slacks = {}
        for path in sorted(build.glob("probe_corner*_*.rpt")):
            match = re.search(r"Worst case slack is ([\d.-]+)", path.read_text(errors="replace"))
            if match:
                slacks[path.stem] = float(match[1])
        assert len(slacks) >= 6 and min(slacks.values()) >= 0, slacks
        license_lines = []
        for step in ("map", "fit", "sta"):
            license_lines.extend(line.strip() for line in (build/(step+".log")).read_text(errors="replace").splitlines()
                                 if re.search(r"(?i)license|opencore|evaluation", line))
        comparison[mode] = dict(resources=resources, constrained_corner_slacks_ns=slacks,
                                constrained_timing_pass=True, license_messages=license_lines)
        (target/"comparison.json").write_text(json.dumps(comparison, indent=2), encoding="utf-8")
        print(mode + ": " + json.dumps(resources), flush=True)
    comparison["official_minus_legacy"] = {
        key: comparison["official"]["resources"][key] - value
        for key, value in comparison["legacy"]["resources"].items()}
    comparison["scope"] = "Isolated EP4CE6F17C8 fit with virtual synchronous I/O; no main receiver fit, SOF or board validation"
    (target/"comparison.json").write_text(json.dumps(comparison, indent=2), encoding="utf-8")
    print(json.dumps(comparison, indent=2))


def generate(quartus, variant):
    target = OUT / variant
    target.mkdir(parents=True, exist_ok=True)
    parameters = dict(filterType="single", symmetryMode="sym", inputChannelNum=2,
                      clockRate="43.5", inputRate="0.5", coeffReload="false",
                      backPressure="false", deviceFamily="Cyclone IV E", speedGrade="slow",
                      inputType="int", inputBitWidth=18, coeffType="int", coeffBitWidth=18,
                      coeffScaling="none", coeffSetRealValue=",".join(map(str, coefficients())),
                      outType="int", outMSBRound="trunc", outMsbBitRem=0,
                      outLSBRound="trunc", outLsbBitRem=0)
    config = dict(tool="Quartus Prime 18.1", device="EP4CE6F17C8", parameters=parameters,
                  coefficient_sha256=hashlib.sha256((ROOT/"rtl/fir_coeff.hex").read_bytes()).hexdigest(),
                  intent="I/Q 18-bit integer samples; coefficients interpreted as Q1.17 by external conversion")
    (target/"configuration.json").write_text(json.dumps(config, indent=2), encoding="utf-8")
    component = quartus.parent/"ip/altera/dsp/altera_fir_compiler_ii/src/HP_FIR_hw.tcl"
    for fileset, folder in (("QUARTUS_SYNTH", "synth"), ("SIM_VHDL", "sim")):
        destination = target/folder
        command = [f"--component-file={component}", "--component-name=altera_fir_compiler_ii",
                   "--output-name=rx_fir_intel_core", f"--output-directory={destination}",
                   f"--file-set={fileset}", "--language=VHDL", "--part=EP4CE6F17C8",
                   "--standard-reports", "--remove-qsys-generate-warning"]
        command.extend(f"--component-parameter={key}={value}" for key, value in parameters.items())
        run(quartus/"sopc_builder/bin/ip-generate.exe", command, target, "generate_" + folder)
    return target


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    parser.add_argument("--variant", choices=("tdm",), default="tdm")
    parser.add_argument("--skip-generate", action="store_true")
    parser.add_argument("--simulate", action="store_true")
    parser.add_argument("--synthesize", action="store_true")
    parser.add_argument("--modelsim", type=Path, default=Path("D:/modeltech64_2020.4/win64"))
    args = parser.parse_args()
    target = OUT/args.variant
    original = production_fingerprint()
    try:
        if not args.skip_generate:
            generate(args.quartus, args.variant)
        if args.simulate:
            simulate(target, args.modelsim, args.quartus)
        if args.synthesize:
            synthesize(target, args.quartus)
    finally:
        unchanged = production_fingerprint() == original
        target.mkdir(parents=True, exist_ok=True)
        (target/"source_integrity.json").write_text(json.dumps(dict(unchanged=unchanged,
            production_source_sha256=original), indent=2), encoding="utf-8")
        assert unchanged, "Production receiver sources changed during isolation evaluation"


if __name__ == "__main__":
    main()
