"""EP6 OUT simulated ADC upload -> FPGA DDC -> EP2 IN IQ. Offline generation needs stdlib only."""
import argparse
import cmath
import csv
import json
import math
from pathlib import Path

from ...paths import ARTIFACT_ROOT
import struct
import time
import zlib

FS=56000000
IQ_RATE=500000
CAPACITY=8192
BEGIN,DATA,START,STOP=1,2,3,4


def command(op,sequence,argument=0,samples=()):
    if len(samples)>240:raise ValueError("At most 240 ADC samples per command")
    if any(not 0<=v<=4095 for v in samples):raise ValueError("ADC codes must be 0..4095")
    frame=bytearray(512)
    struct.pack_into("<4sHH5I",frame,0,b"RPL1",1,op,sequence,argument,len(samples),0,0)
    for n,value in enumerate(samples):struct.pack_into("<H",frame,28+2*n,value)
    struct.pack_into("<I",frame,508,zlib.crc32(frame[:508]))
    return bytes(frame)


def waveform(kind="am",requested_rf=100700000,length=8192,modulation=.5,deviation=25000,mod_bin=1):
    if not 256<=length<=CAPACITY:raise ValueError("Pattern length must be 256..8192")
    if kind not in ("tone","am","fm"):raise ValueError("Unknown waveform")
    if not 0<=modulation<1:raise ValueError("AM modulation must be 0..1 (exclusive)")
    if not 1<=mod_bin<length//2:raise ValueError("Invalid modulation bin")
    alias_bin=round((112000000-requested_rf)*length/FS)
    rf=112000000-alias_bin*FS/length;fm=mod_bin*FS/length
    if not 88000000<=rf<=108000000:raise ValueError("Actual grid RF must be inside 88..108 MHz")
    if kind=="am" and fm>90000:raise ValueError("AM test modulation must fit inside +/-100 kHz; increase pattern length")
    if deviation<0:raise ValueError("FM deviation must be nonnegative")
    if kind=="fm" and deviation+fm>90000:raise ValueError("Use a modulation test comfortably inside +/-100 kHz")
    samples=[]
    for n in range(length):
        # Integer alias cycles make RF and its modulation seamless at wrap.
        phase=-math.tau*alias_bin*n/length
        envelope=800*(1+modulation*math.cos(math.tau*mod_bin*n/length)) if kind=="am" else 800
        if kind=="fm":phase+=(deviation/fm)*math.sin(math.tau*mod_bin*n/length)
        code=2048+round(envelope*math.cos(phase))
        if not 0<=code<=4095:raise ValueError("ADC waveform clips")
        samples.append(code)
    info=dict(kind=kind,adc_rate=FS,iq_rate=IQ_RATE,length=length,requested_rf_hz=requested_rf,
              actual_rf_hz=rf,alias_bin=alias_bin,modulating_hz=fm,modulation=modulation,deviation_hz=deviation,
              format="ADC12 offset binary in little-endian u16",ep_out="0x06",ep_in="0x82")
    return samples,info


def upload_commands(samples,start_sequence=1):
    sequence=start_sequence
    yield command(BEGIN,sequence,len(samples));sequence+=1
    for offset in range(0,len(samples),240):
        yield command(DATA,sequence,offset,samples[offset:offset+240]);sequence+=1
    yield command(START,sequence)


class Decoder:
    """Resynchronise after stopped/truncated streams and arbitrary USB read boundaries."""
    def __init__(self):self.buffer=bytearray();self.bad_crc=0;self.discarded=0
    def feed(self,data):
        self.buffer.extend(data);result=[]
        while True:
            starts=[p for magic in (b"RPA1",b"FCR1") if (p:=self.buffer.find(magic))>=0]
            if not starts:
                remove=max(0,len(self.buffer)-3);self.discarded+=remove;del self.buffer[:remove];break
            first=min(starts);self.discarded+=first;del self.buffer[:first]
            if len(self.buffer)<512:break
            frame=bytes(self.buffer[:512])
            if zlib.crc32(frame[:508])!=struct.unpack_from("<I",frame,508)[0]:
                self.bad_crc+=1;self.discarded+=1;del self.buffer[0];continue
            h=struct.unpack_from("<15I",frame)
            is_ack=frame[:4]==b"RPA1"
            valid=(h[1]&65535)==1 if is_ack else (h[1]==0x003c0003 and 1<=h[5]<=112 and h[7:9]==(FS,IQ_RATE))
            if not valid:self.discarded+=1;del self.buffer[0];continue
            del self.buffer[:512];result.append(("ack" if is_ack else "iq",h,frame))
        return result


