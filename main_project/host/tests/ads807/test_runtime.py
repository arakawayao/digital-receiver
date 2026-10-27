import json
import queue
import time
import wave

import numpy as np
import pytest

from ads807.audio import AudioOutput
from ads807.protocol import Decoder
from ads807.records import save_capture
from ads807.runtime import Controller
from ads807.sources import SourceConfig, SyntheticStream


def test_audio_bound_and_underrun_are_observable():
    output = AudioOutput()
    output.enabled = True
    for _ in range(20):
        output.push(np.ones(1000, np.float32))
    assert output.frames <= output.capacity
    assert output.overruns > 0
    rendered = output.render(15000)
    assert output.underruns == 1
    assert np.max(rendered) <= .95
    assert np.all(rendered[-3000:] == 0)
    output.clear()
    assert output.frames == 0


@pytest.mark.parametrize("mode,expected", [("合成 AM", "AM"), ("合成 FM", "FM"),
                                              ("合成 无信号", "无有效信号"), ("合成 噪声", "未知")])
def test_stream_pipeline_and_capture_roundtrip(qtbot, tmp_path, mode, expected):
    controller = Controller()
    try:
        controller.start(SourceConfig(mode))
        qtbot.waitUntil(lambda: controller.processor.result.kind == expected
                        and controller.processor.processed > 40000, timeout=8000)
        qtbot.wait(180)
        capture = controller.processor.capture()
        assert capture["measurement"]["kind"] == expected
        assert np.all(np.diff(capture["indices"]) == 1)
        assert controller.processor.continuity.gaps == 0
        assert controller.processor.decoder.crc_errors == 0
        path = save_capture(tmp_path, capture)
        saved = np.load(path/"waveforms.npz")
        assert np.array_equal(saved["iq"], capture["iq"])
        metadata = json.loads((path/"metadata.json").read_text(encoding="utf-8"))
        assert metadata["source"] == mode
        assert metadata["transport_config"]["adc_rate_hz"] == 43500000
        assert metadata["transport_config"]["version"] == 2
        assert metadata["source_config"]["mode"] == mode
        assert metadata["measurement"]["kind"] == expected
        with wave.open(str(path/"demodulated.wav")) as audio:
            assert audio.getframerate() == 48000
            assert audio.getnchannels() == 1
        decoder = Decoder()
        frames = decoder.feed((path/"transport.fcr").read_bytes())
        assert len(frames) > 100
        assert decoder.crc_errors == 0
        with qtbot.waitSignal(controller.saved, timeout=8000):
            controller.save(str(tmp_path))
    finally:
        controller.shutdown()


def test_receive_queue_overflow_does_not_block(qtbot):
    from ads807.sources import Acquisition
    ingress = queue.Queue(maxsize=1)
    source = Acquisition(SourceConfig("合成 AM"), ingress)
    source.start()
    qtbot.waitUntil(lambda: source.queue_dropped_bytes > 0, timeout=3000)
    source.stop()
    assert source.wait(2000)
    assert ingress.qsize() == 1


def test_gap_resets_audio_and_preserves_only_current_segment(qtbot):
    from ads807.protocol import encode_frame
    from ads807.runtime import Processing
    from ads807.sources import Acquisition
    ingress = queue.Queue(128)
    source = Acquisition(SourceConfig("合成 AM"), ingress)
    processor = Processing(ingress, source, AudioOutput())
    stream = SyntheticStream("AM")
    processor.start()
    try:
        ingress.put(stream.read(400))
        qtbot.waitUntil(lambda: processor.processed >= 40000, timeout=5000)
        stream.index += 56
        stream.sequence += 1
        ingress.put(stream.read(400))
        qtbot.waitUntil(lambda: processor.continuity.gaps == 1 and processor.processed >= 80000, timeout=5000)
        capture = processor.capture()
        assert capture["indices"][0] >= 44856
        assert np.all(np.diff(capture["indices"]) == 1)
        assert capture["stats"]["missing_samples"] == 56
        assert processor.error == ""
    finally:
        processor.stop_event.set()
        assert processor.wait(2000)


def test_usb_error_and_stale_data_are_visible(qtbot, monkeypatch):
    import ads807.sources as sources
    class FakeReader:
        def reset_endpoints(self):
            pass

        def __init__(self, *args, **kwargs):
            self.stream = SyntheticStream("FM")
            self.reads = 0
        def read(self):
            self.reads += 1
            if self.reads <= 1:
                return self.stream.read(40)
            raise RuntimeError("simulated disconnect")
        def write(self, data):
            pass
        def close(self):
            pass
    monkeypatch.setattr(sources, "CyUSBReader", FakeReader)
    controller = Controller()
    try:
        controller.start(SourceConfig("USB"))
        qtbot.waitUntil(lambda: controller.state == "错误", timeout=5000)
        assert "simulated disconnect" in controller.last_error
        qtbot.waitUntil(lambda: controller.processor.stale, timeout=3000)
        assert controller.processor.display(20) is None
    finally:
        controller.shutdown()


