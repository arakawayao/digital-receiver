import numpy as np
import pytest

from ads807.audio import AudioOutput


def drive_jittered_stream(output, seconds=4):
    output.enabled = True
    chunk = np.full(1920, .2, dtype=np.float32)
    arrivals = {}
    for block in range(seconds*25):
        # One 60 ms stall every 800 ms, followed by the delayed real samples.
        tick = block*2 + (3 if block % 20 in (10, 11, 12) else 0)
        arrivals[tick] = arrivals.get(tick, 0)+1
    for tick in range(seconds*50):
        for _ in range(arrivals.get(tick, 0)):
            output.push(chunk)
        output.render(960)


def test_audio_prebuffer_absorbs_bounded_delivery_jitter():
    before = AudioOutput()
    before.prebuffer_frames = 1920
    drive_jittered_stream(before)
    assert before.underruns > 0
    after = AudioOutput()
    drive_jittered_stream(after)
    assert after.underruns == after.overruns == 0
    assert after.frames <= after.capacity


def test_real_audio_outage_remains_observable_and_rebuffers():
    output = AudioOutput()
    output.enabled = True
    output.push(np.ones(output.prebuffer_frames, np.float32))
    for _ in range(10):
        output.render(960)
    assert output.underruns == 1
    assert not output.primed
    output.push(np.ones(1920, np.float32))
    assert not output.render(960).any()
    assert output.frames == 1920
    output.push(np.ones(output.prebuffer_frames-1920, np.float32))
    assert output.render(960).any()


def test_gap_reset_keeps_statistics_and_new_session_clears_them():
    output = AudioOutput()
    output.underruns, output.overruns, output.device_errors = 4, 2, 1
    output.startup_silence_frames = 960
    output.last_device_status = "output underflow"
    output.clear()
    assert (output.underruns, output.overruns, output.device_errors) == (4, 2, 1)
    output.clear(reset_stats=True)
    assert (output.underruns, output.overruns, output.device_errors) == (0, 0, 0)
    assert output.startup_silence_frames == 0
    assert output.last_device_status == ""


def test_callback_preserves_device_status_for_diagnosis():
    output = AudioOutput()
    rendered = np.empty((960, 1), np.float32)
    output._callback(rendered, 960, None, "output underflow")
    assert output.device_errors == 1
    assert output.last_device_status == "output underflow"
    assert not rendered.any()


def test_device_latency_budget_absorbs_stall_and_batched_consumption():
    def drive(output):
        output.enabled = True
        pending = 0
        for tick in range(100):
            if tick % 2 == 0:
                pending += 1
            # A 240 ms worker stall, then delivery of the actual queued samples.
            if not 30 <= tick % 100 < 42:
                for _ in range(pending):
                    output.push(np.full(1920, .1, np.float32))
                pending = 0
            output.render(960)
        return output.snapshot()

    previous = drive(AudioOutput())
    assert previous["underruns"] > 0
    current = AudioOutput()
    current.configure_buffer(.2)
    stats = drive(current)
    assert stats["underruns"] == stats["overruns"] == 0
    assert stats["prebuffer_ms"] == 280
    assert stats["capacity_ms"] == 600
    assert current.frames <= current.capacity


def test_overflow_discards_only_excess_and_accounts_samples():
    output = AudioOutput()
    output.enabled = True
    output.push(np.arange(output.capacity-10, dtype=np.float32))
    output.push(np.zeros(30, np.float32))
    assert output.frames == output.capacity
    assert output.chunks[0][0] == 20
    stats = output.snapshot()
    assert stats["overruns"] == 1
    assert stats["discarded_frames"] == 20
    assert stats["received_frames"] == output.frames+stats["discarded_frames"]
    output.clear(reason="classification_change")
    assert output.snapshot()["clear_reasons"] == {"classification_change": 1}
    assert output.snapshot()["discarded_frames"] == 20
    output.clear(reset_stats=True)
    assert output.snapshot()["clear_reasons"] == {}
    assert output.snapshot()["discarded_frames"] == 0


@pytest.mark.parametrize("explicit,reject,expected", [(None, False, 2), (0, False, 0), (None, True, None)])
def test_default_device_prefers_only_same_named_wasapi(explicit, reject, expected):
    class FakeSD:
        PortAudioError = RuntimeError

        @staticmethod
        def query_devices(kind=None):
            devices = [{"name": "selected", "hostapi": 0, "max_output_channels": 2},
                       {"name": "different", "hostapi": 1, "max_output_channels": 2},
                       {"name": "selected", "hostapi": 1, "max_output_channels": 2}]
            return devices[0] if kind == "output" else devices

        @staticmethod
        def query_hostapis():
            return [{"name": "MME"}, {"name": "Windows WASAPI"}]

        @staticmethod
        def check_output_settings(**kwargs):
            if reject:
                raise RuntimeError("unsupported")

    assert AudioOutput.select_device(FakeSD, explicit) == expected
