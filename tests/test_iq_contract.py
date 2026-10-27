import copy
import tempfile
import unittest
from pathlib import Path

from reference.iq import read_capture, validate_capture, write_capture


class CaptureContractTests(unittest.TestCase):
    def setUp(self):
        self.capture = {
            "schema_version": 1,
            "sample_rate_hz": 48_000,
            "center_frequency_hz": 100_000_000,
            "iq_format": "normalized_float",
            "samples": [[1, -1], [0.25, -0.5]],
        }

    def test_round_trip(self):
        self.capture["metadata"] = {"note": "test", "nested": [None, True, 1.5]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.json"
            write_capture(path, self.capture)
            self.assertEqual(read_capture(path), self.capture)

    def test_invalid_fields(self):
        cases = {
            "schema_version": [True, 1.0, 2],
            "sample_rate_hz": [0, -1, True, "48000", float("nan"), float("inf")],
            "center_frequency_hz": [87_999_999, 108_000_001, float("-inf")],
            "iq_format": ["int16", None],
            "samples": [[], None, [[0]], [[0, 0, 0]], [(0, 0)],
                        [[float("nan"), 0]], [[0, float("inf")]],
                        [[True, 0]], [[1.01, 0]], [[0, -1.01]], [["0", 0]]],
            "metadata": [[], {"nested": [float("nan")]}, {1: "key"}, {"x": object()}],
        }
        for field, values in cases.items():
            for value in values:
                with self.subTest(field=field, value=value):
                    capture = copy.deepcopy(self.capture)
                    capture[field] = value
                    with self.assertRaises(ValueError):
                        validate_capture(capture)

    def test_missing_unknown_and_nonobject(self):
        for field in self.capture:
            capture = dict(self.capture)
            del capture[field]
            with self.assertRaises(ValueError):
                validate_capture(capture)
        with self.assertRaises(ValueError):
            validate_capture([])
        with self.assertRaises(ValueError):
            validate_capture(dict(self.capture, extra=1))

    def test_frequency_boundaries(self):
        for frequency in (88_000_000, 108_000_000):
            self.capture["center_frequency_hz"] = frequency
            validate_capture(self.capture)

    def test_invalid_write_preserves_destination(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.json"
            write_capture(path, self.capture)
            before = path.read_bytes()
            self.capture["samples"] = [[2, 0]]
            with self.assertRaises(ValueError):
                write_capture(path, self.capture)
            self.assertEqual(path.read_bytes(), before)

    def test_bad_json_and_duplicates(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "capture.json"
            for content in ('{', '{"a": 1, "a": 2}'):
                path.write_text(content, encoding="utf-8")
                with self.assertRaises(ValueError):
                    read_capture(path)


if __name__ == "__main__":
    unittest.main()
