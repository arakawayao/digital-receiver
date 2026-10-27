"""Receive live FCR1 I/Q frames from the receiver56 ADC build (EP2 IN only).

This utility does not upload replay samples or issue FX2 firmware commands.
It captures 32 MS/s ADC-build output, checks framing/continuity, estimates the
1 kHz AM envelope depth, and writes CSV, JSON, and a dependency-free SVG plot.
"""
import argparse
import csv
import json
import math
import struct
import time
import zlib
from pathlib import Path

from ...paths import ARTIFACT_ROOT

from .usb_transport import EP_IN, TransferTimeout, open_transport

BLOCK = 512
HEADER = 60
SAMPLE_RATE = 500_000
EXPECTED_ADC_RATE = 32_000_000


class FCR1Decoder:
    def __init__(self):
        self.buffer = bytearray()
        self.bad_crc = 0
        self.discarded = 0

    def feed(self, data):
        self.buffer.extend(data)
        frames = []
        while True:
            pos = self.buffer.find(b"FCR1")
            if pos < 0:
                keep = min(3, len(self.buffer))
                self.discarded += len(self.buffer) - keep
                if keep:
                    del self.buffer[:-keep]
                break
            self.discarded += pos
            del self.buffer[:pos]
            if len(self.buffer) < BLOCK:
                break
            packet = bytes(self.buffer[:BLOCK])
            expected_crc = struct.unpack_from("<I", packet, 508)[0]
            if zlib.crc32(packet[:508]) != expected_crc:
                self.bad_crc += 1
                self.discarded += 1
                del self.buffer[0]
                continue
            words = struct.unpack_from("<15I", packet)
            if (words[1] != 0x003C0003 or words[5] < 1 or words[5] > 112
                    or words[8] != SAMPLE_RATE):
                self.discarded += 1
                del self.buffer[0]
                continue
            del self.buffer[:BLOCK]
            frames.append((words, packet))
        return frames


def capture_frames(args):
    if args.vid is None or args.pid is None:
        raise ValueError("--vid and --pid are required")
    transport = open_transport(args.vid, args.pid, args.backend, args.interface, args.cyusb_dll)
    decoder = FCR1Decoder()
    frames = []
    deadline = time.monotonic() + args.timeout
    print(json.dumps(transport.describe(), indent=2), flush=True)
    print(f"Waiting for live FCR1 I/Q frames ({args.frames} frames; timeout {args.timeout:g}s)...", flush=True)
    try:
        while len(frames) < args.frames and time.monotonic() < deadline:
            try:
                data = transport.read(EP_IN, BLOCK, timeout=min(1000, max(1, int((deadline-time.monotonic())*1000))))
            except TransferTimeout:
                continue
            for record in decoder.feed(bytes(data)):
                frames.append(record)
                if len(frames) == 1 or len(frames) % 16 == 0:
                    print(f"Received {len(frames)}/{args.frames} FCR1 frames", flush=True)
                if len(frames) >= args.frames:
                    break
    finally:
        transport.close()
    if len(frames) != args.frames:
        raise RuntimeError(f"Timed out after receiving {len(frames)}/{args.frames} frames. "
                           "Check ADC lock, FPGA SOF, FX2 EP2 IN firmware/IFCLK, and USB connection.")
    if decoder.bad_crc:
        raise RuntimeError(f"USB capture had {decoder.bad_crc} invalid FCR1 CRC(s)")
    return frames, decoder.discarded


def decode_capture(frames, expected_adc_rate):
    rows = []
    first = frames[0][0]
    epoch, rate = first[3], first[7]
    if rate != expected_adc_rate:
        raise ValueError(f"FCR1 reports ADC rate {rate} Hz, expected {expected_adc_rate} Hz; "
                         "ensure receiver56.sof is loaded")
    sequence = first[2]
    next_index = first[4]
    for words, packet in frames:
        if words[3] != epoch:
            raise ValueError("Stream epoch changed during capture")
        if words[2] != sequence or words[4] != next_index:
            raise ValueError(f"I/Q discontinuity at frame {words[2]}: expected frame {sequence}, "
                             f"sample {next_index}; restart stream and capture again")
        # The FPGA's dropped counter is cumulative since stream start. It may
        # already be nonzero before the host connects; sample-index continuity
        # above detects losses that occur within this capture.
        if words[11] & 4:
            raise ValueError(f"DSP clipping flag set in frame {words[2]}")
        for n in range(words[5]):
            i_value, q_value = struct.unpack_from("<hh", packet, HEADER + 4*n)
            index = words[4] + n
            rows.append((index, i_value, q_value, words[9], words[10], words[11]))
        sequence += 1
        next_index += words[5]
    return rows, epoch, rate


