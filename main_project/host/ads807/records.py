"""Portable capture bundles with full-rate IQ, decoded audio and transport bytes."""
from datetime import datetime
import json
from pathlib import Path
import wave

import numpy as np

from .dsp import AUDIO_RATE
from .protocol import IQ_RATE


def save_capture(parent, snapshot):
    parent = Path(parent)
    parent.mkdir(parents=True, exist_ok=True)
    path = parent / datetime.now().strftime("capture_%Y%m%d_%H%M%S_%f")
    path.mkdir()
    iq = snapshot["iq"]
    audio = snapshot["audio"]
    np.savez_compressed(path/"waveforms.npz", iq=iq, sample_index=snapshot["indices"],
                        demodulated=audio, iq_rate_hz=IQ_RATE, audio_rate_hz=AUDIO_RATE)
    np.savetxt(path/"iq.csv", np.column_stack((snapshot["indices"], iq.real, iq.imag)),
               delimiter=",", header="sample_index,i_normalized,q_normalized", comments="",
               fmt=["%d", "%.8f", "%.8f"])
    with wave.open(str(path/"demodulated.wav"), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(AUDIO_RATE)
        output.writeframes((np.clip(audio, -1, 1)*32767).astype("<i2").tobytes())
    (path/"transport.fcr").write_bytes(snapshot["raw"])
    metadata = {"schema_version": 1, "saved_at": datetime.now().astimezone().isoformat(),
                "source": snapshot["source"], "measurement": snapshot["measurement"],
                "source_config": snapshot["source_config"], "transport_config": snapshot["transport_config"],
                "integrity": snapshot["stats"], "iq_rate_hz": IQ_RATE,
                "audio_rate_hz": AUDIO_RATE, "iq_format": "I+jQ, signed16 / 32768",
                "iq_samples": len(iq), "audio_samples": len(audio),
                "index_start": int(snapshot["indices"][0]), "index_end": int(snapshot["indices"][-1]),
                "epoch": snapshot["epoch"], "audio_filter": "15 kHz LPF, 35 Hz HPF, mono 48 kHz",
                "deemphasis_us": snapshot["deemphasis"],
                "demodulation": snapshot.get("demodulation", {"mode": "auto", "forced": False,
                                                               "kind": snapshot["measurement"]["kind"]}),
                "notes": ["Only the latest continuous segment is saved; bounded history is at most 2 seconds.",
                          "transport.fcr can include leading/trailing packet samples outside the IQ window.",
                          "Audio has causal filter delay and settling silence; WAV amplitude is not calibrated voltage.",
                          "Heuristic modulation labels and percentile depths are estimates, not calibrated acceptance results."]}
    (path/"metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    return path
