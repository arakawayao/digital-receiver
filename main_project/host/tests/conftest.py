"""Keep explicit pytest temporary directories usable in a fresh checkout."""
from pathlib import Path


def pytest_configure(config):
    if config.option.basetemp:
        Path(config.option.basetemp).resolve().parent.mkdir(parents=True, exist_ok=True)
