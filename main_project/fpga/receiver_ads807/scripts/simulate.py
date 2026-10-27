"""Actual ModelSim SE / Intel ModelSim; exact integer reference and USB CRC checks."""
import argparse
import cmath
import json
import math
import random
import shutil
import struct
import subprocess
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parents[2]/".harness/receiver_ads807/simulation"


def test_tuning(rf,rate):
    """Known-truth reference for isolated DSP tests, never a host command."""
    assert rate==43500000 and 88000000<=rf<=108000000
    return round((rf-87000000)/rate*2**32),0


def signed(value,bits):
    return (value+(1 << (bits-1))) % (1 << bits)-(1 << (bits-1))


class CIC:
    def __init__(self,r):
        self.r=r
        self.reset()

    def reset(self):
        self.integrators=[0]*5
        self.delay=[0]*5
        self.comb=[0]*5
        self.cv=[False]*5
        self.count=0
        self.output=(0,0,0)

    def tick(self,rst,valid,value):
        if not rst:
            self.reset()
            return
        shift=40
        scaled=self.comb[-1] >> shift
        self.output=(int(self.cv[-1]),max(-131072,min(131071,scaled)),
                     int(not -131072<=scaled<=131071)) if self.cv[-1] else (0,self.output[1],0)
        old_integrators=self.integrators.copy()
        old_comb=self.comb.copy()
        old_cv=self.cv.copy()
        self.cv=[bool(valid and self.count==self.r-1)]+old_cv[:-1]
        if valid:
            self.integrators=[signed(a+b,59) for a,b in
                              zip(old_integrators,[value]+old_integrators[:-1])]
            if self.count==self.r-1:
                self.comb[0]=signed(old_integrators[-1]-self.delay[0],59)
                self.delay[0]=old_integrators[-1]
                self.count=0
            else:
                self.count+=1
        for k in range(1,5):
            if old_cv[k-1]:
                self.comb[k]=signed(old_comb[k-1]-self.delay[k],59)
                self.delay[k]=old_comb[k-1]


