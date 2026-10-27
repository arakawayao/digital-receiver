"""Compatibility discovery entry; host tests are maintained in host/tests/."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT / "host"))
sys.path.insert(0, str(PROJECT))
from host.tests.legacy.test_replay import *

if __name__ == "__main__":
    import unittest
    unittest.main()
