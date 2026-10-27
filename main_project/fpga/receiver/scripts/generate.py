"""Reproducible coefficient tables and Intel Clearbox IP; no legacy RTL inputs."""
import argparse
import json
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_QUARTUS = Path(r"D:\intelFPGA\18.1\quartus")


def run(cmd, cwd=ROOT):
    result = subprocess.run(list(map(str, cmd)), cwd=cwd, capture_output=True,
                            text=True, errors="replace", timeout=120)
    print(result.stdout, end="")
    if result.returncode or "ERROR" in result.stdout.upper():
        raise RuntimeError(result.stdout + result.stderr)


def coefficients():
    # Least squares type-I FIR: compensate CIC in 0..100 kHz; suppress
    # 150..250 kHz. 100..150 kHz is an explicit transition band.
    import numpy as np
    f = np.concatenate((np.linspace(0, .2, 501), np.linspace(.3, .5, 501)))
    target = np.concatenate((1 / np.sinc(f[:501]) ** 5, np.zeros(501)))
    weights = np.concatenate((np.ones(501), np.ones(501) * 20))
    a = np.column_stack([np.ones(len(f))] +
                        [2 * np.cos(2 * np.pi * f * k) for k in range(1, 31)])
    half = np.linalg.lstsq(a * weights[:, None], target * weights, rcond=None)[0]
    h = np.concatenate((half[:0:-1], half))
    h /= sum(h)
    q = np.rint(h * 131072).astype(int)
    q[30] += 131072 - sum(q)
    assert max(abs(q)) < 131072
    (ROOT / "rtl" / "fir_coeff.hex").write_text(
        "".join(f"{int(v) & 0x3ffff:05x}\n" for v in q), encoding="ascii")
    nco = [round(2047 * math.sin(math.tau * k / 1024)) for k in range(1024)]
    (ROOT / "rtl" / "nco_sine.hex").write_text(
        "".join(f"{v & 4095:03x}\n" for v in nco), encoding="ascii")
    results = {}
    for rate in (112,):
        grid = np.linspace(0, .5, 10001)
        fir = abs(sum(v / 131072 * np.exp(-2j * np.pi * grid * k)
                      for k, v in enumerate(q)))
        cic = np.ones(len(grid))
        cic[1:] = abs(np.sin(np.pi * grid[1:]) /
                     (rate * np.sin(np.pi * grid[1:] / rate))) ** 5
        total = fir * cic
        pass_db = 20 * np.log10(total[grid <= .2])
        stop_db = 20 * np.log10(np.maximum(total[grid >= .3], 1e-15))
        # Worst first-stage alias into the desired +/-100 kHz band.
        aliases = np.linspace(.8, rate / 2, 100001)
        folded = abs((aliases + .5) % 1 - .5)
        response = abs(np.sin(np.pi * aliases) /
                       (rate * np.sin(np.pi * aliases / rate))) ** 5
        alias_db = 20 * np.log10(max(response[folded <= .2]))
        assert max(abs(pass_db)) < .15 and max(stop_db) < -65 and alias_db < -60
        results[str(rate)] = dict(pass_min_db=float(min(pass_db)),
            pass_max_db=float(max(pass_db)), stop_max_db=float(max(stop_db)),
            alias_max_db=float(alias_db), coefficients=q.tolist())
    (ROOT / "filter_report.json").write_text(json.dumps(results, indent=2), encoding="utf-8")


def ips(quartus, pll_only=False):
    # ADC is fixed at 56 MHz; the core board supplies a 24 MHz reference.
    for rate, mult, div in ((56, 7, 3),):
        name = f"rx_pll{rate}"
        args = ["altpll", "CBX_HDL_LANGUAGE=Verilog", f"CBX_FILE={name}.v",
            f"CBX_OUTPUT_DIRECTORY={ROOT.as_posix()}/ip", f"CBX_MODULE_PREFIX={name}",
            "device_family=Cyclone IV E", "intended_device_family=Cyclone IV E",
            "inclk0_input_frequency=41667", f"clk0_multiply_by={mult}",
            f"clk0_divide_by={div}", "clk1_multiply_by=1", "clk1_divide_by=1",
            "width_clock=5", "port_clk0=PORT_USED", "port_clk1=PORT_USED",
            "port_clk2=PORT_UNUSED", "port_clk3=PORT_UNUSED", "port_clk4=PORT_UNUSED",
            "compensate_clock=CLK0", "inclk", "clk", "areset", "locked"]
        run([quartus / "bin64/clearbox.exe", *args])
    if pll_only:
        return
    run([quartus / "bin64/clearbox.exe", "dcfifo", "CBX_HDL_LANGUAGE=Verilog",
         "CBX_FILE=rx_fifo.v", f"CBX_OUTPUT_DIRECTORY={ROOT.as_posix()}/ip",
         "CBX_MODULE_PREFIX=rx_fifo", "DEVICE_FAMILY=Cyclone IV E",
         "LPM_WIDTH=97", "LPM_WIDTHU=9", "LPM_NUMWORDS=512", "LPM_SHOWAHEAD=ON",
         "USE_EAB=ON", "RDSYNC_DELAYPIPE=4", "WRSYNC_DELAYPIPE=4",
         "OVERFLOW_CHECKING=ON", "UNDERFLOW_CHECKING=ON",
         "READ_ACLR_SYNCH=ON", "WRITE_ACLR_SYNCH=ON",
         "aclr", "data", "q", "rdclk", "wrclk", "rdreq", "wrreq", "rdempty", "wrfull"])
    run([quartus / "bin64/clearbox.exe", "altddio_out", "CBX_HDL_LANGUAGE=Verilog",
         "CBX_FILE=rx_ifclk.v", f"CBX_OUTPUT_DIRECTORY={ROOT.as_posix()}/ip",
         "CBX_MODULE_PREFIX=rx_ifclk", "DEVICE_FAMILY=Cyclone IV E", "WIDTH=1",
         "datain_h", "datain_l", "outclock", "outclocken", "dataout"])


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--quartus", type=Path, default=DEFAULT_QUARTUS)
    p.add_argument("--ip-only", action="store_true")
    p.add_argument("--tables-only", action="store_true")
    p.add_argument("--pll-only", action="store_true",
                   help="generate only the 56 MHz PLL, preserving FIFO/DDIO IP")
    args = p.parse_args()
    if not args.ip_only and not args.pll_only:
        coefficients()
    if not args.tables_only:
        ips(args.quartus, pll_only=args.pll_only)
