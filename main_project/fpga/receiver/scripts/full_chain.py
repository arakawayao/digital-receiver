"""56 MHz unknown-RF acquisition -> automatic FPGA DDC -> USB RTL simulation.

ADC signal truth is never passed to a DUT configuration port. All complete USB
frames are checked against an independent integer replay of the ADC pin samples.
This does not test the analogue front end, USB driver, production host or audio.
"""
import argparse
import cmath
from collections import Counter, defaultdict
import csv
import json
import math
import shutil
import struct
import subprocess
import zlib
from pathlib import Path

from simulate import ROOT, reference

RATE=56000000
OUT=ROOT.parents[2]/".harness/receiver/full_chain56"
SIGNALS={0:("am",98000000),1:("fm",88000000),2:("fm",108000000),
         3:("am",93370000),6:("am",98000000),7:("am",98000000),9:("am",98000000)}
# Prototype simulation tolerance; not a course requirement or calibrated RF accuracy.
RF_TOLERANCE_HZ=12000


def replay_sessions(path):
    """Replay one uninterrupted DSP stream at a time to bound memory use."""
    result={}; block=[]; epochs=Counter(); phases=Counter(); rfs=Counter()
    current=None; cycles=0
    def finish():
        if not block:
            return
        epoch=epochs.most_common(1)[0][0]
        assert epoch not in result,("duplicate stream epoch",epoch,current)
        assert len(phases)==1,("LO changed during released stream",current,phases)
        golden=[v for v in reference(block,RATE) if v[0]]
        assert golden,("empty running stream",current)
        result[epoch]=dict(session=current,phase_step=next(iter(phases)),
            rf_hz=rfs.most_common(1)[0][0],expected=golden,cycles=len(block))
    with path.open(encoding="ascii") as f:
        for line in f:
            sid,epoch,stage,rst,en,raw,step,conj,rf=line.split()
            sid,epoch,rst,en,raw,step,conj,rf=(int(sid),int(epoch),int(rst),int(en),
                int(raw),int(step,16),int(conj),int(rf))
            if sid!=current:
                finish(); block=[]; epochs=Counter(); phases=Counter(); rfs=Counter()
                current=sid
            block.append((rst,en,raw,step,conj)); cycles+=1
            if rst:
                assert conj==1,("56 MHz RF folding must be conjugated",sid,conj)
                epochs[epoch]+=1; phases[step]+=1; rfs[rf]+=1
    finish()
    assert list(result)==sorted(result),("epoch order",list(result))
    return result,cycles


def decode_frames(data):
    """Resynchronise after intentional stream resets truncate an in-flight frame."""
    frames=[]; rejected=[]; cursor=0
    while True:
        pos=data.find(b"FCR1",cursor)
        if pos<0:
            break
        if len(data)-pos<512:
            break
        frame=data[pos:pos+512]
        h=struct.unpack("<15I",frame[:60])
        if h[1]!=0x003c0002 or h[7]!=RATE or h[8]!=500000 or h[13]!=112:
            cursor=pos+1; continue
        if zlib.crc32(frame[:508])!=struct.unpack_from("<I",frame,508)[0]:
            rejected.append(pos); cursor=pos+1; continue
        frames.append((pos,h,frame)); cursor=pos+512
    assert frames,"No complete FCR1 version 2 frames"
    # A bad complete-sized candidate is permitted only when a new valid frame
    # begins inside it: that is the documented reset-truncated previous frame.
    for pos in rejected:
        assert any(pos<start<pos+512 for start,_,_ in frames),("unexplained CRC failure",pos)
    return frames,len(data)-512*len(frames)