def analyse(frames,info):
    rows=[];epoch=None;last_seq=None;next_index=None
    for frame in frames:
        h=struct.unpack_from("<15I",frame)
        if epoch is None:
            if h[2]!=0 or h[4]!=0:raise ValueError("Capture must begin at frame/sample zero")
            epoch=h[3];next_index=0
        if h[3]!=epoch:raise ValueError("Unexpected epoch change during capture")
        if last_seq is not None and h[2]!=last_seq+1:raise ValueError("Missing/repeated frame")
        if h[4]!=next_index or h[6]!=0:raise ValueError("IQ sample gap / FIFO overflow")
        if h[11]&4:raise ValueError("DSP clipping reported")
        if abs(h[9]-info['actual_rf_hz'])>12000:raise ValueError("Automatic RF estimate outside 12 kHz prototype tolerance")
        for k in range(h[5]):
            i,q=struct.unpack_from("<hh",frame,60+4*k)
            rows.append((h[4]+k,i,q,h[9],h[10]))
        last_seq=h[2];next_index=h[4]+h[5]
    stable=[complex(i,q) for index,i,q,_,_ in rows if index>=32]
    if len(stable)<200:raise ValueError("Need at least 200 settled IQ samples")
    env=[abs(v) for v in stable]
    if min(env)<=0:raise ValueError("Zero envelope after startup")
    result=dict(status="PASS",frames=len(frames),samples=len(rows),epoch=epoch,dropped=0,
                actual_rf_hz=info['actual_rf_hz'],estimated_rf_hz=rows[-1][3],
                envelope_min=min(env),envelope_max=max(env))
    if info['kind']=="am":
        depth=(max(env)-min(env))/(max(env)+min(env));result['am_depth']=depth
        if abs(depth-info['modulation'])>.03:raise ValueError(f"AM envelope depth {depth}")
    elif info['kind']=="fm":
        freq=[cmath.phase(b*a.conjugate())*IQ_RATE/math.tau for a,b in zip(stable,stable[1:])]
        dev=(max(freq)-min(freq))/2;result.update(fm_deviation_hz=dev,residual_hz=sum(freq)/len(freq))
        if abs(dev-info['deviation_hz'])>max(1500,.08*info['deviation_hz']):raise ValueError(f"FM deviation {dev}")
    return rows,result


def save_capture(out,frames,info):
    out.mkdir(parents=True,exist_ok=True)
    (out/'capture.bin').write_bytes(b''.join(frames))
    rows,result=analyse(frames,info)
    with (out/'iq.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(('sample_index','i','q','rf_estimate_hz','phase_step'));w.writerows(rows)
    (out/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2));return result


