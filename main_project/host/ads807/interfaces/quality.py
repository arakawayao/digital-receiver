"""Observe tuned IQ quality without searching for, or changing, the carrier."""
import numpy as np


def assess_iq(values):
    z = np.asarray(values, dtype=np.complex128)
    if len(z) < 1024 or not np.isfinite(z).all():
        return {"confident": False, "offset_hz": 0.0}
    power = np.mean(np.abs(z)**2)
    amplitude = np.abs(z)
    correlation = np.mean(z[1:]*z[:-1].conj())
    coherence = abs(correlation)/max(power, 1e-30)
    offset = np.angle(correlation)*500_000/(2*np.pi)
    # Broadband noise has low adjacent-sample coherence. This is a prototype
    # confidence indicator, not modulation classification or carrier acquisition.
    good = power > 32**2 and np.max(amplitude) < 46000 and coherence > .6
    return {"confident": bool(good), "offset_hz": float(offset)}
