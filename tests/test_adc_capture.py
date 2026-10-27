"""Run the portable ADC RTL testbench with Icarus or Vivado Simulator."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AdcCaptureTests(unittest.TestCase):
    def test_capture_and_formats(self):
        rtl = ROOT / "main_project/fpga/srcs/adc_capture.v"
        tb = ROOT / "tests/rtl/acquisition/adc_capture_tb.sv"
        iverilog = shutil.which("iverilog")
        vvp = shutil.which("vvp")
        xvlog = shutil.which("xvlog")
        xelab = shutil.which("xelab")
        xsim = shutil.which("xsim")

        with tempfile.TemporaryDirectory(prefix="adc_capture_") as directory:
            if iverilog and vvp:
                executable = str(Path(directory) / "adc_capture.vvp")
                commands = [
                    [iverilog, "-g2012", "-Wall", "-s", "adc_capture_tb",
                     "-o", executable, str(rtl), str(tb)],
                    [vvp, executable],
                ]
            elif xvlog and xelab and xsim:
                commands = [
                    [xvlog, str(rtl)],
                    [xvlog, "--sv", str(tb)],
                    [xelab, "adc_capture_tb", "--snapshot", "adc_capture_sim"],
                    [xsim, "adc_capture_sim", "--runall"],
                ]
            else:
                self.fail("RTL simulator missing: provide iverilog/vvp or "
                          "xvlog/xelab/xsim on PATH")

            for command in commands:
                result = subprocess.run(
                    command, cwd=directory, capture_output=True, text=True,
                    errors="replace", timeout=60, check=False,
                )
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0,
                                 f"{command[0]} failed:\n{output}")
            self.assertIn("ADC_CAPTURE_PASS cycles=4233", output, output)


if __name__ == "__main__":
    unittest.main()
