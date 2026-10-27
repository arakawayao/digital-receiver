"""Compare r4/r5 confirmation on real 40 ms I/Q blocks, without USB/audio I/O."""
import argparse
from collections import Counter
import json
from pathlib import Path
import queue

import numpy as np
from PyQt6.QtCore import QCoreApplication
from scipy.io import wavfile

from ads807.audio import AudioOutput
from ads807.dsp import AUDIO_RATE, Demodulator
from ads807.protocol import ADC_RATE
from ads807.runtime import Processing
from ads807.sources import Acquisition, SourceConfig


def compare(directory):
    metadata = json.loads((directory / "metadata.json").read_text(encoding="utf-8"))
    z = np.load(directory / "waveforms.npz")["iq"]
    lo = 87_000_000 + metadata["transport_config"]["phase_step"]*ADC_RATE/2**32
    ingress = queue.Queue(128)
    processor = Processing(ingress, Acquisition(SourceConfig("文件回放"), ingress), AudioOutput())
    previous = Demodulator()
    previous.deemphasis = processor.demodulator.deemphasis = metadata["deemphasis_us"]
    before, after, old_kinds, new_kinds, raw_kinds, held = [], [], [], [], [], []
    for start in range(0, len(z)-20000+1, 20000):
        values = z[start:start+20000]
        processor.measure(values, lo, bool(metadata["integrity"]["clipped_frames"]))
        raw_kinds.append(processor.candidate)
        # r4 muted any valid candidate that differed from the confirmed kind.
        old_kind = (processor.candidate if processor.current_kind == processor.candidate else "未知")
        old_kinds.append(old_kind)
        new_kinds.append(processor.result.kind)
        before.append(previous.process(values, old_kind))
        after.append(processor.demodulator.process(values, processor.result.kind))
        if processor.result.reason.startswith("候选"):
            held.append({"start_sample": start, "reason": processor.result.reason})
    before, after = np.concatenate(before), np.concatenate(after)
    if held:
        wavfile.write(str(Path(__file__).with_name("909MHz_continuity_r5.wav")), AUDIO_RATE,
                      (np.clip(after, -1, 1)*32767).astype(np.int16))
    return {"capture": directory.name, "rf_hz": metadata["source_config"]["rf_hz"],
            "raw_candidates": dict(Counter(raw_kinds)), "r4_demod_kinds": dict(Counter(old_kinds)),
            "r5_demod_kinds": dict(Counter(new_kinds)), "held": held,
            "r4_audio_zero_fraction": float(np.mean(before == 0)),
            "r5_audio_zero_fraction": float(np.mean(after == 0)),
            "classification": processor.stats()["classification"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures-root", type=Path, required=True)
    args = parser.parse_args()
    app = QCoreApplication([])
    report = {"scope": "all saved 40 ms blocks analysed; live rate-limited scheduling may differ",
              "hardware_retest": False, "physical_audio_tested": False,
              "captures": [compare(directory) for directory in sorted(args.captures_root.glob("capture_20261026_*"))]}
    output = Path(__file__).with_name("continuity_r5.json")
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=True, indent=2))


if __name__ == "__main__":
    main()
