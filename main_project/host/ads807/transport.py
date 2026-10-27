"""FX2 EP2 IN / EP6 OUT through the installed official Cypress driver."""
import ctypes
from collections import deque
import hashlib
import json
import os
from pathlib import Path
import threading
import time

from .paths import RESOURCE_ROOT

EP_IN = 0x82


def find_cyusb_dll(dll=None):
    if dll:
        path = Path(dll).resolve()
    else:
        bundled = RESOURCE_ROOT / "usb" / "CyUSB.dll"
        base = Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")) / "Cypress"
        found = sorted(base.glob("EZ-USB FX3 SDK/*/library/c_sharp/lib/CyUSB.dll"))
        if bundled.is_file():
            path = bundled
        elif found:
            path = found[-1]
        else:
            raise RuntimeError("未找到官方 CyUSB.dll，请在连接设置中选择 DLL")
    if not path.is_file():
        raise RuntimeError(f"CyUSB.dll 不存在：{path}")
    return path


class TransferTimeout(TimeoutError):
    pass


class USBTiming:
    """Bounded observations around native calls, including Python scheduling."""

    def __init__(self):
        self.lock = threading.Lock()
        self.started = time.perf_counter()
        self.last_return = None
        self.calls = 0
        self.max_gap_ms = 0.0
        self.max_read_ms = 0.0
        self.over_512_us = 0
        self.over_1024_us = 0
        self.writes = 0
        self.max_write_ms = 0.0
        self.recent = deque(maxlen=128)
        self.pump = None

    def record_read(self, submitted, returned, count, ok):
        with self.lock:
            gap = max(0.0, (submitted-self.last_return)*1000) if self.last_return is not None else 0.0
            duration = (returned-submitted)*1000
            self.calls += 1
            self.max_gap_ms = max(self.max_gap_ms, gap)
            self.max_read_ms = max(self.max_read_ms, duration)
            self.over_512_us += gap > .512
            self.over_1024_us += gap > 1.024
            self.recent.append(dict(submit_s=submitted-self.started, submit_gap_ms=gap,
                                    read_ms=duration, bytes=count, ok=bool(ok)))
            self.last_return = returned

    def record_write(self, elapsed):
        with self.lock:
            self.writes += 1
            self.max_write_ms = max(self.max_write_ms, elapsed*1000)

    def snapshot(self):
        with self.lock:
            result = dict(read_calls=self.calls, max_submit_gap_ms=self.max_gap_ms,
                        max_read_ms=self.max_read_ms, submit_gaps_over_512_us=self.over_512_us,
                        submit_gaps_over_1024_us=self.over_1024_us,
                        write_calls=self.writes, max_write_ms=self.max_write_ms,
                        clock="perf_counter", clock_resolution_s=time.get_clock_info("perf_counter").resolution,
                        recent_reads=list(self.recent))
            if self.pump is not None:
                values = list(self.pump.Timing())
                result.update(read_calls=int(values[0]), max_submit_gap_ms=values[1], max_read_ms=values[2],
                              submit_gaps_over_512_us=int(values[3]), submit_gaps_over_1024_us=int(values[4]),
                              managed_queue_dropped_bytes=int(values[5]), managed_queue_depth=int(values[6]),
                              managed_error=str(self.pump.Error), clock="Stopwatch", recent_reads=[])
                result["queued_usb_requests"] = int(self.pump.QueueDepth)
                result["max_requeue_ms"] = result.pop("max_submit_gap_ms")
            return result


