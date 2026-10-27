"""Create/map/fit/time using local Quartus. No programming or ADC pin guessing."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
LOG=ROOT.parents[2]/".harness/receiver/build"

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--rate",choices=("56",),default="56")
    p.add_argument("--quartus",type=Path,default=Path(r"D:\intelFPGA\18.1\quartus"))
    a=p.parse_args()
    LOG.mkdir(parents=True,exist_ok=True)
    name="receiver"+a.rate
    commands=[("project",[a.quartus/"bin64/quartus_sh.exe","-t","scripts/project.tcl",a.rate]),
              ("map",[a.quartus/"bin64/quartus_map.exe",name]),
              ("fit",[a.quartus/"bin64/quartus_fit.exe",name]),
              ("sta",[a.quartus/"bin64/quartus_sta.exe","-t","scripts/timing.tcl",name])]
    summary={"rate":a.rate,"adc_pins":"virtual; not ready for programming","steps":{}}
    try:
        for stage,command in commands:
            with (LOG/f"{name}_{stage}.log").open("w",encoding="utf-8") as log:
                r=subprocess.run(list(map(str,command)),cwd=ROOT,stdout=log,
                                 stderr=subprocess.STDOUT,timeout=900)
            summary["steps"][stage]=r.returncode
            print(f"{name} {stage}: {r.returncode}",flush=True)
            if r.returncode: raise RuntimeError(f"{stage} failed; see {LOG}")
            content=(LOG/f"{name}_{stage}.log").read_text(encoding="utf-8")
            if "Ignored " in content and stage in ("fit","sta"):
                raise RuntimeError("Ignored timing constraints; see "+str(LOG))
        clock_report=(ROOT/f"{name}_clocks.rpt").read_text(errors="replace")
        clocks={}
        for index,expected in ((0,56.0),(1,24.0)):
            matches=re.findall(
                rf";\s*[^;]*\|clk\[{index}\]\s*;\s*Generated\s*;\s*[\d.]+\s*;\s*([\d.]+)\s+MHz",
                clock_report)
            actual=[float(value) for value in matches]
            assert len(actual)==1 and abs(actual[0]-expected)<.01, (index,actual,expected)
            clocks["adc" if index==0 else "usb"]=actual[0]
        summary["reported_pll_clocks_mhz"]=clocks
        slacks={}
        for report in ROOT.glob(f"{name}_corner*_*.rpt"):
            match=re.search(r"Worst case slack is ([\d.-]+)",report.read_text(errors="replace"))
            if match: slacks[report.stem]=float(match[1])
        summary["constrained_corner_slacks_ns"]=slacks
        summary["constrained_timing_pass"]=bool(slacks) and all(v>=0 for v in slacks.values())
        summary["board_timing"]="incomplete: ADC virtual pins, zero PCB skew model, see check_timing/UCP"
        assert summary["constrained_timing_pass"],slacks
    finally:
        (LOG/f"{name}_summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")

if __name__=="__main__": main()
