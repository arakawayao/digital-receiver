"""Decode actual RTL FX2 output with the production GUI parser; no hardware access."""
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[2]
sys.path.insert(0, str(PROJECT))
from host.ads807.protocol import Decoder, Frame


def main():
    output = PROJECT/".harness/receiver_ads807_dual/simulation"
    raw = bytes(int(x, 16) for x in (output/"dual_bytes.txt").read_text().split())
    decoder = Decoder()
    records = []
    for offset in range(0, len(raw), 71):
        records.extend(decoder.feed(raw[offset:offset+71]))
    # A finite pin trace may stop partway through the next 512-byte frame.
    tail = raw[len(raw)//512*512:]
    assert bytes(decoder.buffer) == tail
    assert tail[:4] == b"TRI1"[:len(tail[:4])]
    if len(tail) >= 16:
        assert struct.unpack_from("<I", tail, 12)[0] == len(records)
    assert not (decoder.crc_errors or decoder.header_errors or decoder.discarded_bytes or decoder.transport_gaps)
    iq = [r for r in records if isinstance(r, Frame)]
    acks = [r for r in records if not isinstance(r, Frame)]
    assert len(acks) == 24 and all(a.kind == 3 for a in acks)
    assert {f.flags & 3 for f in iq} == {1, 2}
    assert sum(len(f.samples) for f in iq) > 1000
    result = dict(status="PASS", frames=len(records), iq_frames=len(iq), ack_frames=len(acks),
                  samples=sum(len(f.samples) for f in iq), decoder="host.ads807.protocol.Decoder",
                  source="Actual Intel IP / FX2 pin simulation", usb_tested=False,
                  trailing_inflight_bytes=len(tail))
    (output/"host_crosscheck.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
