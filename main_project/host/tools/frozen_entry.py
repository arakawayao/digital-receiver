"""Windowed executable entry point with local diagnostics."""
import ctypes
import sys
import traceback

from ads807.paths import HOST_ROOT


def main():
    try:
        logs = HOST_ROOT / "logs"
        logs.mkdir(parents=True, exist_ok=True)
        stream = (logs / "application.log").open("a", encoding="utf-8", buffering=1)
        sys.stdout = sys.stderr = stream
        if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
            from check_portable import run
            if len(sys.argv) != 3:
                raise ValueError("Usage: ADS807Host.exe --self-test OUTPUT_DIRECTORY")
            return run(sys.argv[2])
        from ads807.__main__ import main as application_main
        return application_main()
    except Exception:
        details = traceback.format_exc()
        if sys.stderr is not None:
            sys.stderr.write(details)
        # Automated verification reports failures through its exit code and JSON.
        if "--self-test" not in sys.argv:
            ctypes.windll.user32.MessageBoxW(
                None, "启动失败，请查看软件目录 logs/application.log。\n\n" + details[-1500:],
                "ADS807", 0x10)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
