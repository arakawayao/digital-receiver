"""Actual 56 MHz ModelSim audit of sustained locked ADC-to-USB processing.

Initial autonomous acquisition is measured separately. After lock, every external
ADC clock must reach capture/mixer, every 112 clocks must produce CIC/FIR IQ, and
normal USB reception including bounded backpressure must have zero FIFO loss.
"""
import argparse
import json
from pathlib import Path
import shutil
import struct
import subprocess
import zlib

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parents[2]/".harness/receiver/realtime56"


def observe_adc_clock(modelsim):
    """Independently count external ADC edges from the completed WLF."""
    vcd=OUT/"realtime56_adc.vcd"
    result=subprocess.run([str(modelsim/"wlf2vcd.exe"),"-quiet","-o",str(vcd),
        str(OUT/"realtime56.wlf")],capture_output=True,text=True,errors="replace",timeout=180)
    (OUT/"wlf2vcd.log").write_text(result.stdout+result.stderr,encoding="utf-8")
    assert result.returncode==0,result.stdout+result.stderr
    wanted={"realtime_tb.audit":"audit","realtime_tb.adc_clk":"clock"}
    stack=[]; identifiers={}; state={}; changes={}; timestamp=0
    prior_clock=0; prior_audit=0; edge_count=0; first=None; last=None; start=None; stop=None
    def flush():
        nonlocal prior_clock,prior_audit,edge_count,first,last,start,stop
        state.update(changes)
        clock=state.get("clock",0); audit=state.get("audit",0)
        if audit==1 and prior_audit!=1: start=timestamp
        if audit!=1 and prior_audit==1: stop=timestamp
        if audit==1 and clock==1 and prior_clock==0:
            edge_count+=1
            if first is None: first=timestamp
            last=timestamp
        prior_clock=clock; prior_audit=audit; changes.clear()
    with vcd.open(encoding="ascii") as file:
        definitions=True; ps_timescale=False
        for raw in file:
            line=raw.strip()
            if definitions:
                fields=line.split()
                if line=="1ps": ps_timescale=True
                if line.startswith("$scope "): stack.append(fields[2])
                elif line.startswith("$upscope"): stack.pop()
                elif line.startswith("$var "):
                    name=".".join(stack+[fields[4]])
                    if name in wanted: identifiers[fields[3]]=wanted[name]
                elif line.startswith("$enddefinitions"):
                    definitions=False
                    assert ps_timescale and set(identifiers.values())==set(wanted.values()),identifiers
                continue
            if line.startswith("#"):
                flush(); timestamp=int(line[1:])
            elif line.startswith(("b","B")):
                bits,identifier=line[1:].split()
                if identifier in identifiers:
                    changes[identifiers[identifier]]=int(bits,2) if not set(bits.lower()) & {"x","z"} else None
            elif line and line[0] in "01xzXZ" and line[1:] in identifiers:
                changes[identifiers[line[1:]]]=int(line[0]) if line[0] in "01" else None
        flush()
    assert edge_count>1 and stop is not None and first is not None
    period=(last-first)/(edge_count-1)
    assert stop-start>=6_000_000_000 and 17855<=period<=17860,(stop-start,period)
    return dict(edge_count=edge_count,observed_adc_period_ns=period/1000,
        observed_adc_rate_mhz=1e6/period,audit_start_ps=start,audit_end_ps=stop)