def test_saved_transport_replay_preserves_final_view(qtbot, tmp_path):
    path = tmp_path/"transport.fcr"
    path.write_bytes(SyntheticStream("FM").read(800))
    controller = Controller()
    try:
        controller.start(SourceConfig("文件回放", path=str(path)))
        qtbot.waitUntil(lambda: controller.processor.result.kind == "FM" and controller.source.ended, timeout=5000)
        qtbot.wait(800)
        assert controller.state == "回放结束"
        assert controller.processor.display(20)["measurement"]["kind"] == "FM"
        assert controller.processor.continuity.gaps == 0
    finally:
        controller.shutdown()


def test_repeated_start_stop_and_restart(qtbot):
    controller = Controller()
    try:
        for kind in ("AM", "FM", "AM"):
            controller.start(SourceConfig("合成 " + kind))
            qtbot.waitUntil(lambda: controller.processor.result.kind == kind, timeout=5000)
            controller.stop()
            qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
        assert not controller.source.isRunning()
    finally:
        controller.shutdown()


def test_batch_conversion_preserves_iq_and_frame_indices(qtbot, monkeypatch):
    from types import SimpleNamespace
    from ads807 import runtime
    from ads807.sources import Acquisition
    source = Acquisition(SourceConfig("合成 FM"), queue.Queue(128))
    processor = runtime.Processing(source.ingress, source, AudioOutput())
    rng = np.random.default_rng(807)
    counts = [34, 111, 1, 78, 111]
    starts = [0xfffffff0, 18, 129, 130, 208]
    samples = [rng.integers(-32768, 32768, size=(count, 2), dtype=np.int16) for count in counts]
    processor.pending = [(start, values, False) for start, values in zip(starts, samples)]
    processor.pending_count = sum(counts)
    monkeypatch.setattr(runtime, "analyse", lambda *args: runtime.Measurement(kind="FM"))
    processor.process_pending(SimpleNamespace(phase_step=1))
    indices, z, audio = processor.history[-1]
    expected = np.concatenate([(values[:, 0].astype(float)+1j*values[:, 1])/32768 for values in samples])
    assert np.array_equal(z, expected)
    assert np.array_equal(indices, np.concatenate([np.arange(start, start+count) for start, count in zip(starts, counts)]))
    assert processor.pending == [] and processor.pending_count == 0


def test_measurement_rate_limit_keeps_all_audio_blocks_and_forces_clipping(qtbot, monkeypatch):
    from types import SimpleNamespace
    from ads807 import runtime
    from ads807.sources import Acquisition
    source = Acquisition(SourceConfig("合成 FM"), queue.Queue(128))
    processor = runtime.Processing(source.ingress, source, AudioOutput())
    measured, demodulated = [], []
    processor.candidate = processor.current_kind = "FM"
    processor.candidate_count = 3
    clock = [1.0]
    monkeypatch.setattr(runtime.time, "perf_counter", lambda: clock[0])

    def analyse(values, lo, clipped):
        measured.append(clipped)
        return runtime.Measurement(kind="未知" if clipped else "FM")

    def demodulate(values, kind):
        demodulated.append((len(values), kind))
        return np.zeros(960, np.float32)

    monkeypatch.setattr(runtime, "analyse", analyse)
    monkeypatch.setattr(processor.demodulator, "process", demodulate)
    values = np.ones((10000, 2), np.int16)
    for index in range(20):
        clock[0] = 1+index*.02
        processor.pending = [(index*10000, values, False)]
        processor.pending_count = 10000
        processor.process_pending(SimpleNamespace(phase_step=1))
    assert 3 <= len(measured) <= 4
    assert len(demodulated) == 20
    assert processor.processed == 200000
    clock[0] += .001
    processor.pending = [(200000, values, True)]
    processor.process_pending(SimpleNamespace(phase_step=1))
    assert measured[-1] is True
    assert demodulated[-1][1] == "未知"
    processor.reset_segment()
    assert processor.next_analysis == 0


