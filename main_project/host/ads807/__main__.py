import argparse
import os
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description="ADS807 PyQt6 streaming receiver")
    parser.add_argument("--demo", choices=("AM", "FM", "无信号", "噪声"))
    parser.add_argument("--preview", action="store_true", help="Mirror the actual Qt window on loopback HTTP")
    parser.add_argument("--preview-port", type=int, default=8767)
    parser.add_argument("--offscreen", action="store_true")
    parser.add_argument("--screenshot", type=Path)
    parser.add_argument("--quit-after", type=float)
    parser.add_argument("--health-report", type=Path, help="Write final streaming counters on exit")
    args = parser.parse_args()
    if args.offscreen:
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PyQt6.QtCore import QTimer
    from PyQt6.QtWidgets import QApplication
    from .gui import Window, wire
    from .runtime import Controller

    if os.name == "nt":
        import ctypes
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID("ADS807.Receiver.Host")
    app = QApplication(sys.argv[:1])
    from PyQt6.QtGui import QIcon
    app.setWindowIcon(QIcon(str(Path(__file__).with_name("assets") / "receiver.ico")))
    from .qt_support import load_offscreen_fonts
    load_offscreen_fonts()
    app.setStyle("Fusion")
    app.setStyleSheet(Path(__file__).with_name("theme.qss").read_text(encoding="utf-8"))
    controller = Controller()
    window = Window()
    wire(window, controller)
    window.show()
    window.reset_view()
    preview = None
    if args.preview:
        from .preview import Preview
        preview = Preview(window, args.preview_port)
        print(f"PREVIEW_URL=http://127.0.0.1:{preview.port}", flush=True)
    if args.demo:
        window.source.setCurrentText("合成 " + args.demo)
        QTimer.singleShot(200, window.request_start)
    if args.screenshot:
        def screenshot():
            args.screenshot.parent.mkdir(parents=True, exist_ok=True)
            window.grab().save(str(args.screenshot))
        QTimer.singleShot(2500, screenshot)
    if args.quit_after:
        QTimer.singleShot(int(args.quit_after*1000), window.close)
    result = app.exec()
    controller.shutdown()
    if args.health_report and controller.processor:
        args.health_report.parent.mkdir(parents=True, exist_ok=True)
        args.health_report.write_text(json.dumps(controller.processor.stats(), ensure_ascii=False, indent=2), encoding="utf-8")
    if preview:
        preview.close()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
