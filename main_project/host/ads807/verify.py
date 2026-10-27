"""Local reproducible verification; no USB access or FPGA programming."""
import argparse
import json
import os
from pathlib import Path
import time

import numpy as np

from .paths import ARTIFACT_ROOT


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ARTIFACT_ROOT / "ads807_host/verification")
    audio_choice = parser.add_mutually_exclusive_group()
    audio_choice.add_argument("--audio-device", type=int, help="Optional physical output device index")
    audio_choice.add_argument("--audio-default", action="store_true", help="Test the application's default output selection")
    parser.add_argument("--audio-seconds", type=float, default=1.2)
    parser.add_argument("--silent-audio", action="store_true", help="Feed the real device with zero volume")
    args = parser.parse_args(argv)
    if not 1 <= args.audio_seconds <= 3600:
        parser.error("--audio-seconds must be 1..3600")
    os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PyQt6.QtWidgets import QApplication
    from .gui import Window, wire
    from .runtime import Controller
    from .qt_support import load_offscreen_fonts
    from .records import save_capture
    from .protocol import IQ_RATE
    from .sources import SourceConfig

    args.output.mkdir(parents=True, exist_ok=True)
    app = QApplication([])
    load_offscreen_fonts()
    app.setStyle("Fusion")
    app.setStyleSheet(Path(__file__).with_name("theme.qss").read_text(encoding="utf-8"))
    window = Window(args.output/"captures")
    assert not window.windowIcon().isNull()
    assert not window.windowIcon().pixmap(16, 16).isNull()
    controller = Controller()
    wire(window, controller)
    window.show()
    window.reset_view()
    report = {"status": "PASS", "usb_tested": False, "physical_audio_tested": False, "scenarios": []}

    def wait_for(condition, timeout=5):
        deadline = time.monotonic()+timeout
        while not condition():
            app.processEvents()
            time.sleep(.005)
            if time.monotonic() > deadline:
                raise AssertionError("Verification timeout")

    try:
        for mode in ("AM", "FM", "无信号", "噪声"):
            window.source.setCurrentText("合成 " + mode)
            window.request_start()
            expected = {"无信号": "无有效信号", "噪声": "未知"}.get(mode, mode)
            wait_for(lambda: window.kind_label.text() == expected and controller.processor.processed > 80_000, 8)
            start = time.monotonic()
            wait_for(lambda: time.monotonic()-start >= .5)
            capture = controller.processor.capture()
            assert capture["measurement"]["kind"] == expected
            stats = capture["stats"]
            assert stats["crc_errors"] == stats["continuity_gaps"] == stats["queue_dropped_bytes"] == 0
            assert np.all(np.diff(capture["indices"]) == 1)
            report["scenarios"].append({"source": mode, "measurement": capture["measurement"], "stats": stats})
            if mode in ("AM", "FM"):
                path = save_capture(args.output/"captures", capture)
                report["scenarios"][-1]["capture"] = str(path.resolve())
                for tab, name in enumerate(("demod", "fft", "iq")):
                    window.tabs.setCurrentIndex(tab)
                    app.processEvents()
                    assert window.grab().save(str(args.output/f"{mode.lower()}_{name}.png"))
                if mode == "FM":
                    window.theme_actions["light"].trigger()
                    for tab, name in enumerate(("demod", "fft", "iq")):
                        window.tabs.setCurrentIndex(tab)
                        app.processEvents()
                        assert window.grab().save(str(args.output/f"fm_light_{name}.png"))
                    window.resize(1100, 760)
                    app.processEvents()
                    assert window.grab().save(str(args.output/"fm_light_compact.png"))
                    window.resize(1440, 940)
                    window.theme_actions["dark"].trigger()
                    report["themes"] = ["dark", "light"]
                window.resize(1100, 760)
                app.processEvents()
                window.grab().save(str(args.output/f"{mode.lower()}_compact.png"))
                window.resize(1440, 940)
            window.stop_requested.emit()
            wait_for(lambda: controller.state == "已停止")
        window.source.setCurrentText("合成 噪声")
        window.demodulation_mode.setCurrentIndex(window.demodulation_mode.findData("FM"))
        window.request_start()
        wait_for(lambda: window.kind_label.text() == "未知" and
                 controller.processor.demodulation["forced"] and controller.processor.processed > 80_000, 8)
        forced = controller.processor.capture()
        assert forced["measurement"]["kind"] == "未知"
        assert forced["demodulation"]["kind"] == "FM"
        assert np.std(forced["audio"][960:]) > .001
        report["scenarios"].append({"source": "噪声 / 强制 FM", "demodulation": forced["demodulation"],
                                    "measurement": forced["measurement"], "stats": forced["stats"]})
        window.tabs.setCurrentIndex(0)
        for width, height, name in ((1440, 940, "forced_fm_unknown"), (1100, 760, "forced_fm_compact")):
            window.resize(width, height)
            app.processEvents()
            assert window.grab().save(str(args.output/f"{name}.png"))
        window.stop_requested.emit()
        wait_for(lambda: controller.state == "已停止")
        window.demodulation_mode.setCurrentIndex(0)
        if args.audio_device is not None or args.audio_default:
            output = controller.audio
            output.volume = 0 if args.silent_audio else .06
            try:
                controller.start(SourceConfig("合成 AM"))
                wait_for(lambda: controller.processor.result.kind == "AM")
                controller.set_audio(True, args.audio_device)
                wait_for(lambda: output.enabled or output.error)
                if output.error:
                    raise RuntimeError(output.error)
                start = time.monotonic()
                wait_for(lambda: time.monotonic()-start >= args.audio_seconds, args.audio_seconds+5)
                report["physical_audio_tested"] = True
                report["audio"] = {"device": args.audio_device, "sample_rate_hz": 48000,
                                   "device_errors": output.device_errors,
                                   "underruns": output.underruns, "overruns": output.overruns,
                                   "startup_silence_frames": output.startup_silence_frames,
                                   "note": "Synthetic FCR1 -> decoder -> AM demodulator -> PortAudio completed; perceptual quality not assessed."}
                report["audio"]["duration_s"] = time.monotonic()-start
                report["audio"]["silent"] = args.silent_audio
                report["audio"]["diagnostics"] = output.snapshot()
                report["audio"]["pipeline_stats"] = controller.processor.stats()
                assert output.device_errors == 0
            finally:
                output.stop()
                controller.stop()
                wait_for(lambda: controller.state == "已停止")
    except Exception as error:
        report["status"] = "FAIL"
        report["error"] = repr(error)
        report["failure_stats"] = controller.processor.stats() if controller.processor else {}
        raise
    finally:
        controller.shutdown()
        window.allow_close = True
        window.close()
        app.processEvents()
        (args.output/"result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    print(json.dumps({"status": report["status"], "scenarios": len(report["scenarios"]),
                      "physical_audio_tested": report["physical_audio_tested"],
                      "report": str((args.output/"result.json").resolve())}))


if __name__ == "__main__":
    main()
