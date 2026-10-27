"""Evaluate inherited quantized compensation coefficients with the actual R87 CIC."""
import json
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT.parents[2] / ".harness/receiver_ads807/filter"


def main():
    coefficients = [int(text, 16) for text in (ROOT / "rtl/fir_coeff.hex").read_text().split()]
    coefficients = [(value+131072) % 262144-131072 for value in coefficients]
    grid = np.linspace(0, .5, 20001)
    fir = abs(sum(value/131072*np.exp(-2j*np.pi*grid*index)
                  for index, value in enumerate(coefficients)))
    cic = np.sinc(grid)**5 / np.sinc(grid/87)**5
    response = fir*cic
    passband = 20*np.log10(response[grid <= .2])
    stopband = 20*np.log10(np.maximum(response[grid >= .3], 1e-15))
    aliases = np.linspace(.8, 43.5, 300001)
    folded = abs((aliases+.5) % 1-.5)
    alias_response = abs(np.sin(np.pi*aliases)/(87*np.sin(np.pi*aliases/87)))**5
    alias_db = float(20*np.log10(max(alias_response[folded <= .2])))
    summary = {"cic_R": 87, "cic_gain": 87**5, "cic_width": 59, "cic_shift": 40,
        "adc_rate_hz": 43500000, "iq_rate_hz": 500000,
        "pass_min_db": float(min(passband)), "pass_max_db": float(max(passband)),
        "stop_max_db": float(max(stopband)), "fold_alias_max_db": alias_db,
        "evidence": "double precision response of quantized coefficients, not hardware",
        "fullscale_carrier_iq_amplitude": 2047*2047*(87**5)/2**40/2}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    assert max(abs(passband)) < .15 and max(stopband) < -65 and alias_db < -60
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