@pytest.mark.parametrize("initial,other", [("FM", "AM"), ("AM", "FM")])
def test_single_valid_candidate_preserves_audio_filter_continuity(qtbot, monkeypatch, initial, other):
    from ads807 import runtime
    from ads807.sources import Acquisition

    source = Acquisition(SourceConfig("合成 " + initial), queue.Queue(128))
    processor = runtime.Processing(source.ingress, source, AudioOutput())
    reference = runtime.Demodulator()
    candidate = [initial]
    monkeypatch.setattr(runtime, "analyse", lambda *args: runtime.Measurement(
        kind=candidate[0], carrier_hz=100e6, level_dbfs=-20))
    t = np.arange(20000)/500000
    z = (.3*np.exp(1j*25*np.sin(2*np.pi*1000*t)) if initial == "FM" else
         .3*(1+.5*np.cos(2*np.pi*1000*t)).astype(complex))
    for _ in range(3):
        processor.measure(z, 100e6, False)
    processor.demodulator.process(z, processor.result.kind)
    reference.process(z, initial)
    candidate[0] = other
    processor.measure(z, 100e6, False)
    assert processor.result.kind == initial
    assert other in processor.result.reason and "1/3" in processor.result.reason
    assert processor.result.carrier_hz is None
    assert processor.result.confidence == 0
    assert processor.stats()["classification"]["held_analyses"] == 1
    audio = processor.demodulator.process(z, processor.result.kind)
    assert np.array_equal(audio, reference.process(z, initial))
    assert np.std(audio[:960]) > .01
    candidate[0] = initial
    processor.measure(z, 100e6, False)
    assert processor.result.kind == initial
    assert processor.result.reason == ""


@pytest.mark.parametrize("candidate", ["AM", "未知", "无有效信号"])
def test_candidate_confirmation_does_not_hide_signal_loss(qtbot, monkeypatch, candidate):
    from ads807 import runtime
    from ads807.sources import Acquisition

    source = Acquisition(SourceConfig("合成 FM"), queue.Queue(128))
    processor = runtime.Processing(source.ingress, source, AudioOutput())
    selected = ["FM"]
    monkeypatch.setattr(runtime, "analyse", lambda *args: runtime.Measurement(kind=selected[0]))
    for _ in range(3):
        processor.measure([], 100e6, False)
    selected[0] = candidate
    processor.measure([], 100e6, False)
    if candidate == "AM":
        assert processor.result.kind == "FM"
        processor.measure([], 100e6, False)
        assert processor.result.kind == "FM"
        processor.measure([], 100e6, False)
    assert processor.current_kind == processor.result.kind == candidate
    processor.reset_segment()
    selected[0] = "FM"
    processor.measure([], 100e6, False)
    assert processor.result.kind == "未知"
    assert processor.candidate_count == 1


def test_forced_demodulation_outputs_audio_when_auto_classification_is_unknown(monkeypatch):
    from types import SimpleNamespace
    from ads807 import runtime
    from ads807.sources import Acquisition

    source = Acquisition(SourceConfig("合成 FM"), queue.Queue(128))
    processor = runtime.Processing(source.ingress, source, AudioOutput())
    processor.demodulation_mode = "FM"
    monkeypatch.setattr(runtime, "analyse", lambda *args: runtime.Measurement(
        kind="未知", reason="信号质量不足", level_dbfs=-38))
    t = np.arange(20000)/500000
    z = .08*np.exp(1j*25*np.sin(2*np.pi*1000*t))
    processor.pending = [(0, np.column_stack((z.real, z.imag))*32768, False)]
    processor.pending_count = len(z)
    processor.process_pending(SimpleNamespace(phase_step=1))
    assert processor.result.kind == "未知"
    assert processor.demodulation == {"mode": "FM", "kind": "FM", "forced": True}
    assert np.std(processor.history[-1][2][960:]) > .01


@pytest.mark.parametrize("kind", ["AM", "FM"])
def test_forced_stream_save_switch_to_auto_and_restart(qtbot, tmp_path, kind):
    controller = Controller()
    try:
        controller.set_demodulation(kind)
        controller.start(SourceConfig("合成 噪声"))
        qtbot.waitUntil(lambda: controller.processor.display(20) is not None
                        and controller.processor.processed > 60000, timeout=8000)
        snapshot = controller.processor.capture()
        assert snapshot["measurement"]["kind"] == "未知"
        assert snapshot["demodulation"] == {"mode": kind, "kind": kind, "forced": True}
        assert np.std(snapshot["audio"][960:]) > .001
        path = save_capture(tmp_path, snapshot)
        metadata = json.loads((path/"metadata.json").read_text(encoding="utf-8"))
        assert metadata["measurement"]["kind"] == "未知"
        assert metadata["demodulation"] == snapshot["demodulation"]
        processor = controller.processor
        controller.set_demodulation("auto")
        qtbot.waitUntil(lambda: processor.demodulation["mode"] == "auto", timeout=4000)
        assert not processor.demodulation["forced"]
        assert np.all(processor.capture()["audio"] == 0)
        controller.set_demodulation(kind)
        qtbot.waitUntil(lambda: processor.demodulation["mode"] == kind, timeout=4000)
        assert processor.last_header.config_id == 0
        controller.stop()
        qtbot.waitUntil(lambda: controller.state == "已停止", timeout=5000)
        controller.start(SourceConfig("合成 噪声"))
        qtbot.waitUntil(lambda: controller.processor.demodulation["mode"] == kind, timeout=4000)
    finally:
        controller.shutdown()
