"""Compatibility entry point. Implementation is maintained under host/."""
from importlib import import_module
from pathlib import Path
import runpy
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[4]))

if __name__ == "__main__":
    runpy.run_module("host.ads807.legacy.receiver.usb_transport", run_name="__main__")
else:
    sys.modules[__name__] = import_module("host.ads807.legacy.receiver.usb_transport")
