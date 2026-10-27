"""FPGA auto/manual controller; no host carrier search or automatic retuning."""
from collections import deque
import queue
import secrets
import struct
import threading
import time

import numpy as np

from .interfaces import protocol as tri
from .interfaces.quality import assess_iq


MODE_NAMES = {1: "FPGA 自动估频", 2: "手动载频"}


class TuningSession(threading.Thread):
    def __init__(self, source):
        super().__init__(name="ads807-tuning", daemon=True)
        self.source = source
        self.stop_event = threading.Event()
        self.events = queue.Queue(maxsize=128)
        self.lock = threading.Lock()
        self.blocks = deque(maxlen=96)
        self.header = None
        self.last_iq = 0.0
        self.sequence = secrets.randbits(32)
        self.command_count = 0
        self.error = ""
        self.status = {"message": "等待 USB 连接", "mode": source.config.tuning_mode,
                       "tuned_rf": 0, "flags": 0, "epoch": 0, "config_id": 0,
                       "estimated_rf": 0, "commands": 0}

    def view(self):
        with self.lock:
            return dict(self.status, error=self.error)

    def update(self, **values):
        with self.lock:
            self.status.update(values)

    def offer(self, frame):
        if isinstance(frame, tri.Frame):
            try:
                self.events.put_nowait(frame)
            except queue.Full:
                self.error = "调谐事件队列溢出"
            return
        if frame.protocol != "TRI1":
            self.error = "USB 需要 EP4CE6 两模式 TRI1 固件，收到旧 FCR1"
            return
        with self.lock:
            epoch = self.status["epoch"]
            config = self.status["config_id"]
            if ((frame.epoch != epoch and ((frame.epoch-epoch) & 0xffffffff) >= 0x80000000)
                    or (frame.epoch == epoch and frame.config_id != config
                        and ((frame.config_id-config) & 0xffffffff) >= 0x80000000)):
                return
            key = (frame.epoch, frame.config_id)
            if (self.header is None or key != (self.header.epoch, self.header.config_id)
                    or frame.transport_gap or frame.index != ((self.header.index+self.header.count) & 0xffffffff)):
                self.blocks.clear()
            self.header = frame
            self.last_iq = time.monotonic()
            self.status.update(mode=frame.flags & 3, tuned_rf=frame.rf_hz, flags=frame.flags,
                               epoch=frame.epoch, config_id=frame.config_id,
                               estimated_rf=frame.estimated_rf)
            if not frame.transient and not frame.clipped:
                self.blocks.append(frame.samples)
            else:
                self.blocks.clear()

    def receive(self, timeout):
        frame = self.events.get(timeout=timeout)
        if frame.kind == 2:
            raise RuntimeError("两模式固件不应上传 RAW 快照，请核对固件版本")
        return frame

    def request(self, opcode, argument=0, rf_hz=0, stopping=False):
        self.sequence = (self.sequence+1) & 0xffffffff
        identifier = self.sequence
        packet = tri.command(identifier, opcode, argument, rf_hz)
        self.source.send(packet)
        deadline = time.monotonic()+2
        while time.monotonic() < deadline:
            if self.error and not stopping:
                raise RuntimeError(self.error)
            if self.source.error or self.source.ended:
                raise RuntimeError(self.source.error or "USB 已关闭")
            if self.stop_event.is_set() and not stopping:
                raise InterruptedError()
            try:
                frame = self.receive(.05)
            except queue.Empty:
                continue
            if frame.kind != 3:
                continue
            ack = frame.ack()
            if ack["sequence"] != identifier:
                continue
            if ack["opcode"] != opcode:
                raise RuntimeError(f"TCM1 ACK 命令不匹配：期望 {opcode}，收到 {ack['opcode']}")
            if ack["error"] == 2:
                raise RuntimeError("TCM1 v2 被拒绝（error=2）：请核对板上 SOF 是否匹配 v2；旧 v1 固件不兼容")
            if ack["error"]:
                raise RuntimeError(f"TCM1 命令 {opcode} 被拒绝：error={ack['error']}")
            expected = {}
            if opcode == tri.MODE:
                expected["mode"] = argument
            elif opcode == tri.TUNE:
                expected.update(mode=tri.MANUAL, tuned_rf=rf_hz,
                                phase_step=struct.unpack_from("<I", packet, 16)[0])
            elif opcode == tri.HOLD:
                expected["hold_ms"] = argument
            mismatches = [f"{key}: 期望 {value}，收到 {ack[key]}"
                          for key, value in expected.items() if ack[key] != value]
            if opcode in (tri.TUNE, tri.STOP) and bool(ack["flags"] & 256) != (opcode == tri.TUNE):
                mismatches.append("调谐使能状态不符")
            if mismatches:
                raise RuntimeError(f"TCM1 命令 {opcode} 回读不一致：" + "；".join(mismatches))
            self.command_count += 1
            self.update(**{key: ack[key] for key in ("mode", "tuned_rf", "epoch", "config_id", "flags", "estimated_rf")},
                        commands=self.command_count)
            return ack
        raise TimeoutError(f"TCM1 命令 {opcode} 等待 ACK 超时；未盲目重发")

    def monitor(self):
        mode = self.source.config.tuning_mode
        next_query = 0.0
        while not self.stop_event.wait(.1):
            if self.error or self.source.error or self.source.ended:
                raise RuntimeError(self.error or self.source.error or "USB 已关闭")
            if mode == tri.FPGA_AUTO:
                # Without a lock the FPGA emits no IQ. QUERY still returns
                # current state; it neither retunes nor restarts the DSP.
                if time.monotonic() >= next_query:
                    self.request(tri.QUERY)
                    next_query = time.monotonic()+.5
                flags = self.view()["flags"]
                self.update(message=("FPGA 自主估频 / 保持" if flags & 256 else
                                     "等待 FPGA 估频锁定，尚未启动 I/Q"))
                continue
            with self.lock:
                header = self.header
                fresh = time.monotonic()-self.last_iq < .25
                blocks = list(self.blocks)
                current = (self.status["epoch"], self.status["config_id"])
            matching = header is not None and (header.epoch, header.config_id) == current
            if blocks and matching:
                samples = np.concatenate(blocks)[-4096:]
                values = samples[:, 0].astype(float) + 1j*samples[:, 1]
            else:
                values = np.empty(0)
            quality = assess_iq(values)
            good = quality["confident"] and fresh and matching
            measured = round(header.rf_hz+quality["offset_hz"]) if good else 0
            good = good and 87_000_000 <= measured <= 108_750_000
            self.request(tri.QUALITY, int(good), measured if good else 0)
            if good:
                self.update(message="手动调谐 / 信号可信")
            else:
                self.update(message="低可信度，保持当前调谐")

    def run(self):
        connected = False
        try:
            while not self.source.connected:
                if self.stop_event.wait(.02):
                    return
                if self.source.ended:
                    raise RuntimeError(self.source.error or "USB 连接失败")
            connected = True
            self.request(tri.QUERY)
            self.request(tri.MODE, self.source.config.tuning_mode)
            self.request(tri.HOLD, self.source.config.hold_ms)
            if self.source.config.tuning_mode == tri.MANUAL:
                self.request(tri.TUNE, rf_hz=self.source.config.rf_hz)
                self.update(message="手动调谐完成，评估 I/Q")
            elif self.source.config.tuning_mode == tri.FPGA_AUTO:
                self.update(message="等待 FPGA 估频 / 保持")
            self.monitor()
        except InterruptedError:
            pass
        except Exception as error:
            self.error = str(error)
            self.update(message="调谐控制错误")
        finally:
            if connected and not self.source.ended:
                try:
                    self.request(tri.STOP, stopping=True)
                except Exception as error:
                    self.error = self.error or str(error)
