"""Compare mixer RTL against trigonometric vectors and frequency translation."""

import cmath
import math
import random
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def nearest(value):
    return math.floor(value + 0.5) if value >= 0 else math.ceil(value - 0.5)


def expected_outputs(rows):
    phase = 0
    pending = None
    last_i = last_q = 0
    expected = []
    for rst_n, den, sample, increment in rows:
        if not rst_n:
            phase = 0
            pending = None
            last_i = last_q = 0
            valid = 0
        else:
            valid = int(pending is not None)
            if pending is not None:
                last_i, last_q = pending
            pending = None
            if den:
                # Quantize the phase, then evaluate trig independently of the ROM.
                angle = math.tau * (phase >> 24) / 256
                pending = (sample * nearest(2047 * math.cos(angle)),
                           sample * nearest(-2047 * math.sin(angle)))
                phase = (phase + increment) % (1 << 32)
        expected.append((valid, last_i, last_q))
    return expected


class DdcMixerTests(unittest.TestCase):
    def test_numeric_pipeline_and_translation(self):
        rows = [(0, 1, -2048, 0)]
        # Every LUT phase and both ADC rails, including phase wrap.
        for sample in (-2048, -1, 0, 1, 2047):
            rows.append((0, 0, 0, 0))
            rows.extend((1, 1, sample, 1 << 24) for _ in range(513))
            rows.extend([(1, 0, 123, 0)] * 3)

        rng = random.Random(20260929)
        for increment in (0, 0x33333333, 0x80000000, 0xE1234567, 0xFFFFFFFF):
            rows.append((0, 1, 2047, increment))
            for cycle in range(1024):
                rows.append((int(cycle != 503), int(rng.random() > 0.25),
                             rng.randrange(-2048, 2048), increment))
            rows.extend([(1, 0, -2048, increment)] * 4)

        # LO = Fs/8. Input at LO +/- Fs/128 must emerge at +/- Fs/128.
        # Also test on-frequency conversion to DC; image remains until filtering.
        spectra = []
        length = 1024
        for offset_bin in (-8, 0, 8):
            rows.append((0, 0, 0, 0))
            start = len(rows)
            for n in range(length):
                sample = nearest(1000 * math.cos(math.tau * (128 + offset_bin)
                                                * n / length))
                rows.append((1, 1, sample, 1 << 29))
            rows.extend([(1, 0, 0, 1 << 29)] * 2)
            spectra.append((start + 1, offset_bin))

        rtl = ROOT / "main_project/fpga/srcs/ddc_mixer.v"
        tb = ROOT / "tests/rtl/ddc/ddc_mixer_tb.sv"
        iverilog, vvp = shutil.which("iverilog"), shutil.which("vvp")
        xvlog, xelab, xsim = (shutil.which(name) for name in ("xvlog", "xelab", "xsim"))
        with tempfile.TemporaryDirectory(prefix="ddc_mixer_") as directory:
            work = Path(directory)
            (work / "inputs.txt").write_text(
                "".join(f"{rst} {den} {value} {inc:08x}\n"
                        for rst, den, value, inc in rows), encoding="ascii")
            if iverilog and vvp:
                executable = str(work / "ddc_mixer.vvp")
                commands = [
                    [iverilog, "-g2012", "-Wall", "-s", "ddc_mixer_tb",
                     "-o", executable, str(rtl), str(tb)],
                    [vvp, executable],
                ]
            elif xvlog and xelab and xsim:
                commands = [
                    [xvlog, str(rtl)],
                    [xvlog, "--sv", str(tb)],
                    [xelab, "ddc_mixer_tb", "--snapshot", "ddc_mixer_sim"],
                    [xsim, "ddc_mixer_sim", "--runall"],
                ]
            else:
                self.fail("RTL simulator missing: provide iverilog/vvp or "
                          "xvlog/xelab/xsim on PATH")
            for command in commands:
                result = subprocess.run(command, cwd=directory, capture_output=True,
                                        text=True, errors="replace", timeout=60,
                                        check=False)
                output = result.stdout + result.stderr
                self.assertEqual(result.returncode, 0,
                                 f"{command[0]} failed:\n{output}")
            self.assertIn(f"DDC_MIXER_PASS cycles={len(rows)}", output, output)
            actual = [tuple(map(int, row.split())) for row in
                      (work / "outputs.txt").read_text(encoding="ascii").splitlines()]

        expected = expected_outputs(rows)
        self.assertEqual(len(actual), len(expected))
        for cycle, (got, want) in enumerate(zip(actual, expected)):
            self.assertEqual(got, want, f"cycle={cycle}, input={rows[cycle]}")

        for start, offset_bin in spectra:
            samples = actual[start:start + length]
            self.assertTrue(all(valid == 1 for valid, _, _ in samples))
            iq = [complex(i, q) / 2048 for _, i, q in samples]

            def amplitude(bin_index):
                return abs(sum(value * cmath.exp(-1j * math.tau * bin_index * n / length)
                               for n, value in enumerate(iq)) / length)

            self.assertAlmostEqual(amplitude(offset_bin), 500 * 2047 / 2048, delta=0.5)
            if offset_bin:
                self.assertLess(amplitude(-offset_bin), 0.5)
            self.assertGreater(amplitude(-256 - offset_bin), 499)


if __name__ == "__main__":
    unittest.main()
