"""Re-run the current classifier against saved real-I/Q captures."""
from collections import Counter
import argparse
import hashlib
import json
from pathlib import Path
import time

import numpy as np

from scipy.io import wavfile

from ads807.dsp import AUDIO_RATE, Demodulator, analyse
from ads807.protocol import ADC_RATE


CAPTURES = {
    "103.7_off": "capture_20261026_164238_735271",
    "103.7_75us": "capture_20261026_165140_813586",
    "103.7_50us": "capture_20261026_165226_885213",
    "93.4": "capture_20261026_181810_278439",
    "105.7": "capture_20261026_183124_208967",
    "90.9": "capture_20261026_183146_097221",
    "98.1": "capture_20261026_183159_811496",
}


def load_capture(root, name):
    directory = root / CAPTURES[name]
    metadata = json.loads((directory / "metadata.json").read_text(encoding="utf-8"))
    waveforms = np.load(directory / "waveforms.npz")
    iq = np.asarray(waveforms["iq"], dtype=np.complex128)
    rf_hz = 87_000_000 + metadata["transport_config"]["phase_step"]*ADC_RATE/2**32
    clipped = bool(metadata["integrity"]["clipped_frames"])
    return directory, metadata, iq, rf_hz, clipped


def replay(directory, metadata, app):
    from ads807.runtime import Controller
    from ads807.sources import SourceConfig

    controller = Controller()
    try:
        controller.set_deemphasis(metadata["deemphasis_us"])
        controller.start(SourceConfig("文件回放", path=str(directory / "transport.fcr")))
        deadline = time.monotonic() + 15
        last_progress, last_processed = time.monotonic(), -1
        while True:
            app.processEvents()
            processor = controller.processor
            if processor.error or controller.source.error:
                raise RuntimeError(processor.error or controller.source.error)
            if processor.processed != last_processed:
                last_progress, last_processed = time.monotonic(), processor.processed
            if (controller.source.ended and not processor.receiver.is_alive()
                    and processor.receiver.batches.empty() and processor.display(20) is not None
                    and time.monotonic() - last_progress >= .15):
                break
            if time.monotonic() > deadline:
                raise TimeoutError(str(directory))
            time.sleep(.005)
        snapshot = processor.capture()
        audio = snapshot["audio"]
        return {"kind": snapshot["measurement"]["kind"], "processed_samples": processor.processed,
                "audio_rms": float(np.sqrt(np.mean(audio*audio))),
                "audio_zero_fraction": float(np.mean(audio == 0)),
                "crc_errors": processor.decoder.crc_errors,
                "continuity_gaps": processor.continuity.gaps, "error": processor.error,
                "classification": processor.stats()["classification"],
                "note": "transport ring and saved I/Q history can cover different time windows",
                "physical_audio_tested": False}
    finally:
        controller.shutdown()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures-root", type=Path, required=True)
    parser.add_argument("--replay", action="store_true")
    args = parser.parse_args()
    if args.replay:
        from PyQt6.QtCore import QCoreApplication
        app = QCoreApplication([])
    report = {"scope": "current ads807.dsp.analyse on saved I/Q; no new RF validation",
              "dsp_sha256": hashlib.sha256(Path("ads807/dsp.py").read_bytes()).hexdigest(),
              "runtime_sha256": hashlib.sha256(Path("ads807/runtime.py").read_bytes()).hexdigest(),
              "captures": []}
    for name in CAPTURES:
        directory, metadata, iq, rf_hz, clipped = load_capture(args.captures_root, name)
        block = 20_000
        results = [analyse(iq[start:start + block], rf_hz, clipped=clipped)
                   for start in range(0, len(iq) - block + 1, block)]
        counts = Counter(result.kind for result in results)
        demodulator = Demodulator()
        demodulator.deemphasis = metadata["deemphasis_us"]
        audio = np.concatenate([demodulator.process(iq[start:start + block], result.kind)
                                for start, result in zip(range(0, len(iq) - block + 1, block), results)])
        if name == "105.7":
            wavfile.write(str(Path(__file__).with_name("1057MHz_recovered.wav")),
                          AUDIO_RATE, (np.clip(audio, -1, 1)*32767).astype(np.int16))
        if name == "98.1":
            diagnostic = Demodulator()
            diagnostic.deemphasis = 50
            diagnostic_audio = np.concatenate([diagnostic.process(iq[start:start + block], "FM")
                                              for start in range(0, len(iq) - block + 1, block)])
            wavfile.write(str(Path(__file__).with_name("981MHz_diagnostic_forced_fm.wav")),
                          AUDIO_RATE, (np.clip(diagnostic_audio, -1, 1)*32767).astype(np.int16))
        report["captures"].append({
            "rf_mhz": name,
            "capture": directory.name,
            "npz_sha256": hashlib.sha256((directory / "waveforms.npz").read_bytes()).hexdigest(),
            "samples": int(len(iq)),
            "blocks_40ms": len(results),
            "classifications_40ms": dict(sorted(counts.items())),
            "mean_level_dbfs": float(np.mean([result.level_dbfs for result in results])),
            "deviation_hz": [float(result.fm_deviation_hz) for result in results if result.fm_deviation_hz is not None],
            "audio_rms": float(np.sqrt(np.mean(audio * audio))) if len(audio) else 0.0,
            "audio_zero_fraction": float(np.mean(audio == 0)) if len(audio) else 1.0,
            "integrity": {key: metadata["integrity"].get(key) for key in (
                "crc_errors", "header_errors", "continuity_gaps", "missing_samples",
                "clipped_frames", "fpga_dropped", "dsp_dropped_samples", "audio_underruns", "audio_overruns")},
            "original_measurement": metadata["measurement"],
        })
        if args.replay and name in ("105.7", "90.9", "98.1"):
            report["captures"][-1]["transport_replay"] = replay(directory, metadata, app)
    output = Path(__file__).with_name("latest_reanalysis.json")
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    for capture in report["captures"]:
        print(capture["rf_mhz"], capture["classifications_40ms"], capture.get("transport_replay", ""))
    print(output)


if __name__ == "__main__":
    main()