def fit_am(rows, modulation_hz, settle_samples):
    stable = [(index, math.hypot(i_value, q_value)) for index, i_value, q_value, *_ in rows
              if index >= settle_samples]
    required_span = 4 * SAMPLE_RATE / modulation_hz
    if len(stable) < 4 or stable[-1][0]-stable[0][0] < required_span:
        raise ValueError("Capture is too short for AM analysis; increase --frames to capture at least four modulation periods")
    omega = math.tau * modulation_hz / SAMPLE_RATE
    # Least-squares fit env = dc + a*cos(wt) + b*sin(wt), including DC removal.
    n = len(stable)
    c = sum(math.cos(omega*idx) for idx, _ in stable)
    s = sum(math.sin(omega*idx) for idx, _ in stable)
    cc = sum(math.cos(omega*idx)**2 for idx, _ in stable)
    ss = sum(math.sin(omega*idx)**2 for idx, _ in stable)
    cs = sum(math.cos(omega*idx)*math.sin(omega*idx) for idx, _ in stable)
    y = sum(value for _, value in stable)
    yc = sum(value*math.cos(omega*idx) for idx, value in stable)
    ys = sum(value*math.sin(omega*idx) for idx, value in stable)
    # Solve the 3x3 normal equations with pivoted Gaussian elimination.
    matrix = [[n, c, s, y], [c, cc, cs, yc], [s, cs, ss, ys]]
    for col in range(3):
        pivot = max(range(col, 3), key=lambda row: abs(matrix[row][col]))
        if abs(matrix[pivot][col]) < 1e-12:
            raise ValueError("Cannot fit AM envelope at this modulation frequency")
        matrix[col], matrix[pivot] = matrix[pivot], matrix[col]
        scale = matrix[col][col]
        matrix[col] = [v/scale for v in matrix[col]]
        for row in range(3):
            if row == col:
                continue
            factor = matrix[row][col]
            matrix[row] = [a-factor*b for a, b in zip(matrix[row], matrix[col])]
    dc, a, b = (matrix[i][3] for i in range(3))
    ac = math.hypot(a, b)
    depth = ac/dc if dc else float("inf")
    residual = [value-(dc+a*math.cos(omega*idx)+b*math.sin(omega*idx)) for idx, value in stable]
    residual_rms = math.sqrt(sum(x*x for x in residual)/len(residual))
    fit_quality = 1-residual_rms**2/(sum((v-dc)**2 for _,v in stable)/len(stable) or 1)
    signal_rms = math.sqrt(sum(value*value for _, value in stable)/n)
    return stable, dict(modulation_hz=modulation_hz, mean_envelope=dc, fitted_ac_amplitude=ac,
                        estimated_modulation_depth=depth, residual_rms=residual_rms,
                        fit_r_squared=fit_quality, envelope_points=len(stable),
                        fitted_signal_rms=signal_rms, fitted_phase_rad=math.atan2(b, a))


