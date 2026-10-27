"""Paths for the standalone host project; never depend on the FPGA checkout."""
from pathlib import Path
import sys

RESOURCE_ROOT = Path(__file__).resolve().parents[1]
HOST_ROOT = Path(sys.executable).resolve().parent if getattr(sys, "frozen", False) else RESOURCE_ROOT
ARTIFACT_ROOT = HOST_ROOT / ".harness"
FIRMWARE_ROOT = HOST_ROOT / "firmware"
