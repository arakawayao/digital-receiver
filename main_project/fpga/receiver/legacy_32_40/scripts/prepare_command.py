"""Prepare EP6 payload; do not guess the RF from a single alias spectrum."""
import argparse
import json
import struct
from pathlib import Path


def tuning(rf,rate,half_bandwidth=100000,guard=50000):
    if rate not in (32000000,40000000) or not 88000000<=rf<=108000000:
        raise ValueError("unsupported rate or RF range")
    alias=(rf+rate/2)%rate-rate/2
    lo=abs(alias)
    if min(lo,rate/2-lo)<half_bandwidth+guard:
        raise ValueError("complete signal band crosses the folding guard; select other build")
    return round(lo/rate*2**32),int(alias<0)


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--rf-hz",type=int,required=True)
    p.add_argument("--rate",type=int,choices=(32000000,40000000),required=True)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    step,conjugate=tuning(a.rf_hz,a.rate)
    a.output.write_bytes(struct.pack("<4sIII",b"RCF1",step,a.rf_hz,conjugate))
    print(json.dumps(dict(rf_hz=a.rf_hz,adc_rate=a.rate,phase_step=step,conjugate=conjugate,
          endpoint="0x06 OUT",pause="vendor A8, send 16 bytes, wait >=1ms, vendor A9")))
