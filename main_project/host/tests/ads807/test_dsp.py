import numpy as np
import pytest
from scipy import signal

from ads807.dsp import AUDIO_RATE, Demodulator, analyse, spectrum
from ads807.protocol import IQ_RATE


def waveform(kind, amplitude=.35, offset=137, depth=.6, deviation=25000, snr=60, length=50000):
    t = np.arange(length)/IQ_RATE
    phase = 2*np.pi*offset*t
    if kind == "AM":
        z = amplitude*(1+depth*np.cos(2*np.pi*1000*t))*np.exp(1j*phase)
    elif kind == "FM":
        z = amplitude*np.exp(1j*(phase+deviation/1000*np.sin(2*np.pi*1000*t)))
    elif kind == "tone":
        z = amplitude*np.exp(1j*phase)
    else:
        return np.zeros(length, complex)
    rng = np.random.default_rng(807)
    z += amplitude*10**(-snr/20)/np.sqrt(2)*(rng.normal(size=length)+1j*rng.normal(size=length))
    return z


@pytest.mark.parametrize("kind", ["AM", "FM"])
@pytest.mark.parametrize("amplitude,offset,snr", [(.05, -2000, 30), (.35, 137, 40), (.5, 3000, 25)])
def test_identification_with_level_offset_and_noise(kind, amplitude, offset, snr):
    result = analyse(waveform(kind, amplitude, offset, snr=snr), 100_000_000)
    assert result.kind == kind
    assert abs(result.carrier_hz - (100_000_000+offset)) < 100
    assert abs(result.modulation_hz - 1000) < 5
    if kind == "AM":
        assert abs(result.am_depth-.6) < .03
    else:
        assert abs(result.fm_deviation_hz-25000) < 1000
        assert abs(result.fm_index-25) < 1


def test_identification_of_wideband_fm():
    """A 75 kHz FM signal must not be rejected by the narrowband gate."""
    length = 100_000
    t = np.arange(length)/IQ_RATE
    phase = 2*np.pi*221*t + 75*np.sin(2*np.pi*1_000*t)
    result = analyse(.25*np.exp(1j*phase), 96_700_000)
    assert result.kind == "FM"
    assert result.fm_deviation_hz is not None
    assert abs(result.fm_deviation_hz-75_000) < 2_000
    audio = Demodulator().process(.25*np.exp(1j*phase), result.kind)
    assert np.max(np.abs(audio[2_000:])) > .01


def test_identification_of_low_deviation_single_tone_fm():
    """Small-deviation generator FM remains distinguishable from a carrier."""
    length = 100_000
    t = np.arange(length)/IQ_RATE
    phase = 2*np.pi*221*t + .2*np.sin(2*np.pi*500*t)
    result = analyse(.25*np.exp(1j*phase), 103_700_000)
    assert result.kind == "FM"
    assert result.fm_deviation_hz is not None
    assert abs(result.fm_deviation_hz-100) < 20
    assert abs(result.modulation_hz-500) < 5


@pytest.mark.parametrize("rf_hz", [88_000_000, 93_400_000, 98_100_000, 105_700_000, 108_000_000])
def test_wideband_fm_with_envelope_variation_keeps_fm_classification(rf_hz):
    t = np.arange(20000)/IQ_RATE
    envelope = .05*(1+.2*np.sin(2*np.pi*150*t))
    z = envelope*np.exp(1j*(2*np.pi*900*t+50*np.sin(2*np.pi*1000*t)))
    result = analyse(z, rf_hz)
    assert result.kind == "FM"
    assert abs(result.fm_deviation_hz-50000) < 2000
    assert abs(result.carrier_hz-(rf_hz+900)) < 100
    audio = Demodulator().process(z, result.kind)
    assert np.std(audio[960:]) > .1
    assert analyse(z, rf_hz, clipped=True).kind == "未知"


@pytest.mark.parametrize("cutoff", [10_000, 50_000, 100_000, 180_000])
def test_filtered_noise_is_not_promoted_to_fm(cutoff):
    rng = np.random.default_rng(807)
    noise = rng.normal(size=40000)+1j*rng.normal(size=40000)
    sos = signal.butter(5, cutoff, fs=IQ_RATE, output="sos")
    z = signal.sosfilt(sos, noise)[10000:]*.05
    assert analyse(z, 93_400_000).kind == "未知"


