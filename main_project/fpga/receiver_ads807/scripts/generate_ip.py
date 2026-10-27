"""Generate only this project's fixed ADS807 PLL with the installed Intel Clearbox."""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quartus", type=Path, default=Path("D:/intelFPGA/18.1/quartus"))
    args = parser.parse_args()
    command = [str(args.quartus / "bin64/clearbox.exe"), "altpll",
        "CBX_HDL_LANGUAGE=Verilog", "CBX_FILE=rx_pll_ads807.v",
        f"CBX_OUTPUT_DIRECTORY={ROOT.as_posix()}/ip", "CBX_MODULE_PREFIX=rx_pll_ads807",
        "device_family=Cyclone IV E", "intended_device_family=Cyclone IV E",
        "inclk0_input_frequency=41667", "clk0_multiply_by=29", "clk0_divide_by=16",
        "clk1_multiply_by=1", "clk1_divide_by=1", "clk0_duty_cycle=50",
        "width_clock=5", "port_clk0=PORT_USED", "port_clk1=PORT_USED",
        "port_clk2=PORT_UNUSED", "port_clk3=PORT_UNUSED", "port_clk4=PORT_UNUSED",
        "compensate_clock=CLK0", "inclk", "clk", "areset", "locked"]
    subprocess.run(command, cwd=ROOT, check=True, timeout=120)


if __name__ == "__main__":
    main()