def write_outputs(out, frames, rows, stable, am, expected_depth, expected_rf, rf_tolerance,
                  discarded, adc_rate, modulation_hz):
    out.mkdir(parents=True, exist_ok=True)
    with (out / "iq.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(("sample_index", "time_s", "i", "q", "envelope", "rf_estimate_hz", "phase_step", "flags"))
        stable_indices = {idx: env for idx, env in stable}
        for idx, i_value, q_value, rf, phase, flags in rows:
            writer.writerow((idx, f"{idx/SAMPLE_RATE:.9f}", i_value, q_value,
                             f"{stable_indices[idx]:.6f}" if idx in stable_indices else f"{math.hypot(i_value,q_value):.6f}",
                             rf, phase, flags))
    rf_values = [words[9] for words, _ in frames]
    estimated_rf = rf_values[-1]
    rf_ok = all(abs(value-expected_rf) <= rf_tolerance for value in rf_values)
    depth_error = abs(am["estimated_modulation_depth"]-expected_depth)
    depth_ok = depth_error <= 0.08
    waveform_ok = am["fit_r_squared"] >= 0.5
    result = dict(status="PASS" if rf_ok and depth_ok and waveform_ok else "CHECK",
                  adc_rate_hz=adc_rate, iq_rate_hz=SAMPLE_RATE, frame_count=len(frames),
                  sample_count=len(rows), epoch=frames[0][0][3], usb_discarded_bytes=discarded,
                  rf_estimate_hz=estimated_rf, rf_min_hz=min(rf_values), rf_max_hz=max(rf_values),
                  expected_rf_hz=expected_rf,
                  rf_tolerance_hz=rf_tolerance, rf_check="PASS" if rf_ok else "CHECK",
                  **am, expected_modulation_depth=expected_depth,
                  modulation_depth_error=depth_error,
                  am_depth_check="PASS" if depth_ok else "CHECK",
                  am_modulation_fit_check="PASS" if waveform_ok else "CHECK",
                  note="For a 2 MHz real input at 32 MS/s, the receiver's negative-alias mapping reports approximately 94 MHz.")
    (out / "result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    write_svg(out / "iq_envelope.svg", rows, stable, am, modulation_hz)
    print(json.dumps(result, indent=2), flush=True)


def write_svg(path, rows, stable, am, modulation_hz):
    width, height = 1500, 900
    left, right = 90, 1450
    panel_top, panel_h = (70, 330), (500, 320)
    stride = max(1, len(rows)//2400)
    shown = rows[::stride]
    x_min, x_max = rows[0][0], rows[-1][0]
    peak = max(1, max(abs(v) for row in shown for v in (row[1], row[2])))
    env_min, env_max = min(v for _, v in stable), max(v for _, v in stable)
    env_pad = max(1.0, (env_max-env_min)*0.15)
    ey0, ey1 = env_min-env_pad, env_max+env_pad
    def xmap(idx): return left+(idx-x_min)*((right-left)/max(1,x_max-x_min))
    def ymap(value, top, ph, low, high): return top+ph-(value-low)*ph/(high-low or 1)
    def poly(points): return " ".join(f"{x:.1f},{y:.1f}" for x,y in points)
    i_points=[(xmap(r[0]),ymap(r[1],*panel_top,-peak,peak)) for r in shown]
    q_points=[(xmap(r[0]),ymap(r[2],*panel_top,-peak,peak)) for r in shown]
    env_points=[(xmap(idx),ymap(env,*panel_h,ey0,ey1)) for idx,env in stable[::max(1,len(stable)//2400)]]
    omega=math.tau*modulation_hz/SAMPLE_RATE
    # Recover fitted phase from least-squares samples for an overlay.
    candidates=[(idx,env) for idx,env in stable]
    c=sum(math.cos(omega*idx) for idx,_ in candidates); s=sum(math.sin(omega*idx) for idx,_ in candidates)
    cc=sum(math.cos(omega*idx)**2 for idx,_ in candidates); ss=sum(math.sin(omega*idx)**2 for idx,_ in candidates)
    cs=sum(math.cos(omega*idx)*math.sin(omega*idx) for idx,_ in candidates)
    yc=sum(env*math.cos(omega*idx) for idx,env in candidates); ys=sum(env*math.sin(omega*idx) for idx,env in candidates)
    y=sum(env for _,env in candidates); n=len(candidates)
    m=[[n,c,s,y],[c,cc,cs,yc],[s,cs,ss,ys]]
    for col in range(3):
        pivot=max(range(col,3),key=lambda row:abs(m[row][col]));m[col],m[pivot]=m[pivot],m[col]
        div=m[col][col];m[col]=[v/div for v in m[col]]
        for row in range(3):
            if row!=col:
                fac=m[row][col];m[row]=[a-fac*b for a,b in zip(m[row],m[col])]
    a,b=m[1][3],m[2][3]
    ref_points=[(xmap(idx),ymap(am["mean_envelope"]+a*math.cos(omega*idx)+b*math.sin(omega*idx),*panel_h,ey0,ey1)) for idx,_ in stable[::max(1,len(stable)//2400)]]
    text=(f"ADC to I/Q capture — {modulation_hz:g} Hz AM | fitted depth {am['estimated_modulation_depth']*100:.1f}% | R² {am['fit_r_squared']:.3f}")
    svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
         '<rect width="100%" height="100%" fill="white"/>',
         '<style>text{font-family:Segoe UI,Arial,sans-serif;fill:#222}.axis{stroke:#555;stroke-width:1}.grid{stroke:#ddd;stroke-width:1}.i{fill:none;stroke:#1565c0;stroke-width:1.2}.q{fill:none;stroke:#ef6c00;stroke-width:1.2}.env{fill:none;stroke:#2e7d32;stroke-width:1.4}.fit{fill:none;stroke:#c62828;stroke-width:1.5;stroke-dasharray:7 5}</style>',
         f'<text x="{left}" y="32" font-size="21">{text}</text>',
         f'<text x="{left}" y="58" font-size="14">Top: signed I (blue) / Q (orange); bottom: |I+jQ| envelope (green) and fitted {modulation_hz:g} Hz model (red dashed)</text>']
    for top,ph,low,high,title in [(panel_top[0],panel_top[1],-peak,peak,"I and Q samples"),(panel_h[0],panel_h[1],ey0,ey1,"Baseband envelope")]:
        for k in range(5):
            yy=top+ph*k/4
            svg.append(f'<line class="grid" x1="{left}" y1="{yy:.1f}" x2="{right}" y2="{yy:.1f}"/>')
        svg.append(f'<line class="axis" x1="{left}" y1="{top}" x2="{left}" y2="{top+ph}"/><line class="axis" x1="{left}" y1="{top+ph}" x2="{right}" y2="{top+ph}"/>')
        svg.append(f'<text x="{left}" y="{top-8}" font-size="16">{title}</text>')
    svg.append(f'<polyline class="i" points="{poly(i_points)}"/><polyline class="q" points="{poly(q_points)}"/>')
    svg.append(f'<polyline class="env" points="{poly(env_points)}"/><polyline class="fit" points="{poly(ref_points)}"/>')
    duration_ms=(x_max-x_min)/SAMPLE_RATE*1000
    for k in range(6):
        x=left+(right-left)*k/5
        label=f"{duration_ms*k/5:.1f} ms"
        svg.append(f'<line class="grid" x1="{x:.1f}" y1="{panel_top[0]}" x2="{x:.1f}" y2="{panel_top[0]+panel_top[1]}"/>')
        svg.append(f'<line class="grid" x1="{x:.1f}" y1="{panel_h[0]}" x2="{x:.1f}" y2="{panel_h[0]+panel_h[1]}"/>')
        svg.append(f'<text x="{x-20:.1f}" y="{panel_h[0]+panel_h[1]+24}" font-size="12">{label}</text>')
    svg.append(f'<text x="{left}" y="{panel_h[0]+panel_h[1]+58}" font-size="14">Time from capture start (ms), I/Q output at 500 kS/s</text>')
    svg.append('<text x="105" y="475" font-size="14" fill="#1565c0">I</text><text x="130" y="475" font-size="14" fill="#ef6c00">Q</text>')
    svg.append('</svg>')
    path.write_text("\n".join(svg), encoding="utf-8")


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gui", action="store_true", help="Open the continuous live I/Q viewer")
    parser.add_argument("--vid", type=lambda value:int(value,0))
    parser.add_argument("--pid", type=lambda value:int(value,0))
    parser.add_argument("--backend", choices=("auto","cyusb","pyusb"), default="auto")
    parser.add_argument("--interface", type=int, default=0)
    parser.add_argument("--cyusb-dll", type=Path)
    parser.add_argument("--frames", type=int, default=128, help="FCR1 frames; 128 is about 28.7 ms at 500 kS/s")
    parser.add_argument("--timeout", type=float, default=30)
    parser.add_argument("--modulation-hz", type=float, default=1000)
    parser.add_argument("--expected-depth", type=float, default=.54, help="Expected AM modulation index (default: prior 54%% setup)")
    parser.add_argument("--expected-rf", type=float, default=94_000_000, help="Expected reported RF Hz for 2 MHz input at 32 MS/s")
    parser.add_argument("--rf-tolerance", type=float, default=12_000)
    parser.add_argument("--expected-adc-rate", type=int, default=EXPECTED_ADC_RATE)
    parser.add_argument("--output", type=Path, default=ARTIFACT_ROOT / "legacy/receiver_v2/live_adc")
    args=parser.parse_args()
    if args.gui:
        from .usb_capture_gui import main as gui_main
        gui_main()
        return
    if args.vid is None or args.pid is None:
        parser.error("--vid and --pid are required unless --gui is selected")
    if args.frames<20: parser.error("--frames must be at least 20 to evaluate 1 kHz modulation")
    if args.timeout<=0 or args.modulation_hz<=0: parser.error("--timeout and --modulation-hz must be positive")
    if not 0<args.expected_depth<1: parser.error("--expected-depth must be between 0 and 1")
    frames,discarded=capture_frames(args)
    rows,epoch,adc_rate=decode_capture(frames,args.expected_adc_rate)
    stable,am=fit_am(rows,args.modulation_hz,32)
    write_outputs(args.output,frames,rows,stable,am,args.expected_depth,args.expected_rf,
                  args.rf_tolerance,discarded,adc_rate,args.modulation_hz)
    print(f"Saved iq.csv, result.json, and iq_envelope.svg under {args.output.resolve()}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError) as error:
        raise SystemExit(str(error))