def validate(modelsim=Path(r"D:\modeltech64_2020.4\win64")):
    row=(OUT/"realtime_stats.txt").read_text(encoding="ascii").split()
    assert len(row)==17,row
    values=[int(v,16) if k==14 else int(v) for k,v in enumerate(row)]
    (stimulus,start,stop,adc,capture,mix,cic,iq,written,read,byte_count,
     backpressure,min_credit,rf,phase,epoch,last_index)=values
    observed=observe_adc_clock(modelsim)
    assert stop-start>=6_000_000_000 and adc==observed["edge_count"],(adc,observed)
    assert adc==capture==mix and 0<=cic-iq<=1 and iq-1<=written<=iq
    assert read<=written and backpressure>0 and min_credit==0
    data=bytes(int(v,16) for v in (OUT/"realtime_bytes.txt").read_text(encoding="ascii").split())
    assert len(data)==byte_count and len(data)%512==0
    accepted=[tuple(map(int,line.split())) for line in
        (OUT/"realtime_iq.txt").read_text(encoding="ascii").splitlines()]
    payload_source="actual FIFO wrreq log"
    assert len(accepted)==written
    assert [v[0] for v in accepted]==list(range(written)),"FIFO accepted repeated/missing IQ index"
    next_index=0
    for sequence,pos in enumerate(range(0,len(data),512)):
        frame=data[pos:pos+512]
        h=struct.unpack("<15I",frame[:60])
        assert h[:7]==(0x31524346,0x003c0002,sequence,epoch,next_index,112,0),h
        assert h[7:11]==(56000000,500000,rf,phase),h
        block=accepted[next_index:next_index+112]
        assert len(block)==112
        assert h[11]==(2|16|(8 if next_index<66 else 0)|(4 if any(v[3] for v in block) else 0)),h
        assert h[12:]==(42,112,0),h
        assert zlib.crc32(frame[:508])==struct.unpack_from("<I",frame,508)[0]
        payload=struct.unpack("<224h",frame[60:508])
        expected=tuple(value for _,i,q,_ in block for value in (i,q))
        assert payload==expected,("FIFO-to-USB IQ payload missing/repeated/reordered",sequence,next_index)
        next_index+=112
    assert abs(rf-93370000)<=12000,("automatic estimate",rf)
    # Count all IQ generated in the audited stream; queued trailing data at the
    # simulation stop is not silently counted as already received by the host.
    assert next_index<=read<=written<=last_index
    assert last_index-next_index<224,("excessive unsent normal stream backlog",last_index,next_index)
    return dict(status="passed",scope="continuous locked stream with normal USB and bounded backpressure",
        adc_rate=56000000,iq_rate=500000,initial_lock_prepare_us=(start-stimulus)/1e6,
        audited_duration_us=(stop-start)/1e6,continuous_adc_clocks=adc,captured_adc_clocks=capture,
        external_adc_clock_observation=observed,
        mixed_adc_clocks=mix,cic_outputs=cic,iq_outputs=iq,fifo_accepted_iq=written,
        fifo_consumed_iq=read,usb_bytes=len(data),complete_frames=len(data)//512,
        received_iq=next_index,trailing_iq_pending=last_index-next_index,
        missing_received_iq=0,fifo_dropped_iq=0,payload_checked_iq=next_index,
        payload_source=payload_source,short_backpressure_clocks=backpressure,
        rf_estimate_hz=rf,phase_step=phase,epoch=epoch,
        exclusions="Initial frequency acquisition, retuning, deliberate host pause and unbounded USB stalls")


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--modelsim",type=Path,default=Path(r"D:\modeltech64_2020.4\win64"))
    p.add_argument("--quartus",type=Path,default=Path(r"D:\intelFPGA\18.1\quartus"))
    p.add_argument("--timeout",type=int,default=1200)
    a=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True); (OUT/"rtl").mkdir(exist_ok=True)
    for file in (ROOT/"rtl").glob("*.hex"): shutil.copyfile(file,OUT/"rtl"/file.name)
    def run(tool,args,label,timeout=240):
        process=subprocess.Popen([str(a.modelsim/(tool+".exe")),*map(str,args)],cwd=OUT,
            stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,errors="replace")
        try:
            stdout,stderr=process.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],
                capture_output=True,text=True,check=False)
            stdout,stderr=process.communicate()
            (OUT/(label+".log")).write_text(stdout+stderr,encoding="utf-8")
            raise RuntimeError(f"{label} timed out after {timeout}s")
        log=stdout+stderr
        (OUT/(label+".log")).write_text(log,encoding="utf-8")
        assert process.returncode==0 and "** Error" not in log and "** Fatal" not in log,log[-5000:]
        print(label+": passed",flush=True); return log
    run("vlib",["work"],"library")
    libraries=[a.quartus/"eda/sim_lib"/name for name in
        ("altera_primitives.v","220model.v","altera_mf.v","cycloneive_atoms.v")]
    run("vlog",["-sv",*libraries,*sorted((ROOT/"ip").glob("*.v")),
        *sorted((ROOT/"rtl").glob("*.v")),ROOT/"tests/realtime_tb.sv"],"compile")
    signals=("adc_clk","audit")
    internal=("stream_sample_n","stream_usb_n","sample_phase","rf_hz","epoch","dropped",
        "fifo_full","fifo_read","iq_valid","iq_i","iq_q","dsp_error",
        "dsp/capture_valid","dsp/mix_valid","dsp/cic_i/count","dsp/ci_valid",
        "tx_valid","tx_ready","detector/locked")
    paths=["/realtime_tb/"+s for s in signals]+["/realtime_tb/dut/"+s for s in internal]
    wlf=OUT/"realtime56.wlf"
    if wlf.exists(): wlf.unlink()
    do="onerror {quit -code 1}; onbreak {quit -code 1}; log "+" ".join(paths)+"; run -all; quit -code 0"
    # Preserve only the two external waveform observation points. TB hierarchy
    # references already preserve the DUT signals used by assertions/logging.
    # Blanket +acc also preserves generated-IP internals and is much slower.
    access="-voptargs=+acc=n+/realtime_tb/adc_clk +acc=r+/realtime_tb/audit"
    log=run("vsim",["-c",access,"-wlf",wlf.name,"work.realtime_tb","-do",do],
        "realtime56",a.timeout)
    assert "REALTIME_PASS" in log and "vsim-WLF-5000" not in log
    assert "No objects found matching" not in log,"Required WLF observation point was optimized away"
    result=validate(a.modelsim)
    (OUT/"summary.json").write_text(json.dumps(result,indent=2),encoding="utf-8")
    print("Locked realtime processing: every ADC clock, fixed IQ cadence, normal USB CRC/index, zero loss PASS")


if __name__=="__main__": main()