def run_device(args,samples,info,on_frame=None,on_progress=None):
    from .usb_transport import open_transport, TransferTimeout
    if on_progress is not None: on_progress("Connecting to FX2LP USB interface...")
    dev=open_transport(args.vid,args.pid,args.backend,args.interface,args.cyusb_dll)
    print(json.dumps(dev.describe(),indent=2),flush=True)
    if on_progress is not None: on_progress("FX2LP connected: EP6 OUT / EP2 IN")
    decoder=Decoder();pending=[];started=False
    def read_records(timeout=1000):
        if pending:return pending.pop(0)
        data=dev.read(0x82,512,timeout=timeout)
        pending.extend(decoder.feed(bytes(data)))
        return pending.pop(0) if pending else None
    def exchange(frame):
        sequence=struct.unpack_from('<I',frame,8)[0]
        op=struct.unpack_from('<H',frame,6)[0]
        label={BEGIN:'BEGIN',DATA:'DATA',START:'START',STOP:'STOP'}.get(op,str(op))
        try:
            if dev.write(0x06,frame,timeout=3000)!=512:raise RuntimeError("Short EP6 OUT write")
        except (TransferTimeout,RuntimeError) as e:
            raise RuntimeError(f'EP6 OUT failed sending {label}, seq={sequence}; no ACK stage reached. {e}. '
                               'Check FX2 FIFO readiness, IFCLK and FPGA reads; after a stalled run, reset/reconnect the board and reload SOF if board power was lost.') from e
        deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            try:record=read_records(1000)
            except TransferTimeout:continue
            if record and record[0]=='ack' and record[1][2]==sequence:
                h=record[1];status=h[1]>>16
                if status:raise RuntimeError(f"FPGA rejected command seq={sequence}, status={status}, op={h[3]}, loaded={h[4]}")
                return h
        raise RuntimeError("No RPA1 ACK: check EP6 OUT/EP2 IN, indexed FLAGB/FLAGC after FIFO selection, slave FIFO mode and FPGA build")
    try:
        if getattr(args,'fx2_init','none')=='fcore2s':
            if (args.vid,args.pid)!=(0x04b4,0x1004):raise RuntimeError('fcore2s initialization is only for VID 04B4 / PID 1004')
            print('WARNING: supplied bulkloop.iic A9 resets EP6 without AUTOOUT re-arm; use --fx2-init none after a fresh board startup for replay.',flush=True)
            for request in (0xa9,0xa8):
                dev.vendor_command(request)
                print(f'FX2 vendor {request:#04x} completed',flush=True)
        if on_progress is not None: on_progress("Clearing previous replay state (STOP)...")
        exchange(command(STOP,1))
        for n,frame in enumerate(upload_commands(samples,2)):
            exchange(frame)
            if struct.unpack_from('<H',frame,6)[0]==START:started=True
            if n%8==0:
                print(f'Upload command {n} acknowledged',flush=True)
                if on_progress is not None: on_progress(f"Uploaded {n + 1} command frames")
        decoder.bad_crc=0;frames=[];deadline=time.monotonic()+args.timeout
        if on_progress is not None: on_progress(f"Receiving {args.frames} FCR1 IQ frames...")
        while len(frames)<args.frames and time.monotonic()<deadline:
            try:record=read_records(1000)
            except TransferTimeout:continue
            if record and record[0]=='iq':
                frames.append(record[2])
                if on_frame is not None: on_frame(record[2])
                if on_progress is not None and (len(frames) == 1 or len(frames) % 16 == 0):
                    on_progress(f"Received {len(frames)}/{args.frames} IQ frames")
        if len(frames)!=args.frames:raise RuntimeError("IQ timeout: inspect FPGA lock LED and replay ACKs")
        if decoder.bad_crc:raise RuntimeError("CRC failure during current IQ capture")
        if on_progress is not None: on_progress("Stopping replay and saving validated capture...")
        exchange(command(STOP,1000000));started=False
        return save_capture(args.output,frames,info)
    finally:
        if started:
            try:exchange(command(STOP,1000001))
            except Exception as error:print(f"Cleanup STOP failed: {error}")
        dev.close()


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('action',choices=('generate','run','check','probe','gui'))
    p.add_argument('--kind',choices=('tone','am','fm','alternate'),default='am',
                   help='alternate switches AM and FM on successive continuous replay rounds')
    p.add_argument('--rf',type=float,default=100700000,
                   help='RF carrier in Hz (AM carrier in alternate mode; default: 100700000)')
    p.add_argument('--fm-rf',type=float,default=101700000,
                   help='FM carrier in Hz for alternate mode (default: 101700000)')
    p.add_argument('--length',type=int,default=8192)
    p.add_argument('--modulation',type=float,default=.5)
    p.add_argument('--deviation',type=float,default=25000)
    p.add_argument('--mod-bin',type=int,default=1)
    p.add_argument('--output',type=Path,default=ARTIFACT_ROOT / "legacy/receiver/usb_replay")
    p.add_argument('--vid',type=lambda v:int(v,0));p.add_argument('--pid',type=lambda v:int(v,0))
    p.add_argument('--interface',type=int,default=0)
    p.add_argument('--frames',type=int,default=16,
                   help='IQ frames to receive per upload (default: 16)')
    p.add_argument('--continuous',action='store_true',
                   help='Repeat upload, IQ capture and validation until Ctrl+C; keep the latest capture for each modulation')
    p.add_argument('--timeout',type=float,default=15)
    p.add_argument('--fx2-init',choices=('none','fcore2s'),default='none',help='Optional board-example A9/A8 vendor sequence; does not flash firmware')
    p.add_argument('--backend',choices=('auto','cyusb','pyusb'),default='auto')
    p.add_argument('--cyusb-dll',type=Path,help='Path to official CyUSB.dll (Cypress driver)')
    args=p.parse_args()
    if args.action=='gui':
        from usb_replay_gui import main as gui_main
        gui_main()
        return
    if args.action=='probe':
        if args.vid is None or args.pid is None:p.error('probe requires --vid and --pid')
        from .usb_transport import open_transport
        dev=open_transport(args.vid,args.pid,args.backend,args.interface,args.cyusb_dll)
        try:print(json.dumps(dev.describe(),indent=2))
        finally:dev.close()
        return
    if args.kind=='alternate' and (args.action!='run' or not args.continuous):
        p.error('--kind alternate requires run --continuous')
    modes=('am','fm') if args.kind=='alternate' else (args.kind,)
    patterns={kind:waveform(kind,args.fm_rf if args.kind=='alternate' and kind=='fm' else args.rf,
                           args.length,args.modulation,args.deviation,args.mod_bin)
              for kind in modes} if args.action in ('generate','run') else {}
    if args.kind=='alternate' and patterns['am'][1]['actual_rf_hz']==patterns['fm'][1]['actual_rf_hz']:
        p.error('AM and FM carriers resolve to the same frequency; change --rf or --fm-rf')
    args.output.mkdir(parents=True,exist_ok=True)
    if args.action=='generate':
        samples,info=patterns[args.kind]
        frames=list(upload_commands(samples))
        (args.output/'upload.bin').write_bytes(b''.join(frames))
        (args.output/'adc_u16le.bin').write_bytes(struct.pack('<'+'H'*len(samples),*samples))
        (args.output/'manifest.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
        print(json.dumps(info,indent=2));print(f'{len(frames)} commands -> {args.output}')
    elif args.action=='run':
        if args.vid is None or args.pid is None:p.error('run requires --vid and --pid from your actual device')
        if args.frames<3:p.error('capture at least 3 IQ frames')
        if args.continuous:
            print('Continuous replay: uploading '+('/'.join(modes))+' ADC patterns in order; '
                  'press Ctrl+C to stop. Playback briefly stops between rounds. '
                  'Only the latest capture for each modulation is kept.',flush=True)
            round_number=0
            try:
                while True:
                    kind=modes[round_number%len(modes)]
                    round_number+=1
                    round_args=argparse.Namespace(**vars(args))
                    if args.kind=='alternate':round_args.output=args.output/kind
                    round_args.output.mkdir(parents=True,exist_ok=True)
                    samples,info=patterns[kind]
                    (round_args.output/'manifest.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
                    print(f"--- Replay round {round_number}: {kind.upper()} "
                          f"RF={info['actual_rf_hz']:.3f} Hz ---",flush=True)
                    run_device(round_args,samples,info)
            except KeyboardInterrupt:
                print(f'Stopped after {round_number} replay round(s).',flush=True)
        else:
            samples,info=patterns[args.kind]
            (args.output/'manifest.json').write_text(json.dumps(info,indent=2),encoding='utf-8')
            run_device(args,samples,info)
    else:
        info=json.loads((args.output/'manifest.json').read_text(encoding='utf-8'))
        d=Decoder();records=d.feed((args.output/'capture.bin').read_bytes())
        if d.bad_crc:raise RuntimeError('Capture contains CRC errors')
        save_capture(args.output,[frame for kind,_,frame in records if kind=='iq'],info)

if __name__=='__main__':
    try:main()
    except (RuntimeError,ValueError,TimeoutError) as e:raise SystemExit(str(e))
