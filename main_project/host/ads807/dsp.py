"""Heuristic AM/FM analysis and stateful mono demodulation, no truth labels."""
from dataclasses import dataclass, asdict

import numpy as np
from scipy import signal

from .protocol import IQ_RATE

AUDIO_RATE = 48_000
DEMODULATION_MODES = {"auto": "自动识别", "AM": "强制 AM", "FM": "强制 FM"}
FM_DEEMPHASIS_OPTIONS = ((0, "关闭"), (50, "50 µs"), (75, "75 µs"),
                         (100, "100 µs"), (150, "150 µs"), (200, "200 µs"),
                         (300, "300 µs"))


@dataclass
class Measurement:
    kind: str = "无有效信号"
    confidence: float = 0.0
    carrier_hz: float | None = None
    residual_hz: float | None = None
    am_depth: float | None = None
    fm_deviation_hz: float | None = None
    modulation_hz: float | None = None
    fm_index: float | None = None
    level_dbfs: float = -120.0
    occupied_hz: float = 0.0
    reason: str = ""

    def to_dict(self):
        return asdict(self)


def spectrum(z, rate=IQ_RATE, nfft=8192):
    n = min(len(z), nfft)
    if n < 8:
        return np.empty(0), np.empty(0)
    window = signal.windows.hann(n, sym=False)
    transformed = np.fft.fftshift(np.fft.fft(z[-n:] * window, nfft)) / window.sum()
    db = 20*np.log10(np.maximum(np.abs(transformed), 1e-7))
    return np.fft.fftshift(np.fft.fftfreq(nfft, 1/rate)), db


def _tone_frequency(values, rate):
    values = values - np.mean(values)
    if len(values) < 64 or np.std(values) < 1e-9:
        return None
    power = np.abs(np.fft.rfft(values * signal.windows.hann(len(values), sym=False)))**2
    freqs = np.fft.rfftfreq(len(values), 1/rate)
    power[(freqs < 50) | (freqs > 15_000)] = 0
    k = int(np.argmax(power))
    if power[k] <= 0 or power[k]/(power.sum() + 1e-30) < .15:
        return None
    offset = 0.0
    if 0 < k < len(power)-1:
        a, b, c = np.log(np.maximum(power[k-1:k+2], 1e-30))
        offset = float(.5*(a-c)/(a-2*b+c)) if a-2*b+c else 0
    return float((k + np.clip(offset, -.5, .5))*rate/len(values))


def _has_stereo_pilot(values, rate):
    if len(values) < 512 or rate/2 <= 20_500:
        return False
    power = abs(np.fft.rfft((values-np.mean(values))*signal.windows.hann(len(values), sym=False)))**2
    frequencies = np.fft.rfftfreq(len(values), 1/rate)
    pilot = np.flatnonzero(abs(frequencies-19_000) <= 100)
    neighbours = (abs(frequencies-19_000) >= 200) & (abs(frequencies-19_000) <= 1500)
    peak = pilot[np.argmax(power[pilot])]
    return bool(abs(frequencies[peak]-19_000) <= 50
                and power[peak] > 16*max(float(np.median(power[neighbours])), 1e-30)
                and power[peak] > .002*power.sum())


