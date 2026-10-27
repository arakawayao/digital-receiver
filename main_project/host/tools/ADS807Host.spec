# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path
import os
import sys

root = Path(SPECPATH).parent
sys.path.insert(0, str(root))
from ads807.build_usb_pump import build_inputs

sdk = Path(os.environ["ADS807_CYUSB_DLL"])
source, assembly, _ = build_inputs(sdk)
datas = [
    (str(root / "ads807/theme.qss"), "ads807"),
    (str(root / "ads807/theme_light.qss"), "ads807"),
    (str(root / "ads807/assets/receiver.ico"), "ads807/assets"),
    (str(source), "ads807"),
    (str(sdk), "usb"),
    (str(assembly), "managed"),
    (str(assembly.with_suffix(".json")), "managed"),
]
# Conda's _ctypes.pyd links against libffi outside Python's DLLs directory.
binaries = []
ffi = Path(sys.base_prefix) / "Library/bin/ffi.dll"
if ffi.is_file():
    binaries.append((str(ffi), "."))
a = Analysis(
    [str(root / "tools/frozen_entry.py")],
    pathex=[str(root), str(root / "tools")],
    binaries=binaries, datas=datas,
    hiddenimports=["clr", "sounddevice", "_cffi_backend"],
    hookspath=[], runtime_hooks=[],
    excludes=["tkinter", "PyQt5", "PySide2", "PySide6", "pytest", "IPython", "matplotlib"],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, [], exclude_binaries=True,
    name="ADS807Host", debug=False, strip=False, upx=False, console=False,
    icon=str(root / "ads807/assets/receiver.ico"),
    disable_windowed_traceback=False,
)
coll = COLLECT(exe, a.binaries, a.datas, strip=False, upx=False, name="ADS807Host")
