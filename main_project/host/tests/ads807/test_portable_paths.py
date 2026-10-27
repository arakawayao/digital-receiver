from pathlib import Path
import runpy
import sys

import pytest

from ads807 import build_usb_pump, transport


def test_frozen_capture_root_is_executable_directory(monkeypatch, tmp_path):
    executable = tmp_path / "portable/ADS807Host.exe"
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(sys, "executable", str(executable))
    from ads807 import paths
    namespace = runpy.run_path(str(Path(paths.__file__)))
    assert namespace["HOST_ROOT"] == executable.parent
    assert namespace["RESOURCE_ROOT"] == Path(paths.__file__).resolve().parents[1]
    assert namespace["HOST_ROOT"] != namespace["RESOURCE_ROOT"]


def test_bundled_usb_dll_and_explicit_override(monkeypatch, tmp_path):
    monkeypatch.setattr(transport, "RESOURCE_ROOT", tmp_path)
    sdk = tmp_path / "usb/CyUSB.dll"
    sdk.parent.mkdir()
    sdk.write_bytes(b"bundled SDK")
    assert transport.find_cyusb_dll() == sdk
    custom = tmp_path / "custom/CyUSB.dll"
    custom.parent.mkdir()
    custom.write_bytes(b"custom SDK")
    assert transport.find_cyusb_dll(custom) == custom
    with pytest.raises(RuntimeError, match="不存在"):
        transport.find_cyusb_dll(tmp_path / "missing.dll")


def test_frozen_usb_pump_uses_bundled_evidence(monkeypatch, tmp_path):
    sdk = tmp_path / "CyUSB.dll"
    sdk.write_bytes(b"test SDK")
    monkeypatch.setattr(sys, "frozen", True, raising=False)
    monkeypatch.setattr(build_usb_pump, "RESOURCE_ROOT", tmp_path)
    _, library, expected = build_usb_pump.build_inputs(sdk)
    assert library.parent == tmp_path / "managed"
    assert set(expected) == {"source_sha256", "sdk_sha256"}