def analyse(z, lo_hz, clipped=False, rate=IQ_RATE):
    z = np.asarray(z, dtype=np.complex128)
    result = Measurement()
    if len(z) < 1024 or not np.isfinite(z).all():
        result.reason = "有效连续样本不足"
        return result
    rms = float(np.sqrt(np.mean(np.abs(z)**2)))
    result.level_dbfs = float(20*np.log10(max(rms, 1e-6)))
    if rms < .001:
        result.reason = "幅度低于软件门限"
        return result
    env = np.abs(z)
    mean = float(np.mean(env))
    frequency = np.angle(z[1:]*np.conj(z[:-1]))*rate/(2*np.pi)
    # Sample only the audio bandwidth for robust envelope/phase features.
    env_lp = signal.resample_poly(env, 1, 10)[20:-20]
    freq_lp = signal.resample_poly(frequency, 1, 10)[20:-20]
    cv = float(np.std(env_lp)/max(mean, 1e-9))
    phase_coherence = float(abs(np.mean(z[1:]*np.conj(z[:-1]))) /
                            max(np.mean(abs(z[1:]*z[:-1])), 1e-12))
    p = abs(np.fft.fft(z * signal.windows.hann(len(z), sym=False)))**2
    spectral_concentration = float(np.sort(p)[-max(3, len(p)//50):].sum()/max(p.sum(), 1e-30))
    result.residual_hz = float(np.mean(freq_lp))
    # Use the transmitted LO, not the rounded RF estimate, for residual correction.
    result.carrier_hz = float(lo_hz + np.mean(freq_lp))
    centered_f = freq_lp - np.mean(freq_lp)
    dev = float((np.percentile(centered_f, 99)-np.percentile(centered_f, 1))/2)
    fm_tone = _tone_frequency(centered_f, rate/10)
    phase_noise = float(np.std(frequency - signal.savgol_filter(frequency, 31, 2)))
    am_metric = float((np.percentile(env_lp, 99)-np.percentile(env_lp, 1)) /
                      max(np.percentile(env_lp, 99)+np.percentile(env_lp, 1), 1e-12))
    # Wideband FM spreads energy across sidebands and can have low one-sample
    # phase coherence. Keep a constant-envelope path for broadcast FM while
    # retaining unknown for noise and an unmodulated carrier.
    narrowband_signal = phase_coherence >= .8 and spectral_concentration >= .55
    wideband_fm = (cv < .18 and phase_coherence >= .4
                   and dev > max(800.0, phase_noise*.75)
                   and spectral_concentration >= .03)
    narrowband_fm = (cv < .12 and phase_coherence >= .4 and dev > 150.0
                     and fm_tone is not None and spectral_concentration >= .03)
    # A narrow 19 kHz discriminator tone supports broadcast FM when fading
    # exceeds the constant-envelope limit. Mono FM still uses existing paths.
    stereo_fm = (not wideband_fm and cv < .28 and phase_coherence >= .8
                 and dev > max(800.0, phase_noise*.75)
                 and spectral_concentration >= .15 and _has_stereo_pilot(freq_lp, rate/10))
    if not narrowband_signal and not wideband_fm and not narrowband_fm and not stereo_fm:
        result.kind = "未知"
        result.reason = "噪声或不支持的调制"
        return result
    if clipped:
        result.kind, result.reason = "未知", "FPGA 报告削顶，参数不可信"
        return result
    if cv > .035 and am_metric > .05 and dev < max(500, phase_noise*.7):
        result.kind = "AM"
        result.confidence = float(np.clip(1-dev/max(1000, phase_noise), .5, .99))
        result.am_depth = am_metric
        result.modulation_hz = _tone_frequency(env_lp, rate/10)
    # Keep the qualified wideband path through final classification: real FM
    # can have more envelope variation than the narrowband 0.12 limit.
    elif wideband_fm or stereo_fm or (cv < .12 and (dev > max(150.0, phase_noise*.35) or fm_tone is not None)):
        result.kind = "FM"
        result.confidence = float(np.clip(1-cv*5, .5, .99))
        result.fm_deviation_hz = dev
        # Mid-percentile center limits finite-window bias for symmetric FM tones.
        result.residual_hz = float((np.percentile(freq_lp, 99)+np.percentile(freq_lp, 1))/2)
        result.carrier_hz = float(lo_hz + result.residual_hz)
        result.modulation_hz = fm_tone
        if result.modulation_hz:
            result.fm_index = dev/result.modulation_hz
    else:
        result.kind, result.reason = "未知", "载波 / 低调制度 / AM 与 FM 特征不明确"
    order = np.argsort(np.fft.fftfreq(len(z), 1/rate))
    cumulative = np.cumsum(p[order])/max(p.sum(), 1e-30)
    frequencies = np.fft.fftfreq(len(z), 1/rate)[order]
    low, high = np.searchsorted(cumulative, [.005, .995])
    result.occupied_hz = float(frequencies[min(high, len(z)-1)]-frequencies[low])
    return result


class Demodulator:
    """500 kIQ/s -> causal audio low-pass -> /5 -> rational 12/25 -> 48 kHz.

    Continuous FIR history is retained through both resampling stages. Every
    transport gap or epoch change resets this object and mutes its settling tail.
    """
    def __init__(self):
        self.lowpass = signal.firwin(161, 15_000, fs=IQ_RATE)
        self.audio_filter = signal.firwin(501, 19_000, fs=1_200_000)*12
        self.dc_sos = signal.butter(2, 35, "highpass", fs=AUDIO_RATE, output="sos")
        self.deemphasis = 0
        self.reset()

    def reset(self):
        self.kind = None
        self.previous = None
        self.lp_state = np.zeros(len(self.lowpass)-1)
        self.rate_state = np.zeros(len(self.audio_filter)-1)
        self.dc_state = np.zeros((len(self.dc_sos), 2))
        self.decimation_phase = 0
        self.resample_phase = 0
        self.deemphasis_state = np.zeros(1)
        self.envelope_state = None
        self.warmup = 960

    def process(self, z, kind):
        if self.kind != kind:
            self.reset()
            self.kind = kind
        if kind == "AM":
            env = np.abs(z)
            alpha = np.exp(-1/(IQ_RATE*.05))
            if self.envelope_state is None:
                self.envelope_state = np.array([env[0]*alpha])
            level, self.envelope_state = signal.lfilter([1-alpha], [1, -alpha], env, zi=self.envelope_state)
            raw = env/np.maximum(level, .001) - 1
        elif kind == "FM":
            previous = np.concatenate(([z[0] if self.previous is None else self.previous], z[:-1]))
            raw = np.angle(z*np.conj(previous))*IQ_RATE/(2*np.pi*75_000)
            self.previous = z[-1]
        else:
            raw = np.zeros(len(z))
        filtered, self.lp_state = signal.lfilter(self.lowpass, [1.0], raw, zi=self.lp_state)
        down = filtered[self.decimation_phase::5]
        self.decimation_phase = (self.decimation_phase - len(filtered)) % 5
        up = np.zeros(len(down)*12)
        up[::12] = down
        converted, self.rate_state = signal.lfilter(self.audio_filter, [1.0], up, zi=self.rate_state)
        audio = converted[self.resample_phase::25]
        self.resample_phase = (self.resample_phase - len(converted)) % 25
        audio, self.dc_state = signal.sosfilt(self.dc_sos, audio, zi=self.dc_state)
        if kind == "FM" and self.deemphasis:
            alpha = np.exp(-1/(AUDIO_RATE*self.deemphasis*1e-6))
            audio, self.deemphasis_state = signal.lfilter([1-alpha], [1, -alpha], audio, zi=self.deemphasis_state)
        mute = min(len(audio), self.warmup)
        audio[:mute] = 0
        self.warmup -= mute
        return audio.astype(np.float32)