class CyUSBReader:
    def __init__(self, vid=0x04B4, pid=0x1004, dll=None, duplex=False):
        import clr
        from System import Array, Byte, Int32
        from System.Runtime.InteropServices import GCHandle, GCHandleType

        path = find_cyusb_dll(dll)
        clr.AddReference(str(path))
        self.sdk_path = path
        from CyUSB import USBDeviceList, CyConst

        self.Array, self.Byte, self.Int32 = Array, Byte, Int32
        self.GCHandle, self.GCHandleType = GCHandle, GCHandleType
        self.timing = USBTiming()
        self.pump = None
        self.devices = USBDeviceList(CyConst.DEVICES_CYUSB)
        try:
            matches = [self.devices[i] for i in range(self.devices.Count)
                       if self.devices[i] is not None
                       and self.devices[i].VendorID == vid and self.devices[i].ProductID == pid]
            if len(matches) != 1:
                raise RuntimeError(f"匹配到 {len(matches)} 个 {vid:04X}:{pid:04X} 设备，需要恰好一个")
            self.device = matches[0]
            endpoints = [e for e in self.device.EndPoints if e is not None and int(e.Address) == EP_IN]
            if self.device.AltIntfc != 0 or not self.device.bHighSpeed or len(endpoints) != 1:
                raise RuntimeError("需要高速 USB、alternate interface 0 和 EP2 IN 0x82")
            self.endpoint = endpoints[0]
            if int(self.endpoint.Attributes) & 3 != 2 or int(self.endpoint.MaxPktSize) != 512:
                raise RuntimeError("EP2 必须是 512 字节高速 Bulk IN")
            if duplex:
                outputs = [e for e in self.device.EndPoints if e is not None and int(e.Address) == 0x06]
                if (len(outputs) != 1 or int(outputs[0].Attributes) & 3 != 2
                        or int(outputs[0].MaxPktSize) != 512):
                    raise RuntimeError("三模式固件需要 512 字节 Bulk EP6 OUT 0x06")
                self.output = outputs[0]
        except Exception:
            self.close()
            raise

    def write(self, packet):
        if len(packet) != 512:
            raise ValueError("TCM1 必须为完整 512 字节命令")
        self.output.TimeOut = 500
        buffer = self.Array[self.Byte](packet)
        start = time.perf_counter()
        try:
            ok, _, count = self.output.XferData(buffer, self.Int32(len(packet)))
        finally:
            self.timing.record_write(time.perf_counter()-start)
        if not ok or int(count) != len(packet):
            detail = (f"bytes={int(count)}/{len(packet)}, "
                      f"LastError={int(self.output.LastError)}, "
                      f"NtStatus={int(self.output.NtStatus):#x}, "
                      f"UsbdStatus={int(self.output.UsbdStatus):#x}, "
                      f"elapsed_ms={(time.perf_counter()-start)*1000:.0f}")
            raise RuntimeError(f"EP6 OUT 写入失败或短写：{detail}；命令未重发。"
                               "请关闭上位机后重连 FX2 数据 USB；若板卡断电，需重新加载 SOF。")

    def reset_endpoints(self):
        """Recover bulk pipes before starting requests; do not reset FX2 firmware."""
        if self.pump is not None:
            raise RuntimeError("USB端点恢复必须在异步接收启动前执行")
        failures = []
        for label, endpoint in (("EP6 OUT", self.output), ("EP2 IN", self.endpoint)):
            try:
                endpoint.Abort()
                if not endpoint.Reset():
                    failures.append(f"{label} Reset=false "
                                   f"LastError={int(endpoint.LastError)} "
                                   f"NtStatus={int(endpoint.NtStatus):#x}")
            except Exception as error:
                failures.append(f"{label}: {error}")
        if failures:
            raise RuntimeError("USB端点恢复失败：" + "；".join(failures))

    def read(self, size=32768, timeout=100):
        if self.pump is not None:
            deadline = time.perf_counter() + timeout/1000
            while True:
                if str(self.pump.Error):
                    raise RuntimeError(str(self.pump.Error))
                if self.pump.DroppedBytes:
                    raise BufferError("Managed USB receive queue overflow: " + str(self.pump.DroppedBytes))
                data = self.pump.Read(0)
                if data is not None:
                    break
                if time.perf_counter() >= deadline:
                    raise TransferTimeout("Managed USB read timed out")
                # Do not hold the interpreter lock inside a managed blocking wait.
                time.sleep(.001)
            handle = self.GCHandle.Alloc(data, self.GCHandleType.Pinned)
            try:
                return ctypes.string_at(handle.AddrOfPinnedObject().ToInt64(), len(data))
            finally:
                handle.Free()
        ep = self.endpoint
        ep.TimeOut = timeout
        buffer = self.Array.CreateInstance(self.Byte, size)
        start = time.perf_counter()
        ok, data, count = ep.XferData(buffer, self.Int32(size))
        returned = time.perf_counter()
        count = int(count)
        self.timing.record_read(start, returned, count, ok)
        if not 0 <= count <= size:
            raise RuntimeError("CyUSB 返回非法传输长度")
        if not ok:
            timed_out = int(ep.LastError) in (121, 997, 1460) or time.perf_counter()-start >= timeout*.0008
            detail = f"USB: error={ep.LastError}, status={int(ep.NtStatus):#x}, bytes={count}"
            if not timed_out:
                raise RuntimeError(detail)
            if not count:
                raise TransferTimeout(detail)
        handle = self.GCHandle.Alloc(data, self.GCHandleType.Pinned)
        try:
            return ctypes.string_at(handle.AddrOfPinnedObject().ToInt64(), count)
        finally:
            handle.Free()

    def start_pump(self):
        import clr
        from .build_usb_pump import build_inputs
        _, library, expected = build_inputs(self.sdk_path)
        if not library.is_file() or not library.with_suffix(".json").is_file():
            raise RuntimeError("Build optional USB pump: python -B -m ads807.build_usb_pump")
        evidence = json.loads(library.with_suffix(".json").read_text(encoding="utf-8"))
        if any(evidence.get(key) != value for key, value in expected.items()) or evidence.get("assembly_sha256") != hashlib.sha256(library.read_bytes()).hexdigest():
            raise RuntimeError("Managed USB assembly does not match build evidence")
        clr.AddReference(str(library))
        from Ads807Transport import UsbReceivePump
        self.pump = UsbReceivePump(self.endpoint)
        self.timing.pump = self.pump

    def close(self):
        try:
            if self.pump is not None:
                pump, self.pump = self.pump, None
                pump.Dispose()
        finally:
            if self.devices is not None:
                devices, self.devices = self.devices, None
                devices.Dispose()
