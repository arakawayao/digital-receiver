"""Build the optional .NET receive worker against the installed Cypress SDK."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from .paths import HOST_ROOT, RESOURCE_ROOT


def build_inputs(sdk):
    output = (RESOURCE_ROOT / "managed" if getattr(sys, "frozen", False)
              else HOST_ROOT / ".harness/ads807_host/managed")
    source = Path(__file__).with_name("UsbReceivePump.cs")
    source_digest = hashlib.sha256(source.read_bytes()).hexdigest()
    sdk_digest = hashlib.sha256(sdk.read_bytes()).hexdigest()
    identity = hashlib.sha256((source_digest+sdk_digest).encode("ascii")).hexdigest()[:16]
    assembly = output / ("UsbReceivePump_" + identity + ".dll")
    return source, assembly, dict(source_sha256=source_digest, sdk_sha256=sdk_digest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-dll", type=Path, default=Path("C:/Program Files (x86)/Cypress/EZ-USB FX3 SDK/1.3/library/c_sharp/lib/CyUSB.dll"))
    args = parser.parse_args()
    source, assembly, evidence = build_inputs(args.sdk_dll)
    output = assembly.parent
    output.mkdir(parents=True, exist_ok=True)
    compiler = Path("C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe")
    process = subprocess.run([str(compiler), "/nologo", "/target:library", "/optimize+",
                              "/reference:" + str(args.sdk_dll), "/out:" + str(assembly), str(source)],
                             capture_output=True, text=True, errors="replace", timeout=60)
    (output / "compile.log").write_text(process.stdout+process.stderr, encoding="utf-8")
    print(process.stdout+process.stderr)
    process.check_returncode()
    evidence.update(assembly_sha256=hashlib.sha256(assembly.read_bytes()).hexdigest(), compiler=str(compiler))
    assembly.with_suffix(".json").write_text(json.dumps(evidence, indent=2), encoding="utf-8")
    print(assembly)


if __name__ == "__main__":
    main()
