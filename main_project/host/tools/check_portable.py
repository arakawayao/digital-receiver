"""Verify the frozen GUI and native libraries without opening USB or speakers."""
import hashlib
import json
from pathlib import Path
import sys
import traceback


def run(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {"status": "FAIL", "frozen": bool(getattr(sys, "frozen", False)),
              "executable": sys.executable, "usb_tested": False, "physical_audio_tested": False}
    try:
        import clr
        import sounddevice as sd
        from ads807.build_usb_pump import build_inputs
        from ads807.paths import HOST_ROOT, RESOURCE_ROOT
        from ads807.transport import find_cyusb_dll

        sdk = find_cyusb_dll()
        _, assembly, expected = build_inputs(sdk)
        evidence = json.loads(assembly.with_suffix(".json").read_text(encoding="utf-8"))
        assert all(evidence.get(key) == value for key, value in expected.items())
        assert evidence["assembly_sha256"] == hashlib.sha256(assembly.read_bytes()).hexdigest()
        clr.AddReference(str(sdk))
        clr.AddReference(str(assembly))
        from CyUSB import USBDeviceList
        from Ads807Transport import UsbReceivePump
        from System import Array, Byte

        assert len(Array[Byte]([1, 2, 3])) == 3
        report.update(host_root=str(HOST_ROOT), resource_root=str(RESOURCE_ROOT),
                      cyusb=str(sdk), usb_pump=str(assembly),
                      managed_types=[str(USBDeviceList), str(UsbReceivePump)],
                      portaudio=sd.get_portaudio_version(), host_apis=len(sd.query_hostapis()),
                      sys_path=sys.path)
        probe = HOST_ROOT / "captures" / ".write_probe"
        probe.parent.mkdir(parents=True, exist_ok=True)
        probe.write_text("portable capture directory", encoding="ascii")
        probe.unlink()
        from ads807.verify import main as verify
        verify(["--output", str(output / "gui")])
        gui_report = json.loads((output / "gui/result.json").read_text(encoding="utf-8"))
        assert gui_report["status"] == "PASS" and gui_report["themes"] == ["dark", "light"]
        report.update(status="PASS", gui_report=str(output / "gui/result.json"))
        return 0
    except Exception:
        report["error"] = traceback.format_exc()
        return 1
    finally:
        (output / "portable_result.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
