"""Deterministic synthetic baseband fixtures, not a production receiver."""

import argparse
import math
from pathlib import Path

from .iq import validate_capture, write_capture


def make_capture(kind):
    """Build 4800 samples of AM, FM, or silence with known test truth."""
    if kind not in ("am", "fm", "silence"):
        raise ValueError("kind must be am, fm, or silence")
    sample_rate = 48_000
    count = 4_800
    tone = 1_000
    amplitude = 0.5
    modulation_depth = 0.6
    deviation = 2_000
    phase = 0.0
    samples = []
    for index in range(count):
        message = math.cos(2 * math.pi * tone * index / sample_rate)
        if kind == "am":
            samples.append([amplitude * (1 + modulation_depth * message), 0.0])
        elif kind == "fm":
            samples.append([amplitude * math.cos(phase), amplitude * math.sin(phase)])
            phase += 2 * math.pi * deviation * message / sample_rate
        else:
            samples.append([0.0, 0.0])
    truth = {
        "kind": kind,
        "sample_count": count,
        "baseband_carrier_offset_hz": 0,
        "noise": "none",
        "generator": "reference.fixtures.v1",
        "purpose": "offline_test_only",
    }
    if kind != "silence":
        truth.update(amplitude=amplitude, audio_tone_hz=tone)
    if kind == "am":
        truth["modulation_depth"] = modulation_depth
    if kind == "fm":
        truth.update(frequency_deviation_hz=deviation, initial_phase_rad=0.0)
    capture = {
        "schema_version": 1,
        "sample_rate_hz": sample_rate,
        "center_frequency_hz": 100_000_000,
        "iq_format": "normalized_float",
        "samples": samples,
        "metadata": {"truth": truth},
    }
    validate_capture(capture)
    return capture


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for kind in ("am", "fm", "silence"):
        destination = args.output_dir / f"{kind}.json"
        write_capture(destination, make_capture(kind))
        print(destination)


if __name__ == "__main__":
    main()