@pytest.mark.parametrize("pilot_hz,expected", [(19000, "FM"), (18000, "未知"), (20000, "未知"), (0, "未知")])
def test_broadcast_pilot_supports_fm_with_stronger_envelope_variation(pilot_hz, expected):
    t = np.arange(20000)/IQ_RATE
    phase = 2*np.pi*900*t+35*np.sin(2*np.pi*1000*t)
    if pilot_hz:
        phase += 6000/pilot_hz*np.sin(2*np.pi*pilot_hz*t)
    z = .05*(1+.32*np.sin(2*np.pi*150*t))*np.exp(1j*phase)
    assert analyse(z, 105_700_000).kind == expected
    assert analyse(z, 105_700_000, clipped=True).kind == "未知"


def test_am_with_19khz_envelope_component_is_not_stereo_fm():
    t = np.arange(20000)/IQ_RATE
    z = .2*(1+.4*np.cos(2*np.pi*1000*t)+.1*np.cos(2*np.pi*19000*t))*np.exp(2j*np.pi*900*t)
    assert analyse(z, 105_700_000).kind == "AM"


@pytest.mark.parametrize("kind", ["AM", "FM"])
def test_demodulation_block_seams_and_audio_frequency(kind):
    z = waveform(kind, snr=100, length=150000)
    full = Demodulator().process(z, kind)
    streaming = Demodulator()
    pieces = [streaming.process(z[start:start+7777], kind) for start in range(0, len(z), 7777)]
    audio = np.concatenate(pieces)
    assert len(audio) == round(len(z)*AUDIO_RATE/IQ_RATE)
    assert np.max(abs(audio-full)) < 1e-6
    freq, psd = signal.periodogram(audio[3000:], AUDIO_RATE)
    assert abs(freq[np.argmax(psd)]-1000) < 5
    assert .1 < np.max(abs(audio)) < 1


def test_audio_lowpass_suppresses_out_of_band_alias():
    t = np.arange(100000)/IQ_RATE
    z = .3*(1+.3*np.cos(2*np.pi*1000*t)+.3*np.cos(2*np.pi*30000*t)).astype(complex)
    audio = Demodulator().process(z, "AM")[2000:]
    frequency, psd = signal.periodogram(audio, AUDIO_RATE)
    main = psd[abs(frequency-1000)<20].max()
    aliased = psd[abs(frequency-18000)<20].max()
    assert 10*np.log10(main/aliased) > 40


@pytest.mark.parametrize("deemphasis_us", [50, 75, 100, 150, 200, 300])
def test_fm_deemphasis_longer_time_constants_are_causal_and_attenuate_high_audio(deemphasis_us):
    t = np.arange(150000)/IQ_RATE
    z = .3*np.exp(1j*(10*np.sin(2*np.pi*1000*t)+np.sin(2*np.pi*10000*t)))
    reference = Demodulator().process(z, "FM")
    demodulator = Demodulator()
    demodulator.deemphasis = deemphasis_us
    audio = demodulator.process(z, "FM")
    alpha = np.exp(-1/(AUDIO_RATE*deemphasis_us*1e-6))
    # Skip startup muting; compare steady state against the expected RC response.
    expected = signal.lfilter([1-alpha], [1, -alpha], reference)
    assert len(audio) == len(reference)
    assert np.isfinite(audio).all()
    assert np.max(abs(audio[3000:]-expected[3000:])) < 1e-6
    frequencies, power = signal.periodogram(audio[3000:], AUDIO_RATE)
    assert power[abs(frequencies-10000)<10].max() < power[abs(frequencies-1000)<10].max()


@pytest.mark.parametrize("kind", ["silence", "noise", "tone", "clipped"])
def test_no_forced_am_fm_label(kind):
    if kind == "silence":
        z = np.zeros(10000, complex)
    elif kind == "noise":
        rng = np.random.default_rng(1)
        z = .1*(rng.normal(size=10000)+1j*rng.normal(size=10000))
    else:
        z = waveform("AM" if kind == "clipped" else "tone")
    result = analyse(z, 100_000_000, clipped=kind == "clipped")
    assert result.kind == ("无有效信号" if kind == "silence" else "未知")
    assert result.am_depth is None
    assert result.fm_deviation_hz is None


def test_fft_bin_and_amplitude_calibration():
    n = 8192
    rate = IQ_RATE
    z = .5*np.exp(2j*np.pi*17*np.arange(n)/n)
    frequencies, power = spectrum(z)
    assert frequencies[np.argmax(power)] == 17*rate/n
    assert abs(max(power) - 20*np.log10(.5)) < 1e-6


def test_silence_and_filter_reset_after_gap():
    demod = Demodulator()
    demod.process(waveform("FM", length=20000), "FM")
    demod.reset()
    audio = demod.process(waveform("FM", length=20000), "FM")
    assert np.all(audio[:960] == 0)
    unknown = demod.process(waveform("AM", length=20000), "未知")
    assert not unknown.any()