def reference(rows,rate):
    coeff=[signed(int(v,16),18) for v in (ROOT/"rtl/fir_coeff.hex").read_text().split()]
    c_i,c_q=CIC(rate//500000),CIC(rate//500000)
    capture=(0,0)
    mix=(0,0,0)
    phase=0
    pending_mix=None
    hist_i=[];hist_q=[]
    fir_pending={}
    last=(0,0,0,0,0)
    output=[]
    for cycle,(rst,en,raw,step,conj) in enumerate(rows):
        ci,cq=c_i.output,c_q.output
        old_capture=capture
        old_mix=mix
        if not rst:
            capture=(0,0);mix=(0,0,0);phase=0;pending_mix=None
            hist_i=[];hist_q=[];fir_pending={};last=(0,0,0,0,0)
        else:
            capture=(en,raw-2048 if en else capture[1])
            mix=(0,mix[1],mix[2]) if pending_mix is None else (1,*pending_mix)
            pending_mix=None
            if old_capture[0]:
                angle=math.tau*(phase>>22)/1024
                # Same quantization specification, independent trigonometric values.
                s=round(2047*math.sin(angle));c=round(2047*math.cos(angle))
                pending_mix=(old_capture[1]*c,old_capture[1]*(s if conj else -s))
                phase=(phase+step)&0xffffffff
            if ci[0] and cq[0]:
                hist_i=([ci[1]]+hist_i)[:61];hist_q=([cq[1]]+hist_q)[:61]
                si=(sum(h*c for h,c in zip(hist_i,coeff))+65536)>>17
                sq=(sum(h*c for h,c in zip(hist_q,coeff))+65536)>>17
                fir_pending[cycle+63]=(1,max(-32768,min(32767,si)),
                    max(-32768,min(32767,sq)),
                    int(ci[2] or cq[2] or not -32768<=si<=32767 or not -32768<=sq<=32767),0)
            last=fir_pending.pop(cycle,(0,last[1],last[2],0,0))
        c_i.tick(rst,old_mix[0],old_mix[1]);c_q.tick(rst,old_mix[0],old_mix[2])
        output.append(last)
    return output


def vectors(rate):
    rng=random.Random(20261004)
    rows=[(0,1,4095,0,0)]*4
    # Full ADC range, deterministic random data, enable bubbles and stream reset.
    rows += [(1,1,code,1<<22,0) for code in range(4096)]
    rows += [(1,int(rng.random()>.15),rng.randrange(4096),0xe1234567,1)
             for _ in range(5000)]
    segments=[]
    # AM/FM real passband waveforms; desired complex envelope is checked separately.
    # Includes both orientations of spectral folding, upper/lower offset and silence.
    for kind,rf,offset in (("tone",98000000,-5000),("tone",96000000,5000),
                            ("tone",88000000,-5000),("tone",104000000,5000),
                            ("tone",108000000,5000),("tone",100000000,5000),
                            ("am",98000000,0),("fm",98000000,0),("silence",98000000,0)):
        alias=signed(round(rf/rate*(1<<32)),32)*rate/(1<<32)
        inverted=alias<0
        lo=abs(alias)
        if min(lo,rate/2-lo)<150000:
            # This rate cannot recover a complete +/-100 kHz signal at this RF.
            segments.append(dict(kind=kind,rf=rf,rejected=True));continue
        step,direction=test_tuning(rf,rate)
        assert direction==int(inverted)
        rows += [(0,0,2048,step,int(inverted))]*4
        start=len(rows)
        length=rate//500000*320
        phase=0.0
        for n in range(length):
            t=n/rate
            amplitude=800
            if kind=="am": amplitude*=1+.5*math.cos(math.tau*5000*t)
            if kind=="fm": phase+=math.tau*(rf+25000*math.cos(math.tau*5000*t))/rate
            else: phase=math.tau*(rf+offset)*t
            value=0 if kind=="silence" else round(amplitude*math.cos(phase))
            rows.append((1,1,2048+value,step,int(inverted)))
        rows += [(1,0,2048,step,int(inverted))]*150
        segments.append(dict(kind=kind,rf=rf,offset=offset,start=start,stop=len(rows),rejected=False))
    return rows,segments


def validate_dsp(path,rows,rate,segments):
    actual=[tuple(map(int,line.split())) for line in path.read_text().splitlines()]
    expected=reference(rows,rate)
    assert len(actual)==len(expected),(len(actual),len(expected))
    for cycle,(a,e) in enumerate(zip(actual,expected)):
        assert a==e,f"rate={rate} cycle={cycle} input={rows[cycle]} got={a} expected={e}"
    measurements=[]
    for s in segments:
        if s["rejected"]: continue
        # Use valid outputs after startup transient; model comparison covers all samples.
        block=actual[s["start"]:s["stop"]]
        values=[complex(row[1],row[2]) for row in block if row[0]][100:300]
        assert len(values)==200
        if s["kind"]=="tone":
            def amplitude(f):
                return abs(sum(x*cmath.exp(-1j*math.tau*f*n/500000)
                               for n,x in enumerate(values))/len(values))
            wanted=amplitude(s["offset"]);image=amplitude(-s["offset"])
            r=rate//500000
            shift=40
            gain=800*2047*r**5/(2**shift)/2
            assert abs(wanted/gain-1)<.01 and image<wanted*.02,(s,wanted,image,gain)
            measurements.append(dict(kind="tone",rf=s["rf"],wanted=wanted,image=image))
        elif s["kind"]=="silence": assert max(map(abs,values))==0
        elif s["kind"]=="am":
            envelope=list(map(abs,values));ratio=(max(envelope)-min(envelope))/(max(envelope)+min(envelope))
            assert .47<ratio<.53,ratio
            measurements.append(dict(kind="am",modulation=ratio))
        elif s["kind"]=="fm":
            frequencies=[cmath.phase(b*a.conjugate())*500000/math.tau
                         for a,b in zip(values,values[1:])]
            assert min(frequencies)<-23500 and max(frequencies)>23500
            measurements.append(dict(kind="fm",min_hz=min(frequencies),max_hz=max(frequencies)))
    return dict(rate=rate,cycles=len(rows),measurements=measurements,segments=segments)


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--modelsim",type=Path,default=Path(r"D:\modeltech64_2020.4\win64"))
    p.add_argument("--quartus",type=Path,default=Path(r"D:\intelFPGA\18.1\quartus"))
    p.add_argument("--modules-only",action="store_true")
    a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/"rtl").mkdir(exist_ok=True)
    for file in (ROOT/"rtl").glob("*.hex"): shutil.copyfile(file,OUT/"rtl"/file.name)
    def run(tool,args,label,timeout=180):
        cmd=[str(a.modelsim/(tool+".exe")),*map(str,args)]
        r=subprocess.run(cmd,cwd=OUT,capture_output=True,text=True,errors="replace",timeout=timeout)
        (OUT/(label+".log")).write_text(r.stdout+r.stderr,encoding="utf-8")
        assert not r.returncode and "** Error" not in r.stdout and "** Fatal" not in r.stdout, r.stdout[-4000:]+r.stderr[-1000:]
        print(label+": passed",flush=True)
        return r.stdout
    run("vlib",["work"],"library")
    libraries=[a.quartus/"eda/sim_lib/altera_primitives.v",
               a.quartus/"eda/sim_lib/220model.v",a.quartus/"eda/sim_lib/altera_mf.v",
               a.quartus/"eda/sim_lib/cycloneive_atoms.v"]
    tests=sorted((ROOT/"tests").glob("tb_*.v"))
    run("vlog",["-sv",*libraries,ROOT/"ip/rx_pll_ads807.v",ROOT/"ip/rx_fifo.v",ROOT/"ip/rx_ifclk.v",
                *sorted((ROOT/"rtl").glob("*.v")),*tests],"compile")
    summary={}
    do="onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"
    tops=("tb_capture","tb_pll","tb_frequency") if a.modules_only else ("tb_capture","tb_pll","tb_frequency","tb_receiver")
    for top in tops:
        output=run("vsim",["-c","-wlf",top+".wlf","work."+top,"-do",do],top,timeout=600)
        assert top.split("_")[1].upper()+"_PASS" in output,output
        summary[top]="passed"
    for rf in range(88000000,108000001,10000):
        step,conj=test_tuning(rf,43500000)
        assert 0<step<2**31 and conj==0
    summary["rate_coverage"]="43.5 MHz positive alias, 2001 RF model points; hardware not validated"
    for rate in (43500000,):
        rows,segments=vectors(rate)
        (OUT/"dsp_inputs.txt").write_text("".join(f"{r} {e} {raw} {step:08x} {c}\n"
                                                for r,e,raw,step,c in rows),encoding="ascii")
        output=run("vsim",["-c","-voptargs=+acc","-wlf",f"dsp{rate}.wlf",
                           f"-gADC_RATE={rate}","work.tb_dsp","-do",do],f"dsp{rate}")
        assert "DSP_PASS" in output
        shutil.copyfile(OUT/"dsp_outputs.txt",OUT/f"dsp{rate}_outputs.txt")
        summary[str(rate)]=validate_dsp(OUT/"dsp_outputs.txt",rows,rate,segments)
    if a.modules_only:
        (OUT/"modules_summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
        print("Module numeric checks: ALL PASS")
        return
    data=bytes(int(line,16) for line in (OUT/"receiver_bytes.txt").read_text().split())
    frames=[]
    position=0
    while position<=len(data)-512:
        frame=data[position:position+512]
        if frame[:4]!=b"FCR1":
            position+=1
            continue
        assert zlib.crc32(frame[:508])==struct.unpack_from("<I",frame,508)[0]
        header=struct.unpack("<15I",frame[:60])
        assert header[1]==0x003c0002 and header[7:9]==(43500000,500000)
        assert header[6]==0 and header[11]&2==0 and header[12]==40
        assert 88000000<=header[9]<=108000000
        assert header[5]==112
        if frames:
            assert header[2]==frames[-1][2]+1
            assert header[4]==frames[-1][4]+112
        frames.append(header)
        position+=512
    assert len(frames)>=4,len(frames)
    actual_iq={int(p[0]):tuple(map(int,p[1:])) for line in
               (OUT/"receiver_iq.txt").read_text().splitlines() if (p:=line.split())}
    for number,header in enumerate(frames):
        frame=data[number*512:(number+1)*512]
        for k in range(112):
            assert struct.unpack_from("<hh",frame,60+4*k)==actual_iq[header[4]+k]
    summary["receiver_chain"]={"complete_frames":len(frames),"crc_and_payload":"passed",
        "rf_estimate_hz":frames[0][9],"dropped":0,"adc_rate_hz":43500000,
        "iq_rate_hz":500000,"source":"actual DUT FIFO write values"}
    (OUT/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print("ModelSim and independent numeric/CRC checks: ALL PASS")

if __name__=="__main__": main()
