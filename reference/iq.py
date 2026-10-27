"""Versioned offline IQ capture validation and UTF-8 JSON I/O."""

import json
import math
from pathlib import Path


def _number(value, label):
    if type(value) not in (int, float):
        raise ValueError(f"{label} must be a finite real number")
    try:
        finite = math.isfinite(value)
    except OverflowError:
        finite = False
    if not finite:
        raise ValueError(f"{label} must be a finite real number")


def validate_capture(capture):
    """Raise ValueError for an invalid v1 capture; return None on success."""
    if not isinstance(capture, dict):
        raise ValueError("capture must be a JSON object")
    required = {
        "schema_version", "sample_rate_hz", "center_frequency_hz",
        "iq_format", "samples",
    }
    missing = required - capture.keys()
    if missing:
        raise ValueError(f"missing capture fields: {sorted(missing)}")
    if set(capture) - required - {"metadata"}:
        raise ValueError("unexpected capture fields; put annotations in metadata")
    if type(capture["schema_version"]) is not int or capture["schema_version"] != 1:
        raise ValueError("schema_version must be integer 1")
    for field in ("sample_rate_hz", "center_frequency_hz"):
        _number(capture[field], field)
    if capture["sample_rate_hz"] <= 0:
        raise ValueError("sample_rate_hz must be positive")
    if not 88_000_000 <= capture["center_frequency_hz"] <= 108_000_000:
        raise ValueError("center_frequency_hz must be within 88 MHz to 108 MHz")
    if capture["iq_format"] != "normalized_float":
        raise ValueError("iq_format must be normalized_float")
    samples = capture["samples"]
    if not isinstance(samples, list) or not samples:
        raise ValueError("samples must be a non-empty list")
    for index, pair in enumerate(samples):
        if not isinstance(pair, list) or len(pair) != 2:
            raise ValueError(f"samples[{index}] must contain exactly [I, Q]")
        for component, value in zip(("I", "Q"), pair):
            label = f"samples[{index}].{component}"
            _number(value, label)
            if not -1 <= value <= 1:
                raise ValueError(f"{label} must be within [-1, 1]")
    if "metadata" in capture:
        if not isinstance(capture["metadata"], dict):
            raise ValueError("metadata must be an object")
        _validate_json(capture["metadata"])


def _validate_json(value):
    if value is None or type(value) in (str, bool):
        return
    if type(value) in (int, float):
        _number(value, "metadata number")
    elif isinstance(value, list):
        for item in value:
            _validate_json(item)
    elif isinstance(value, dict):
        for key, item in value.items():
            if not isinstance(key, str):
                raise ValueError("metadata object keys must be strings")
            _validate_json(item)
    else:
        raise ValueError("metadata must contain JSON-compatible values")


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON field: {key}")
        result[key] = value
    return result


def read_capture(path):
    """Read UTF-8 JSON and validate it; preserve filesystem errors."""
    with Path(path).open("r", encoding="utf-8") as stream:
        capture = json.load(stream, object_pairs_hook=_object)
    validate_capture(capture)
    return capture


def write_capture(path, capture):
    """Validate before opening the destination; overwrite an existing capture."""
    validate_capture(capture)
    content = json.dumps(capture, ensure_ascii=False, allow_nan=False, indent=2)
    Path(path).write_text(content + "\n", encoding="utf-8")
