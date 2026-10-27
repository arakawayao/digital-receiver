"""Visible, sequential EP4CE6 ROM replay tests using the production Qt receiver."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from PyQt6.QtCore import QObject, QThread, QTimer, pyqtSignal, pyqtSlot
from PyQt6.QtWidgets import QApplication

from .gui import Window, wire
from .preview import Preview
from .runtime import Controller
from .sources import SourceConfig
from .tuning import MODE_NAMES

from .paths import HOST_ROOT

PROJECT = HOST_ROOT
OUTPUT = PROJECT / ".harness/tri_board_test"


def check_usb(startup_path=None):
    from .legacy.receiver_v2.usb_transport import open_transport, TransferTimeout
    device = open_transport(0x04B4, 0x1004, "cyusb")
    startup = bytearray()
    try:
        description = device.describe()
        if startup_path is not None:
            while len(startup) < 65536:
                try:
                    data = device.read(0x82, 32768, timeout=100)
                except TransferTimeout:
                    break
                if not data:
                    break
                startup.extend(data)
            else:
                raise BufferError("Startup IN FIFO did not become idle within 64 KiB")
            startup_path.write_bytes(startup)
        return {"ok": True, "usb": description, "startup_bytes": len(startup)}
    finally:
        device.close()


class ProgramJob(QThread):
    completed = pyqtSignal(object)

    def __init__(self, case):
        super().__init__()
        self.case = case

    def run(self):
        try:
            # A missing data device ends the matrix. Never retry or reset it here.
            self.usb_action()
            sof = Path(self.case["sof"])
            if hashlib.sha256(sof.read_bytes()).hexdigest() != self.case["sha256"]:
                raise ValueError("SOF hash mismatch")
            result = subprocess.run([
                "D:/intelFPGA/18.1/quartus/bin64/quartus_pgm.exe",
                "-c", "USB-Blaster [USB-0]", "-m", "JTAG", "-o", "p;" + str(sof) + "@1"],
                capture_output=True, text=True, errors="replace", timeout=60)
            (OUTPUT / (self.case["name"] + "_program.log")).write_text(result.stdout + result.stderr, encoding="utf-8")
            if result.returncode or "Configuration succeeded" not in result.stdout:
                raise RuntimeError("FPGA download failed; see programming log")
            # Run preflight in a separate process: the GUI's Cypress device list
            # is created and owned only by its acquisition worker.
            self.completed.emit(self.usb_action(OUTPUT / (self.case["name"] + "_startup.bin")))
        except Exception as error:
            self.completed.emit({"ok": False, "error": str(error)})

    def usb_action(self, startup_path=None):
        arguments = [sys.executable, "-B", "-m", "ads807.board_test", "--usb-check"]
        if startup_path is not None:
            arguments.extend(["--startup-output", str(startup_path)])
        result = subprocess.run(arguments, cwd=PROJECT, capture_output=True, text=True, errors="replace", timeout=20)
        if result.returncode:
            raise RuntimeError(result.stdout.strip() or result.stderr[-1500:])
        return json.loads(result.stdout)


class Matrix(QObject):
    start_requested = pyqtSignal(object)
    stop_requested = pyqtSignal()
    log = pyqtSignal(str)
    state = pyqtSignal(str)

    def __init__(self, window, controller, seconds, names=None, managed_pump=False):
        super().__init__(window)
        self.window, self.controller, self.seconds = window, controller, seconds
        self.start_requested.connect(controller.start)
        self.stop_requested.connect(controller.stop)
        self.log.connect(window.append_log)
        self.state.connect(window.set_state)
        self.cases = None
        self.names = set(names or ())
        self.managed_pump = managed_pump
        self.host_sources = {name: hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
                             for name in ("board_test.py", "runtime.py", "sources.py", "transport.py",
                                          "dsp.py", "tuning.py", "UsbReceivePump.cs", "preview.py")}
        self.position = 0
        self.phase = "build"
        self.job = None
        self.results = []
        self.current = None
        self.stable_since = None
        self.initial_samples = 0
        self.checks = 0
        self.next_check = 0
        self.connect_deadline = 0
        self.pending = None
        self.startup_bytes = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.tick)
        self.timer.start(200)
        self.window.stop_requested.connect(self.abort)
        self.window.source_badge.setText("实板 ROM 回放 · 等待 EP4CE6 配置构建")
        self.window.start_action.setEnabled(False)
        self.state.emit("准备实板测试")

    def save(self, status):
        value = dict(status=status, updated_local=datetime.now().astimezone().isoformat(),
                     seconds_per_case=self.seconds, completed=self.results,
                     selected_cases=sorted(self.names),
                     python_switch_interval_ms=sys.getswitchinterval()*1000,
                     managed_usb_pump=self.managed_pump,
                     host_source_sha256=self.host_sources,
                     numeric_thread_environment={key: os.environ.get(key) for key in
                                                 ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")},
                     current=self.current, phase=self.phase,
                     scope="FPGA ROM (TRI1) / USB preloaded RAM (RPL1) ADC12 -> real DSP -> real FX2 USB -> production GUI; no physical ADC/audio")
        temporary = OUTPUT / "result.tmp"
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
        temporary.replace(OUTPUT / "result.json")

    @pyqtSlot()
    def abort(self):
        if self.phase not in ("done", "failed"):
            self.phase = "failed"
            self.save("STOPPED")
            self.log.emit("用户停止测试矩阵")

    def fail(self, reason):
        self.log.emit("实板测试停止：" + reason)
        self.pending = dict(name=self.current["name"] if self.current else "preparation", status="FAIL", reason=reason)
        if self.controller.processor is not None:
            self.pending["stats"] = self.controller.processor.stats()
            self.pending["measurement"] = self.controller.processor.result.to_dict()
            if self.current is not None:
                processor = self.controller.processor
                with processor.lock:
                    recent = b"".join(processor.raw)
                (OUTPUT / (self.current["name"] + "_failed_stream.bin")).write_bytes(recent)
        if self.current is not None:
            self.window.grab().save(str(OUTPUT / (self.current["name"] + "_failed.png")))
        self.stop_requested.emit()
        self.phase = "stopping_fail"

    @pyqtSlot(object)
    def programmed(self, result):
        if self.phase != "programming":
            return
        if not result["ok"]:
            self.fail(result["error"] + "；若数据 USB 未识别，请重新上电后通知测试人员")
            return
        case = self.current
        self.startup_bytes = result["startup_bytes"]
        self.window.tuning_mode.setCurrentIndex(case["mode_id"])
        self.window.manual_rf.setValue(case["actual_rf_hz"] / 1e6)
        self.window.source_badge.setText(f"实板回放→USB · {MODE_NAMES[case['mode_id']]} · {case['kind'].upper()} · {case['carrier_amplitude_codes']} 码")
        self.log.emit(f"下载完成，启动残留 {self.startup_bytes} 字节已单独保存；开始 " + case["name"])
        self.start_requested.emit(SourceConfig(mode="USB", tuning_mode=case["mode_id"], rf_hz=round(case["actual_rf_hz"]),
                                              usb_protocol=case.get("usb_protocol", "TRI1"), replay_kind=case["kind"],
                                              usb_managed_pump=self.managed_pump,
                                              replay_amplitude=case["carrier_amplitude_codes"]))
        self.window.start_action.setEnabled(False)
        self.connect_deadline = time.monotonic() + 20
        self.stable_since = None
        self.checks = 0
        self.next_check = 0
        self.phase = "running"

    def finish_case(self, stats):
        elapsed = time.monotonic() - self.stable_since
        rate = (self.controller.processor.processed - self.initial_samples) / elapsed
        self.pending = dict(name=self.current["name"], status="PASS" if rate >= 490000 and self.checks else "FAIL",
                            elapsed_seconds=elapsed, validated_iq_rate_hz=rate, measurement_checks=self.checks,
                            startup_discarded_bytes=self.startup_bytes,
                            measurement=self.controller.processor.result.to_dict(), stats=stats)
        self.window.grab().save(str(OUTPUT / (self.current["name"] + ".png")))
        self.stop_requested.emit()
        self.phase = "stopping"

    @pyqtSlot()
    def tick(self):
        if self.phase in ("done", "failed", "programming"):
            return
        if self.phase == "build":
            ready = OUTPUT / "ready.json"
            if not ready.is_file():
                return
            manifest = json.loads(ready.read_text(encoding="utf-8"))
            if manifest["status"] != "PASS":
                self.fail(manifest.get("reason", "Build/simulation not passed"))
                return
            self.cases = manifest["cases"]
            if self.names:
                missing = self.names - {case["name"] for case in self.cases}
                if missing:
                    self.fail("未知测试组：" + ", ".join(sorted(missing)))
                    return
                self.cases = [case for case in self.cases if case["name"] in self.names]
            self.phase = "next"
        if self.phase == "next":
            if self.position == len(self.cases):
                self.phase = "done"
                self.save("PASS" if all(r["status"] == "PASS" for r in self.results) else "FAIL")
                self.state.emit("测试完成")
                self.log.emit("测试矩阵已完成；页面保留最后一轮结果")
                return
            self.current = self.cases[self.position]
            self.phase = "programming"
            self.state.emit("下载 " + self.current["name"])
            self.log.emit(f"第 {self.position+1}/{len(self.cases)} 轮：{self.current['name']}")
            self.job = ProgramJob(self.current)
            self.job.completed.connect(self.programmed)
            self.job.start()
            self.save("RUNNING")
            return
        if self.phase.startswith("stopping"):
            if self.controller.busy():
                return
            self.results.append(self.pending)
            cleanup = {name: worker.error for name, worker in
                       (("source", self.controller.source), ("processing", self.controller.processor))
                       if worker is not None and worker.error}
            if cleanup:
                self.pending.update(status="FAIL", cleanup_error=cleanup)
            failed = self.phase == "stopping_fail" or self.pending["status"] == "FAIL"
            self.log.emit(self.pending["name"] + ": " + self.pending["status"])
            self.pending = None
            self.position += 1
            self.phase = "failed" if failed else "next"
            self.save("FAIL" if failed else "RUNNING")
            return
        if self.phase != "running" or self.controller.processor is None:
            return
        processor = self.controller.processor
        stats = processor.stats()
        error = stats["source_error"] or stats["processing_error"]
        timing = stats.get("usb_timing") or {}
        error = error or timing.get("managed_error")
        if timing.get("managed_queue_dropped_bytes"):
            self.fail(".NET USB 接收队列溢出：" + str(timing["managed_queue_dropped_bytes"]))
            return
        if error:
            self.fail(error)
            return
        bad = ("crc_errors", "header_errors", "discarded_bytes", "continuity_gaps", "missing_samples",
               "fpga_dropped", "queue_dropped_bytes", "clipped_frames", "transport_gaps")
        if any(stats[key] for key in bad):
            self.fail("数据完整性失败：" + str({key: stats[key] for key in bad if stats[key]}))
            return
        now = time.monotonic()
        result = processor.result
        expected = self.current["kind"].upper()
        if self.stable_since is None:
            if result.kind != expected:
                if now > self.connect_deadline:
                    self.fail("20 秒内未得到预期识别：" + str(result.to_dict()))
                return
            self.stable_since = now
            self.initial_samples = processor.processed
            self.next_check = now
        if stats["last_valid_age_s"] is None or stats["last_valid_age_s"] > 1:
            self.fail("有效 I/Q 断流超过 1 秒")
            return
        if now >= self.next_check:
            reason = ""
            if result.kind != expected:
                reason = "识别发生变化：" + result.kind
            elif abs(result.carrier_hz - self.current["actual_rf_hz"]) > 12000:
                reason = "载频误差超过 12 kHz"
            elif expected == "AM" and abs(result.am_depth - .5) > .05:
                reason = "AM 调制度误差超过 0.05"
            elif expected == "FM" and abs(result.fm_deviation_hz - 25000) > 2500:
                reason = "FM 频偏误差超过 2.5 kHz"
            if reason:
                self.fail(reason)
                return
            self.checks += 1
            self.next_check = now + 1
            self.save("RUNNING")
        if now - self.stable_since >= self.seconds:
            self.finish_case(stats)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=30)
    parser.add_argument("--offscreen", action="store_true")
    parser.add_argument("--usb-check", action="store_true")
    parser.add_argument("--startup-output", type=Path)
    parser.add_argument("--case", action="append", help="Run only named cases; repeat to select several")
    parser.add_argument("--switch-interval-ms", type=float, help="Diagnostic Python thread switch interval")
    parser.add_argument("--managed-pump", action="store_true", help="Diagnostic .NET receive thread")
    parser.add_argument("--profile-processing", type=Path, help="Save processing worker cProfile evidence")
    args = parser.parse_args()
    if args.usb_check:
        try:
            print(json.dumps(check_usb(args.startup_output)), flush=True)
            return 0
        except Exception as error:
            print(json.dumps({"ok": False, "error": str(error)}), flush=True)
            return 1
    if args.seconds < 5:
        parser.error("--seconds must be >=5")
    if args.switch_interval_ms is not None:
        if not .1 <= args.switch_interval_ms <= 50:
            parser.error("--switch-interval-ms must be 0.1..50")
        sys.setswitchinterval(args.switch_interval_ms/1000)
    if args.offscreen:
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    if args.profile_processing:
        os.environ["ADS807_PROCESSING_PROFILE"] = str(args.profile_processing.resolve())
    app = QApplication(sys.argv[:1])
    from .qt_support import load_offscreen_fonts
    load_offscreen_fonts()
    app.setStyle("Fusion")
    app.setStyleSheet(Path(__file__).with_name("theme.qss").read_text(encoding="utf-8"))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    if (OUTPUT / "result.json").is_file():
        archive = OUTPUT / "attempts" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        archive.mkdir(parents=True)
        for path in OUTPUT.iterdir():
            if path.is_file() and path.suffix in (".json", ".png", ".log", ".bin", ".prof"):
                shutil.copyfile(path, archive / path.name)
    controller = Controller()
    window = Window()
    wire(window, controller)
    matrix = Matrix(window, controller, args.seconds, args.case, args.managed_pump)
    window.show()
    window.reset_view()
    preview = Preview(window)
    (OUTPUT / "preview.json").write_text(json.dumps({"url": f"http://127.0.0.1:{preview.port}"}), encoding="utf-8")
    print(f"PREVIEW_URL=http://127.0.0.1:{preview.port}", flush=True)
    result = app.exec()
    matrix.timer.stop()
    if matrix.job is not None:
        matrix.job.wait()
    controller.shutdown()
    preview.close()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