def validate():
    sessions,cycles=replay_sessions(OUT/"chain56000000_inputs.txt")
    data=bytearray()
    with (OUT/"chain56000000_bytes.txt").open(encoding="ascii") as f:
        for line in f:
            stage,epoch,value=line.split(); data.append(int(value,16))
    events=[]
    with (OUT/"chain56000000_events.txt").open(encoding="ascii") as f:
        for line in f:
            label,*values=line.split()
            stage,epoch,received,dropped,index,locked,time_ps=map(int,values)
            events.append(dict(label=label,stage=stage,epoch=epoch,bytes=received,
                dropped=dropped,index=index,locked=locked,time_ps=time_ps))
    capture={e["stage"]:e for e in events if e["label"]=="CAPTURE"}
    locks={e["stage"]:e for e in events if e["label"]=="LOCK"}
    assert set(capture)==set(SIGNALS),("missing capture scenarios",capture)
    for stage in SIGNALS:
        assert capture[stage]["epoch"]==locks[stage]["epoch"],("capture lost/restarted lock",stage)
    for stage in (4,5):
        loss=next(e for e in events if e["label"]=="LOSS" and e["stage"]==stage)
        quiet=next(e for e in events if e["label"]=="QUIET" and e["stage"]==stage)
        assert loss["bytes"]==quiet["bytes"] and quiet["locked"]==0,("fabricated signal",stage)
        assert quiet["time_ps"]-loss["time_ps"]>=3500000000
    frames,discarded=decode_frames(bytes(data))
    by_epoch=defaultdict(list); samples=defaultdict(list); iq_rows=[]
    for pos,h,frame in frames:
        epoch=h[3]
        assert epoch in sessions,("USB epoch has no ADC reference stream",epoch)
        by_epoch[epoch].append((pos,h,frame))
    session_results=[]
    for epoch,entries in by_epoch.items():
        model=sessions[epoch]; next_index=0; missing=0; counts=[]
        for seq,(_,h,frame) in enumerate(entries):
            first,count,dropped=h[4:7]
            assert h[:4]==(0x31524346,0x003c0002,seq,epoch),(epoch,seq,h)
            assert 1<=count<=112 and first>=next_index,(epoch,seq,h)
            missing+=first-next_index; next_index=first+count
            assert dropped==missing,(epoch,seq,"drop accounting",dropped,missing)
            assert h[7:11]==(RATE,500000,model["rf_hz"],model["phase_step"]),\
                (epoch,seq,h,model["rf_hz"],model["phase_step"])
            # RF estimate and NCO must describe the same 112 MHz - RF alias.
            estimated=112000000-h[10]*RATE/(1<<32)
            # Detector clamps endpoint metadata; LO retains the measured phase.
            clamped=max(88000000,min(108000000,estimated))
            assert abs(h[9]-clamped)<=3,("inconsistent automatic metadata",epoch,h[9],estimated)
            block=model["expected"][first:first+count]
            assert len(block)==count,(epoch,seq,"out-of-range sample index")
            flags=int(dropped!=0)|2|(int(any(v[3] for v in block))<<2)|(int(first<66)<<3)|16
            assert h[11:]==(flags,42,112,0),(epoch,seq,"flags/format",h)
            payload=struct.unpack("<224h",frame[60:508])
            want=tuple(x for v in block for x in v[1:3])+(0,)*(2*(112-count))
            assert payload==want,f"epoch={epoch} frame={seq}: ADC-to-USB IQ/zero-padding mismatch"
            for k in range(count):
                value=complex(payload[2*k],payload[2*k+1])
                samples[epoch].append((first+k,value))
                iq_rows.append((epoch,first+k,int(value.real),int(value.imag),dropped,flags))
            counts.append(count)
        session_results.append(dict(epoch=epoch,session=model["session"],rf_estimate_hz=model["rf_hz"],
            phase_step=model["phase_step"],frames=len(entries),received_iq=sum(counts),
            missing_iq=missing,valid_counts=counts))
    scenario_results=[]
    for stage,(kind,rf) in SIGNALS.items():
        epoch=capture[stage]["epoch"]
        assert epoch in by_epoch,("missing captured epoch",stage,epoch)
        assert len(by_epoch[epoch]) >= (4 if stage==9 else 6),("insufficient full frames",stage)
        model=sessions[epoch]
        error=model["rf_hz"]-rf
        assert abs(error)<=RF_TOLERANCE_HZ,("automatic RF estimate",stage,rf,model["rf_hz"])
        stable=[v for index,v in samples[epoch] if 200<=index<600]
        assert len(stable)>=200,(stage,"insufficient settled received IQ")
        if kind=="am":
            envelope=list(map(abs,stable))
            depth=(max(envelope)-min(envelope))/(max(envelope)+min(envelope))
            assert .47<depth<.53,(stage,"AM envelope",depth)
            measurement=dict(am_depth=depth,truth_depth=.5,modulating_hz=5000)
        else:
            frequencies=[cmath.phase(b*a.conjugate())*500000/math.tau
                         for a,b in zip(stable,stable[1:])]
            deviation=(max(frequencies)-min(frequencies))/2
            center=(max(frequencies)+min(frequencies))/2
            assert 23500<deviation<26500,(stage,"FM deviation",deviation)
            measurement=dict(fm_deviation_hz=deviation,truth_deviation_hz=25000,
                residual_center_hz=center,modulating_hz=5000)
        scenario_results.append(dict(stage=stage,kind=kind,rf_truth_hz=rf,
            rf_estimate_hz=model["rf_hz"],error_hz=error,epoch=epoch,measurement=measurement))
    overflow=next(e for e in events if e["label"]=="OVERFLOW")
    overflow_result=next(s for s in session_results if s["epoch"]==overflow["epoch"])
    assert overflow["dropped"]>0 and overflow_result["missing_iq"]==overflow["dropped"]
    assert min(overflow_result["valid_counts"])<112,"FIFO loss must split a partial valid block"
    assert discarded>0,"Mid-frame pause should exercise byte-stream resynchronisation"
    recovery=next(s for s in session_results if s["epoch"]==capture[9]["epoch"])
    assert recovery["missing_iq"]==0 and recovery["epoch"]>overflow["epoch"]
    with (OUT/"chain56000000_iq.csv").open("w",newline="",encoding="ascii") as f:
        writer=csv.writer(f); writer.writerow(("epoch","sample_index","i_int16","q_int16","dropped","flags"))
        writer.writerows(iq_rows)
    return dict(rate=RATE,status="passed",logged_running_dsp_cycles=cycles,
        usb_bytes=len(data),complete_frames=len(frames),discarded_truncated_bytes=discarded,
        rf_test_tolerance_hz=RF_TOLERANCE_HZ,sessions=session_results,scenarios=scenario_results,
        silence_and_noise="unlocked, no new data for 3.5 ms after loss",events=events)


