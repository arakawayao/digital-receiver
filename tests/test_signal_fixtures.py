import cmath
import math
import unittest

from reference.fixtures import make_capture
from reference.iq import validate_capture


class SignalFixtureTests(unittest.TestCase):
    def test_deterministic_valid_captures(self):
        for kind in ("am", "fm", "silence"):
            with self.subTest(kind=kind):
                capture = make_capture(kind)
                validate_capture(capture)
                self.assertEqual(capture, make_capture(kind))
                self.assertEqual(len(capture["samples"]), 4800)
                self.assertEqual(capture["metadata"]["truth"]["kind"], kind)

    def test_am_envelope(self):
        capture = make_capture("am")
        for index, (i, q) in enumerate(capture["samples"]):
            expected = 0.5 * (1 + 0.6 * math.cos(2 * math.pi * 1000 * index / 48000))
            self.assertAlmostEqual(math.hypot(i, q), expected, places=12)
            self.assertEqual(q, 0)
        self.assertAlmostEqual(min(i for i, _ in capture["samples"]), 0.2)
        self.assertAlmostEqual(max(i for i, _ in capture["samples"]), 0.8)

    def test_fm_phase_increment_and_envelope(self):
        samples = [complex(i, q) for i, q in make_capture("fm")["samples"]]
        for index, sample in enumerate(samples):
            self.assertAlmostEqual(abs(sample), 0.5, places=12)
            if index + 1 < len(samples):
                measured = cmath.phase(samples[index + 1] * sample.conjugate())
                expected = 2 * math.pi * 2000 / 48000 * math.cos(2 * math.pi * 1000 * index / 48000)
                self.assertAlmostEqual(measured, expected, places=12)

    def test_silence(self):
        self.assertTrue(all(pair == [0.0, 0.0] for pair in make_capture("silence")["samples"]))

    def test_unknown_kind(self):
        with self.assertRaises(ValueError):
            make_capture("unknown")


if __name__ == "__main__":
    unittest.main()
