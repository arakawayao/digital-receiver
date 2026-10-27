"""Bounded byte ingress; synthetic sources exercise the same decoder as USB."""
from dataclasses import dataclass
from pathlib import Path
import queue
import threading
import time

import numpy as np
from PyQt6.QtCore import QThread

from .protocol import CAPACITY, IQ_RATE, encode_frame
from .transport import CyUSBReader, TransferTimeout


@dataclass
class SourceConfig:
    mode: str = "USB"
    vid: int = 0x04B4
    pid: int = 0x1004
    dll: str = ""
    path: str = ""
    tuning_mode: int = 1
    rf_hz: int = 100_000_000
    hold_ms: int = 500
    usb_protocol: str = "TRI1"
    replay_kind: str = "am"
    replay_amplitude: float = 800
    usb_managed_pump: bool = False

    def __post_init__(self):
        if self.tuning_mode not in (1, 2):
            raise ValueError("调谐模式必须为 FPGA 自动(1)或手动载频(2)")
        if not 88_000_000 <= self.rf_hz <= 108_000_000:
            raise ValueError("手动载频须为 88..108 MHz")
        if not 1 <= self.hold_ms <= 60000:
            raise ValueError("保持时间须为 1..60000 ms")
        if self.usb_protocol not in ("TRI1", "RPL1"):
            raise ValueError("未知 USB 控制协议")


class SyntheticStream:
    def __init__(self, kind="AM", seed=807):
        self.kind = kind
        self.rng = np.random.default_rng(seed)
        self.index = 0
        self.sequence = 0

    def read(self, frames=40):
        count = frames*CAPACITY
        t = (self.index + np.arange(count))/IQ_RATE
        phase = 2*np.pi*137*t
        if self.kind == "AM":
            z = .35*(1+.6*np.cos(2*np.pi*1000*t))*np.exp(1j*phase)
        elif self.kind == "FM":
            z = .4*np.exp(1j*(phase+25*np.sin(2*np.pi*1000*t)))
        elif self.kind == "无信号":
            z = np.zeros(count, dtype=complex)
        elif self.kind == "噪声":
            z = .08*(self.rng.normal(size=count)+1j*self.rng.normal(size=count))
        else:
            raise ValueError("Unknown synthetic source")
        if self.kind in ("AM", "FM"):
            z += .0003*(self.rng.normal(size=count)+1j*self.rng.normal(size=count))
        iq = np.column_stack((z.real, z.imag))*32768
        result = []
        for k in range(frames):
            result.append(encode_frame(np.rint(iq[k*CAPACITY:(k+1)*CAPACITY]),
                                       self.sequence, 1, self.index))
            self.sequence += 1
            self.index += CAPACITY
        return b"".join(result)


