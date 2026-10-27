"""ModelSim autonomous-carrier checks. Uses no externally supplied tuning."""
import argparse
import json
import math
from pathlib import Path
import random
import subprocess

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT.parents[2]/".harness/receiver/frequency"
FS=56000000
WINDOW=65536


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--modelsim",type=Path,default=Path(r"D:\modeltech64_2020.4\win64"))
    args=parser.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    rng=random.Random(56108)
    scenarios=[]
    cycle=0
    with (OUT/"inputs.txt").open("w",encoding="ascii") as stream:
        def segment(kind,rf=None,amp=800,dc=0,noise=0,reset=True):
            nonlocal cycle
            sid=len(scenarios)
            start=cycle
            if reset:
                for _ in range(8):
                    stream.write(f"0 2048 {sid}\n");cycle+=1
            for n in range(5*WINDOW):
                if kind=="noise": value=rng.gauss(0,300)
                elif kind=="silence": value=0
                else:
                    t=n/FS
                    phase=math.tau*rf*t
                    envelope=1
                    if kind=="am": envelope=1+.8*math.sin(math.tau*5000*t)
                    if kind=="fm": phase+=15*math.sin(math.tau*5000*t) # +/-75 kHz
                    value=amp*envelope*math.cos(phase)
                    if noise: value+=rng.gauss(0,noise)
                raw=max(0,min(4095,2048+round(dc+value)))
                stream.write(f"1 {raw} {sid}\n");cycle+=1
            scenarios.append(dict(kind=kind,rf=rf,start=start,end=cycle,amp=amp,dc=dc,noise=noise))
        for rf in (88000000,90000000,98000000,103000000,108000000): segment("tone",rf)
        segment("am",98500000)
        segment("fm",100700000)
        segment("tone",97000000,dc=400)
        segment("tone",96500000,noise=20)
        segment("silence")
        segment("silence",dc=800)
        segment("noise")
        segment("tone",95000000,amp=12)
        segment("tone",95000000,amp=4096)
        segment("tone",85000000)
        segment("tone",110000000)
        segment("tone",98000000)
        segment("tone",105000000,reset=False)
        segment("silence",reset=False)
        segment("tone",91000000,reset=False)
    def run(tool,argv,label,timeout=300):
        result=subprocess.run([str(args.modelsim/(tool+".exe")),*map(str,argv)],
            cwd=OUT,capture_output=True,text=True,errors="replace",timeout=timeout)
        (OUT/(label+".log")).write_text(result.stdout+result.stderr,encoding="utf-8")
        assert result.returncode==0 and "** Error" not in result.stdout and "** Fatal" not in result.stdout, result.stdout[-3000:]+result.stderr
        return result.stdout
    run("vlib",["work"],"library")
    run("vlog",["-sv",ROOT/"rtl/rx_frequency.v",ROOT/"tests/frequency_tb.sv"],"compile")
    output=run("vsim",["-c","-voptargs=+acc","-wlf","frequency.wlf","work.frequency_tb",
        "-do","onerror {quit -code 1}; onbreak {quit -code 1}; log -r /*; run -all; quit -code 0"],"frequency")
    assert "FREQUENCY_PASS" in output
    rows=[tuple(map(int,line.split())) for line in (OUT/"outputs.txt").read_text().splitlines()]
    summary=[]
    for sid,scenario in enumerate(scenarios):
        valid=scenario["kind"] not in ("silence","noise") and 64<=scenario["amp"]<=1500 and 88000000<=scenario["rf"]<=108000000
        records=[r for r in rows if r[1]==sid and r[0]>=scenario["start"]+2*WINDOW]
        assert records,(sid,scenario)
        latest=records[-1]
        if valid:
            assert latest[2]==1,("failed acquisition",scenario,records)
            error=latest[7]-scenario["rf"]
            limit=5000 if scenario["kind"]=="fm" else 2000
            assert abs(error)<=limit,("RF error",scenario,error,records)
            wanted_alias=112000000-scenario["rf"]
            actual_alias=latest[6]*FS/2**32
            assert abs(actual_alias-wanted_alias)<=limit,(scenario,actual_alias)
            # Frozen LO after acquisition: no periodic reset/relock for stable RF.
            updates=[r for r in rows if r[1]==sid and r[3]]
            assert len(updates)==1,("unnecessary relock",scenario,updates)
        else:
            assert not any(r[2] for r in records),("false lock",scenario,records)
            error=None
        summary.append(dict(**scenario,locked=bool(latest[2]),rf_estimate=latest[7],rf_error_hz=error))
    (OUT/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
    print(f"Autonomous 56 MHz frequency ModelSim: {len(summary)} scenarios PASS")


if __name__=="__main__": main()