def waveform_signals():
    tb=("stage","session","kind","rf","clk","rst_n","adc_clk","adc","pause",
        "host_stall","received","credit","pclk","wr","rd","pa7","pa6","pa5",
        "pa4","pa2","pa0","dq","flagb")
    dut=("locked","sample_clk","usb_clk","usb_reset_n","pause_sync","stream_arst_n",
        "stream_sample_n","stream_usb_n","sample_phase","sample_conjugate","rf_hz",
        "epoch","iq_i","iq_q","iq_valid","iq_clip","dsp_error","fifo_full","fifo_empty",
        "fifo_read","index","dropped","fifo_q","tx_data","tx_valid","tx_ready",
        "dsp/sample","dsp/capture_valid","dsp/mixer/phase","dsp/mi","dsp/mq",
        "dsp/mix_valid","dsp/cic_i/count","dsp/ci","dsp/cq","dsp/ci_valid","dsp/cq_valid",
        "dsp/fir/busy","dsp/fir/tap","packet/state","packet/count","packet/pos",
        "packet/sequence_id","packet/first_index","packet/dropped","packet/crc",
        "detector/locked","detector/phase_step","detector/rf_hz","detector/update",
        "detector/valid_window","detector/measured_bins","usb/state","usb/flagb_q","led")
    return ["/full_chain_tb/"+v for v in tb]+["/full_chain_tb/dut/"+v for v in dut]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--modelsim",type=Path,default=Path(r"D:\modeltech64_2020.4\win64"))
    p.add_argument("--quartus",type=Path,default=Path(r"D:\intelFPGA\18.1\quartus"))
    p.add_argument("--rate",type=int,choices=(RATE,),default=RATE)
    p.add_argument("--timeout",type=int,default=1800,help="ModelSim wall time limit in seconds")
    a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True); (OUT/"rtl").mkdir(exist_ok=True)
    for file in (ROOT/"rtl").glob("*.hex"): shutil.copyfile(file,OUT/"rtl"/file.name)
    def run(tool,args,label,timeout=240):
        command=[str(a.modelsim/(tool+".exe")),*map(str,args)]
        process=subprocess.Popen(command,cwd=OUT,stdout=subprocess.PIPE,stderr=subprocess.PIPE,
            text=True,errors="replace")
        try:
            stdout,stderr=process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            # Terminate only this launched process tree; vsim can spawn vsimk.
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],
                capture_output=True,text=True,errors="replace",check=False)
            stdout,stderr=process.communicate()
            (OUT/(label+".log")).write_text(stdout+stderr,encoding="utf-8")
            raise RuntimeError(f"{label}: ModelSim timed out after {timeout}s")
        log=stdout+stderr
        (OUT/(label+".log")).write_text(log,encoding="utf-8")
        assert process.returncode==0 and "** Error" not in log and "** Fatal" not in log,log[-6000:]
        print(label+": passed",flush=True); return log
    run("vlib",["work"],"library")
    libraries=[a.quartus/"eda/sim_lib"/name for name in
               ("altera_primitives.v","220model.v","altera_mf.v","cycloneive_atoms.v")]
    run("vlog",["-sv",*libraries,*sorted((ROOT/"ip").glob("*.v")),
                *sorted((ROOT/"rtl").glob("*.v")),ROOT/"tests/full_chain_tb.sv"],"compile")
    wlf=OUT/"full_chain56000000.wlf"
    # Only the known generated result is removed, after the prior run has ended.
    if wlf.exists(): wlf.unlink()
    do="onerror {quit -code 1}; onbreak {quit -code 1}; log "+" ".join(waveform_signals())+"; run -all; quit -code 0"
    log=run("vsim",["-c","-voptargs=+acc","-wlf",wlf.name,
                    f"-gADC_RATE={RATE}","work.full_chain_tb","-do",do],"chain56000000",a.timeout)
    assert f"FULL_CHAIN_PASS rate={RATE}" in log
    assert "vsim-WLF-5000" not in log,"Existing WLF is in use; end the old viewer/run and repeat"
    for name in ("inputs","bytes","events"):
        shutil.copyfile(OUT/f"chain_{name}.txt",OUT/f"chain56000000_{name}.txt")
    result=validate()
    (OUT/"chain56000000_summary.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    (OUT/"summary.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    print("56 MHz automatic full chain: payload/CRC, unknown RF, AM/FM, no signal, retune, pause and overflow ALL PASS")


if __name__=="__main__": main()
