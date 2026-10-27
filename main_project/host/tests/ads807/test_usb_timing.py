from types import SimpleNamespace

import pytest

from ads807.transport import CyUSBReader, USBTiming


def test_native_call_duration_is_distinct_from_submit_gap():
    timing = USBTiming()
    timing.started = 0
    timing.record_read(1.0, 1.100, 32768, True)
    timing.record_read(1.1002, 1.110, 32768, True)
    timing.record_read(1.112, 1.212, 512, False)
    timing.record_write(.003)
    stats = timing.snapshot()
    assert stats["read_calls"] == 3
    assert abs(stats["max_read_ms"] - 100) < .00001
    assert abs(stats["max_submit_gap_ms"] - 2) < .00001
    assert stats["submit_gaps_over_512_us"] == stats["submit_gaps_over_1024_us"] == 1
    assert stats["write_calls"] == 1 and stats["max_write_ms"] == 3
    assert stats["recent_reads"][-1]["ok"] is False


def test_timing_history_is_bounded_and_snapshots_are_detached():
    timing = USBTiming()
    for n in range(1000):
        timing.record_read(n, n+.01, 512, True)
    stats = timing.snapshot()
    assert stats["read_calls"] == 1000
    assert len(stats["recent_reads"]) == 128
    stats["recent_reads"].clear()
    assert len(timing.snapshot()["recent_reads"]) == 128


def test_managed_worker_metrics_are_used_instead_of_python_consumer_waits():
    class Pump:
        Error = ""
        QueueDepth = 128

        def Timing(self):
            return [12, .3, 14.2, 0, 0, 512, 3]

    timing = USBTiming()
    timing.pump = Pump()
    stats = timing.snapshot()
    assert stats["read_calls"] == 12
    assert stats["max_requeue_ms"] == .3
    assert stats["queued_usb_requests"] == 128
    assert stats["managed_queue_dropped_bytes"] == 512
    assert stats["clock"] == "Stopwatch"


def test_managed_worker_stops_before_device_is_disposed():
    operations = []

    class Pump:
        def Dispose(self):
            operations.append("join worker")

    class Devices:
        def Dispose(self):
            operations.append("dispose device")

    reader = CyUSBReader.__new__(CyUSBReader)
    reader.pump, reader.devices = Pump(), Devices()
    reader.close()
    reader.close()
    assert operations == ["join worker", "dispose device"]


def test_endpoint_recovery_aborts_and_resets_both_bulk_pipes():
    calls = []

    class Endpoint:
        def __init__(self, name):
            self.name = name
            self.LastError = self.NtStatus = 0

        def Abort(self):
            calls.append((self.name, "abort"))
            return True

        def Reset(self):
            calls.append((self.name, "reset"))
            return True

    reader = CyUSBReader.__new__(CyUSBReader)
    reader.pump = None
    reader.output = Endpoint("out")
    reader.endpoint = Endpoint("in")
    reader.reset_endpoints()
    assert calls == [("out", "abort"), ("out", "reset"),
                     ("in", "abort"), ("in", "reset")]


def test_endpoint_recovery_reports_reset_failure():
    class Endpoint:
        LastError = 31
        NtStatus = 0xC0000001

        def Abort(self):
            return True

        def Reset(self):
            return False

    reader = CyUSBReader.__new__(CyUSBReader)
    reader.pump = None
    reader.output = reader.endpoint = Endpoint()
    with pytest.raises(RuntimeError, match="USB端点恢复失败"):
        reader.reset_endpoints()


@pytest.mark.parametrize("ok,count", [(False, 0), (False, 512), (True, 128)])
def test_out_failure_reports_driver_status_and_never_resends(ok, count):
    calls = []

    def transfer(data, length):
        calls.append(bytes(data))
        return ok, data, count

    reader = CyUSBReader.__new__(CyUSBReader)
    reader.output = SimpleNamespace(XferData=transfer, LastError=997,
                                    NtStatus=0x3e3, UsbdStatus=0xc0010000)
    reader.Array, reader.Byte, reader.Int32 = {int: bytes}, int, int
    reader.timing = USBTiming()
    with pytest.raises(RuntimeError) as error:
        reader.write(bytes(512))
    detail = str(error.value)
    assert f"bytes={count}/512" in detail
    assert "LastError=997" in detail and "NtStatus=0x3e3" in detail
    assert "UsbdStatus=0xc0010000" in detail
    assert len(calls) == reader.timing.writes == 1


def test_device_is_released_when_managed_shutdown_reports_error():
    calls = []

    def failed_shutdown():
        calls.append("pump")
        raise RuntimeError("receive failed")

    reader = CyUSBReader.__new__(CyUSBReader)
    reader.pump = SimpleNamespace(Dispose=failed_shutdown)
    reader.devices = SimpleNamespace(Dispose=lambda: calls.append("device"))
    with pytest.raises(RuntimeError, match="receive failed"):
        reader.close()
    reader.close()
    assert calls == ["pump", "device"]