class Acquisition(QThread):
    def __init__(self, config, ingress):
        super().__init__()
        self.config, self.ingress = config, ingress
        self.stop_event = threading.Event()
        self.error = ""
        self.connected = False
        self.queue_dropped_bytes = 0
        self.total_bytes = 0
        self.last_data = 0.0
        self.ended = False
        self.commands = queue.Queue(maxsize=16)
        self.replay_sequence = 0
        self.replay_started = False
        self.replay_pending = bytearray()
        self.usb_timing = None

    def replay_exchange(self, reader, packet):
        import struct
        from .legacy.receiver_ads807.replay import Decoder
        decoder = Decoder()
        identifier = struct.unpack_from("<I", packet, 8)[0]
        opcode = struct.unpack_from("<H", packet, 6)[0]
        reader.write(packet)
        deadline = time.monotonic()+3
        while time.monotonic() < deadline:
            try:
                records = decoder.feed(reader.read(size=512, timeout=100))
            except TransferTimeout:
                continue
            if decoder.crc_errors or decoder.discarded:
                raise ValueError("RPL1 exchange has CRC errors or discarded bytes")
            acknowledged = False
            for kind, words, raw in records:
                if kind == "iq" and self.replay_started:
                    if len(self.replay_pending)+len(raw) > 65536:
                        raise BufferError("RPL1 command IQ buffer exceeds 64 KiB")
                    self.replay_pending.extend(raw)
                if kind == "ack" and words[2] == identifier:
                    if words[1] >> 16 or words[3] != opcode:
                        raise RuntimeError("RPL1 命令被拒绝：" + str(words))
                    acknowledged = True
            if acknowledged:
                return
        raise TimeoutError(f"RPL1 命令 {opcode} 等待 ACK 超时")

    def prepare_replay(self, reader):
        import struct
        from .legacy.receiver_ads807.replay import waveform
        from .legacy.receiver_v2.usb_replay import command, upload_commands, STOP
        self.replay_exchange(reader, command(STOP, 0))
        samples, _ = waveform(self.config.replay_kind, amplitude=self.config.replay_amplitude)
        for packet in upload_commands(samples, 1):
            self.replay_sequence = struct.unpack_from("<I", packet, 8)[0]
            if struct.unpack_from("<H", packet, 6)[0] == 3:
                if self.config.usb_managed_pump:
                    reader.start_pump()
                self.replay_started = True
            self.replay_exchange(reader, packet)

    def send(self, data):
        self.commands.put_nowait(data)

    def run(self):
        reader = None
        writer = None
        writer_stop = threading.Event()

        def send_commands():
            try:
                while not writer_stop.is_set():
                    try:
                        packet = self.commands.get(timeout=.02)
                    except queue.Empty:
                        continue
                    reader.write(packet)
            except Exception as error:
                self.error = str(error)
                self.stop_event.set()

        try:
            if self.config.mode == "USB":
                reader = CyUSBReader(self.config.vid, self.config.pid, self.config.dll, duplex=True)
                self.usb_timing = getattr(reader, "timing", None)
                if self.config.usb_protocol == "RPL1":
                    self.prepare_replay(reader)
                else:
                    # Recover driver pipes before any IN/OUT requests start.
                    if hasattr(reader, "reset_endpoints"):
                        reader.reset_endpoints()
                    if self.config.usb_managed_pump:
                        reader.start_pump()
                    # Keep an IN request active while the other endpoint sends control.
                    writer = threading.Thread(target=send_commands, name="ads807-usb-out", daemon=True)
                    writer.start()
            elif self.config.mode == "文件回放":
                reader = Path(self.config.path).open("rb")
            else:
                reader = SyntheticStream(self.config.mode.removeprefix("合成 "))
            self.connected = True
            deadline = time.monotonic()
            while not self.stop_event.is_set():
                try:
                    if self.config.mode == "USB":
                        if self.replay_pending:
                            data = bytes(self.replay_pending)
                            self.replay_pending.clear()
                        else:
                            data = reader.read()
                    elif self.config.mode == "文件回放":
                        data = reader.read(40*512)
                    else:
                        data = reader.read()
                except TransferTimeout:
                    continue
                if not data:
                    if self.config.mode == "文件回放":
                        break
                    continue
                self.total_bytes += len(data)
                self.last_data = time.monotonic()
                try:
                    self.ingress.put_nowait(data)
                except queue.Full:
                    self.queue_dropped_bytes += len(data)
                if self.config.mode != "USB":
                    deadline += len(data)/512*CAPACITY/IQ_RATE
                    self.stop_event.wait(max(0, deadline-time.monotonic()))
                    if time.monotonic()-deadline > .1:
                        deadline = time.monotonic()
        except Exception as error:
            self.error = str(error)
        finally:
            self.connected = False
            self.ended = True
            writer_stop.set()
            if writer is not None:
                writer.join()
            if reader is not None and hasattr(reader, "close"):
                try:
                    if self.replay_started:
                        from .legacy.receiver_v2.usb_replay import command, STOP
                        self.replay_exchange(reader, command(STOP, self.replay_sequence+1))
                    reader.close()
                except Exception as error:
                    self.error = self.error or str(error)
                    reader.close()

    def stop(self):
        self.stop_event.set()
