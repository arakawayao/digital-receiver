"""Build and verify a portable Windows x64 release from the host project."""
import argparse
from datetime import datetime
import hashlib
from importlib import metadata
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / ".harness/build_tools"))

from ads807.transport import find_cyusb_dll


def run_logged(command, log, env, cwd=ROOT, timeout=600):
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}")


def write_licenses(destination, sdk):
    destination.mkdir()
    packages = ["PyQt6", "PyQt6-Qt6", "PyQt6-sip", "pyqtgraph", "numpy", "scipy",
                "sounddevice", "cffi", "pycparser", "pythonnet", "clr_loader",
                "pyinstaller", "pyinstaller-hooks-contrib"]
    versions = {}
    for package in packages:
        distribution = metadata.distribution(package)
        versions[package] = distribution.version
        for entry in distribution.files or []:
            if any("license" in part.lower() or "copying" in part.lower()
                   or "copyright" in part.lower() for part in entry.parts):
                source = Path(distribution.locate_file(entry))
                if source.is_file():
                    target = destination / package / Path(*entry.parts)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
    for filename in ("LICENSE_PYTHON.txt", "LICENSE.txt", "LICENSE"):
        source = Path(sys.base_prefix) / filename
        if source.is_file():
            shutil.copy2(source, destination / "Python-LICENSE.txt")
            break
    sdk_license = sdk.parents[3] / "license/license.txt" if len(sdk.parents) > 3 else Path()
    if sdk_license.is_file():
        shutil.copy2(sdk_license, destination / "Cypress-SDK-license.txt")
    (destination / "versions.json").write_text(json.dumps(versions, indent=2), encoding="utf-8")
    return versions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-dll", type=Path)
    args = parser.parse_args()
    if sys.platform != "win32" or sys.maxsize <= 2**32:
        parser.error("Build requires 64-bit Python on Windows")
    sdk = find_cyusb_dll(args.sdk_dll)
    release = ROOT / ".harness/releases" / datetime.now().strftime("%Y%m%d_%H%M%S")
    release.mkdir(parents=True, exist_ok=False)
    env = os.environ.copy()
    env["ADS807_CYUSB_DLL"] = str(sdk)
    env["PYINSTALLER_CONFIG_DIR"] = str(ROOT / ".harness/pyinstaller_cache")
    build_tools = ROOT / ".harness/build_tools"
    env["PYTHONPATH"] = os.pathsep.join([str(build_tools), str(ROOT)])
    env["PATH"] = os.pathsep.join([str(Path(sys.base_prefix) / "Library/bin"),
                                   str(Path(sys.base_prefix)), env.get("PATH", "")])
    run_logged([sys.executable, "-B", "-m", "ads807.build_usb_pump", "--sdk-dll", str(sdk)],
               release / "usb_build.log", env, timeout=120)
    print(f"Building portable EXE; log: {release / 'pyinstaller.log'}", flush=True)
    run_logged([sys.executable, "-B", "-m", "PyInstaller", "--noconfirm", "--clean",
                "--distpath", str(release), "--workpath", str(release / "work"),
                str(ROOT / "tools/ADS807Host.spec")], release / "pyinstaller.log", env)
    application = release / "ADS807Host"
    shutil.copy2(ROOT / "docs/PORTABLE.md", application / "使用说明.md")
    (application / "启动 ADS807.bat").write_text(
        "@echo off\r\nstart \"ADS807\" \"%~dp0ADS807Host.exe\" %*\r\n", encoding="ascii")
    versions = write_licenses(application / "licenses", sdk)
    with zipfile.ZipFile(application / "source.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for directory in ("ads807", "tools"):
            for source in (ROOT / directory).rglob("*"):
                if source.is_file() and source.suffix in (".py", ".cs", ".qss", ".spec", ".txt", ".svg", ".ico", ".png"):
                    archive.write(source, source.relative_to(ROOT))
        for name in ("run.py", "requirements.txt", "README.md", "docs/PORTABLE.md"):
            archive.write(ROOT / name, name)
    # Verify without Conda, Python paths or the installed Cypress SDK on PATH.
    clean_env = {key: value for key, value in os.environ.items()
                 if not key.upper().startswith(("PYTHON", "CONDA", "VIRTUAL_ENV", "QT_", "PYQT"))}
    windows = Path(os.environ.get("SystemRoot", "C:/Windows"))
    clean_env["PATH"] = os.pathsep.join([str(windows / "System32"), str(windows)])
    check_dir = release / "check_working_directory"
    check_dir.mkdir()
    print("Verifying frozen GUI, AM/FM, themes, records and native libraries...", flush=True)
    run_logged([str(application / "ADS807Host.exe"), "--self-test", str(release / "verification")],
               release / "self_test.log", clean_env, cwd=check_dir, timeout=120)
    report = json.loads((release / "verification/portable_result.json").read_text(encoding="utf-8"))
    if report["status"] != "PASS" or not report["frozen"]:
        raise RuntimeError(f"Frozen application verification failed: {release / 'verification'}")
    files = {str(path.relative_to(application)): hashlib.sha256(path.read_bytes()).hexdigest()
             for path in sorted(application.rglob("*")) if path.is_file()}
    manifest = {"built_at": datetime.now().astimezone().isoformat(), "python": sys.version,
                "platform": "Windows x64", "versions": versions, "verification": report,
                "files_sha256": files, "physical_usb_tested": False, "physical_audio_tested": False}
    (application / "build_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    pending = shutil.make_archive(str(release / "ADS807Host-Windows-x64.partial"), "zip", release, "ADS807Host")
    archive = release / "ADS807Host-Windows-x64.zip"
    Path(pending).replace(archive)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    Path(str(archive) + ".sha256").write_text(f"{digest}  {archive.name}\n", encoding="ascii")
    print(json.dumps({"status": "PASS", "executable": str(application / "ADS807Host.exe"),
                       "archive": str(archive), "sha256": digest}, indent=2), flush=True)


if __name__ == "__main__":
    main()
