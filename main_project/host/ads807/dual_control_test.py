"""Visible real-board TCM1 control checks for receiver_ads807_dual only."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import secrets
import struct
import subprocess
import sys
import threading
import time
import zlib

from .interfaces import protocol
from .transport import CyUSBReader, TransferTimeout

from .paths import HOST_ROOT, FIRMWARE_ROOT

PROJECT = HOST_ROOT
ENGINEERING = FIRMWARE_ROOT / "receiver_ads807_dual"


class ControlSession:
    def __init__(self, reader, log=lambda text: None, stop=None, update=lambda value: None):
        self.reader, self.log = reader, log
        self.update = update
        self.stop = stop or threading.Event()
        self.decoder = protocol.Decoder()
        self.sequence = secrets.randbits(32)
        self.last_frame = None
        self.commands = []
        self.iq_frames = 0
        self.frame_count = 0
        self.max_ack_ms = 0.0

    def request(self, opcode, argument=0, rf_hz=0, error=0, corrupt=None, cleanup=False):
        if self.stop.is_set() and not cleanup:
            raise InterruptedError("Control test stopped")
        self.sequence = (self.sequence+1) & 0xffffffff
        packet = bytearray(protocol.command(self.sequence, opcode, argument, rf_hz))
        if corrupt == "reserved":
            packet[24] = 1
            struct.pack_into("<I", packet, 508, zlib.crc32(packet[:508]))
        elif corrupt == "crc":
            packet[508] ^= 1
        start = time.perf_counter()
        self.reader.write(bytes(packet))
        matched = None
        while time.perf_counter()-start < 2:
            try:
                data = self.reader.read(size=32768, timeout=100)
            except TransferTimeout:
                continue
            for frame in self.decoder.feed(data):
                sequence = frame.words[3]
                if self.last_frame is not None and sequence != (self.last_frame+1) & 0xffffffff:
                    raise ValueError("TRI1 global sequence gap")
                self.last_frame = sequence
                self.frame_count += 1
                if frame.kind == 2:
                    raise ValueError("Dual firmware must not emit RAW snapshots")
                if frame.kind == 1:
                    self.iq_frames += 1
                    continue
                ack = frame.ack()
                if ack["sequence"] != self.sequence:
                    raise ValueError("Unexpected ACK sequence; no blind retry")
                if ack["opcode"] != opcode or ack["error"] != error:
                    raise ValueError("Unexpected ACK: " + str(ack))
                matched = ack
            if self.decoder.crc_errors or self.decoder.discarded:
                raise ValueError("Control stream CRC/discarded bytes error")
            if matched is not None:
                elapsed = (time.perf_counter()-start)*1000
                self.max_ack_ms = max(self.max_ack_ms, elapsed)
                self.commands.append(dict(ack=matched, elapsed_ms=elapsed, corruption=corrupt))
                self.log(f"ACK #{len(self.commands)} opcode={opcode} error={error} mode={matched['mode']} RF={matched['tuned_rf']} Hz {elapsed:.1f} ms")
                self.update(dict(commands=len(self.commands), frames=self.frame_count,
                                 ignored_iq_frames=self.iq_frames, max_ack_ms=self.max_ack_ms,
                                 crc_errors=self.decoder.crc_errors, discarded_bytes=self.decoder.discarded,
                                 ack=matched))
                return matched
        raise TimeoutError(f"TCM1 opcode={opcode} ACK timeout; no retry")

    def boundary_checks(self):
        self.request(protocol.STOP)
        self.request(protocol.MODE, 1)
        self.request(protocol.TUNE, rf_hz=98_000_000, error=5)
        self.request(protocol.MODE, 0, error=4)
        self.request(4, error=3)
        self.request(6, error=3)
        self.request(protocol.QUERY, corrupt="crc", error=1)
        self.request(protocol.QUERY, corrupt="reserved", error=2)
        self.request(protocol.HOLD, 0, error=4)
        self.request(protocol.HOLD, 500)
        self.request(protocol.STOP)
        self.request(protocol.MODE, 2)
        self.request(protocol.TUNE, rf_hz=87_999_999, error=4)
        for frequency in (88_000_000, 98_000_000, 108_000_000):
            ack = self.request(protocol.TUNE, rf_hz=frequency)
            phase = round((frequency-87_000_000)*2**32/protocol.RATE)
            if ack["mode"] != 2 or ack["tuned_rf"] != frequency or ack["phase_step"] != phase:
                raise ValueError("Manual tune/NCO ACK mismatch: " + str(ack))
        ack = self.request(protocol.QUALITY, 0)
        if ack["flags"] & 512:
            raise ValueError("Low-quality command left confidence asserted")
        self.request(protocol.STOP)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=60)
    parser.add_argument("--offscreen", action="store_true")
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("--seconds must be >=1")
    if args.offscreen:
        os.environ["QT_QPA_PLATFORM"] = "offscreen"
    from PyQt6.QtCore import QThread, QTimer, pyqtSignal
    from PyQt6.QtWidgets import QApplication
    from .gui import Window
    from .preview import Preview
    from .qt_support import load_offscreen_fonts

    output = PROJECT / ".harness/receiver_ads807_dual/board_control" / datetime.now().strftime("%Y%m%d_%H%M%S")
    output.mkdir(parents=True)

    class Worker(QThread):
        log = pyqtSignal(str)
        status = pyqtSignal(str)
        progress = pyqtSignal(object)

        def __init__(self):
            super().__init__()
            self.stop = threading.Event()

        def run(self):
            reader = session = None
            evidence = dict(status="RUNNING", project=str(ENGINEERING), seconds=args.seconds,
                            scope="USB control only; ADC absent; IQ ignored, no AM/FM or ADC validation")
            try:
                self.status.emit("检查数据 USB")
                reader = CyUSBReader(duplex=True)
                reader.close()
                reader = None
                sof = ENGINEERING / "receiver_ads807_dual.sof"
                evidence.update(sof=str(sof), sof_sha256=hashlib.sha256(sof.read_bytes()).hexdigest())
                evidence["sources"] = {str(path.relative_to(ENGINEERING)): hashlib.sha256(path.read_bytes()).hexdigest()
                                       for path in ENGINEERING.rglob("*") if path.is_file()
                                       and (path.parent.name in ("rtl", "ip") or path.suffix in (".qsf", ".sdc"))}
                self.status.emit("下载 receiver_ads807_dual")
                result = subprocess.run(["D:/intelFPGA/18.1/quartus/bin64/quartus_pgm.exe", "-c", "USB-Blaster [USB-0]",
                                         "-m", "JTAG", "-o", "p;"+str(sof)+"@1"],
                                        capture_output=True, text=True, errors="replace", timeout=60)
                (output / "program.log").write_text(result.stdout+result.stderr, encoding="utf-8")
                if result.returncode or "Configuration succeeded" not in result.stdout:
                    raise RuntimeError("Dual SOF programming failed")
                reader = CyUSBReader(duplex=True)
                # Retain a bounded startup drain separately from the control test.
                startup = bytearray()
                while len(startup) < 65536:
                    try:
                        startup.extend(reader.read(timeout=100))
                    except TransferTimeout:
                        break
                else:
                    raise BufferError("Startup data did not become idle within 64 KiB")
                (output / "startup.bin").write_bytes(startup)
                reader.start_pump()
                session = ControlSession(reader, self.log.emit, self.stop, self.progress.emit)
                self.status.emit("控制边界检查")
                session.boundary_checks()
                self.status.emit("持续命令往返")
                start = time.perf_counter()
                while time.perf_counter()-start < args.seconds:
                    session.request(protocol.QUERY)
                    if self.stop.wait(.1):
                        raise InterruptedError("User stopped control test")
                session.request(protocol.STOP, cleanup=True)
                evidence.update(status="PASS", elapsed_seconds=time.perf_counter()-start)
            except Exception as error:
                evidence.update(status="FAIL", reason=str(error))
                self.log.emit("测试停止："+str(error))
                # No reopen, reset, or enumeration retry after any USB failure.
            finally:
                if reader is not None:
                    try:
                        reader.close()
                    except Exception as error:
                        evidence.update(status="FAIL", close_error=str(error))
                if session is not None:
                    evidence.update(commands=session.commands, frames=session.frame_count,
                                    ignored_iq_frames=session.iq_frames, max_ack_ms=session.max_ack_ms,
                                    crc_errors=session.decoder.crc_errors, discarded_bytes=session.decoder.discarded)
                evidence["completed_local"] = datetime.now().astimezone().isoformat()
                (output / "result.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
                self.log.emit(f"{evidence['status']} · {output}")
                self.status.emit("控制测试通过" if evidence["status"] == "PASS" else "控制测试失败，已停止")

    app = QApplication(sys.argv[:1])
    load_offscreen_fonts()
    app.setStyle("Fusion")
    app.setStyleSheet(Path(__file__).with_name("theme.qss").read_text(encoding="utf-8"))
    window = Window()
    window.source_badge.setText("receiver_ads807_dual · USB 控制测试 · ADC 未接入")
    window.kind_label.setText("无有效信号")
    window.start_action.setEnabled(False)
    window.audio_on.setEnabled(False)
    for control in (window.source, window.tuning_mode, window.manual_rf):
        control.setEnabled(False)
    for label in window.integrity.values():
        label.setText("未评估")
    worker = Worker()
    worker.log.connect(window.append_log)
    worker.status.connect(window.status.setText)

    def update(value):
        window.stats = value
        window.integrity["frames"].setText(str(value["frames"]))
        window.integrity["crc"].setText(str(value["crc_errors"]))
        window.tuning_status.setText(f"控制 ACK：{value['commands']} · 最长 {value['max_ack_ms']:.1f} ms")
        ack = value["ack"]
        window.tuning_mode.setCurrentIndex(window.tuning_mode.findData(ack["mode"]))
        window.manual_rf.setValue(ack["tuned_rf"]/1e6)
        window.tuning_values.setText(f"模式：{ack['mode']}\n设定：{ack['tuned_rf']/1e6:.6f} MHz\nEpoch：{ack['epoch']}")

    worker.progress.connect(update)
    window.stop_action.setEnabled(True)
    window.stop_requested.connect(worker.stop.set)
    window.close_requested.connect(worker.stop.set)
    window.close_requested.connect(lambda: window.finish_close() if not worker.isRunning() else None)
    worker.finished.connect(lambda: window.finish_close() if window.closing else None)
    window.show()
    preview = Preview(window)
    (output / "preview.json").write_text(json.dumps(dict(url=f"http://127.0.0.1:{preview.port}")), encoding="utf-8")
    print(f"PREVIEW_URL=http://127.0.0.1:{preview.port}\nOUTPUT={output}", flush=True)
    QTimer.singleShot(500, worker.start)
    result = app.exec()
    worker.stop.set()
    worker.wait()
    preview.close()
    return result


if __name__ == "__main__":
    raise SystemExit(main())
