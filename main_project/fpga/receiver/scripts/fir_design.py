"""Pure-stdlib FIR-only 32 MHz -> 500 kS/s coefficient generation."""
from pathlib import Path
import cmath
import json
import math
ROOT=Path(__file__).resolve().parents[1]
HALFBAND=[-1,0,9,16,9,0,-1]
TAPS=111
PASS_HZ=100000
STOP_HZ=200000
FIR_RATE=2000000
FINAL_DECIMATION=4

def i0(x):
    term=total=1.0
    for k in range(1,100):
        term*=(x/(2*k))**2
        total+=term
        if term<total*1e-16:break
    return total

def response(coeff,frequency,rate,scale=1):
    # Symmetric real FIR, strip the irrelevant linear phase.
    mid=len(coeff)//2
    return abs((coeff[mid]+2*sum(coeff[mid-k]*math.cos(math.tau*frequency*k/rate)
               for k in range(1,mid+1)))/scale)

def halfband_response(f):
    return math.prod(response(HALFBAND,f,rate,32) for rate in (32000000,16000000,8000000,4000000))

def coefficients():
    mid=TAPS//2; beta=8.6; cutoff=(PASS_HZ+STOP_HZ)/2
    values=[]
    for n in range(TAPS):
        k=n-mid
        sinc=2*cutoff/FIR_RATE if k==0 else math.sin(math.tau*cutoff*k/FIR_RATE)/(math.pi*k)
        window=i0(beta*math.sqrt(max(0,1-(k/mid)**2)))/i0(beta)
        values.append(sinc*window)
    total=sum(values)
    q=[round(v/total*131072) for v in values]
    q[mid]+=131072-sum(q)
    assert q==q[::-1] and sum(q)==131072 and max(map(abs,q))<131072
    (ROOT/'rtl/fir_coeff32.hex').write_text(''.join(f'{v&0x3ffff:05x}\n' for v in q),encoding='ascii')
    nco=[round(2047*math.sin(math.tau*k/1024)) for k in range(1024)]
    (ROOT/'rtl/nco_sine.hex').write_text(''.join(f'{v&4095:03x}\n' for v in nco),encoding='ascii')
    def db(v):return 20*math.log10(max(v,1e-15))
    pass_db=[db(halfband_response(f)*response(q,f,FIR_RATE,131072)) for f in range(0,PASS_HZ+1,100)]
    stop_db=[db(halfband_response(f)*response(q,f,FIR_RATE,131072)) for f in range(STOP_HZ,FIR_RATE//2+1,250)]
    # Frequencies that fold into desired +/-100 kHz during the first /16.
    hb_alias=max(halfband_response(k*FIR_RATE+f) for k in range(1,9)
                 for f in range(-PASS_HZ,PASS_HZ+1,1000) if k*FIR_RATE+f<=28000000)
    # Subsequent /4 aliases, before discarding samples.
    final_alias=max(halfband_response(f)*response(q,f,FIR_RATE,131072)
                    for f in range(250000,FIR_RATE//2+1,250)
                    if abs((f+250000)%500000-250000)<=PASS_HZ)
    report=dict(architecture='FIR only: halfband /2 /2 /2 /2, symmetric FIR /4',
                adc_rate_hz=32000000,iq_rate_hz=500000,passband_hz=PASS_HZ,
                total_passband_hz=2*PASS_HZ,stopband_hz=STOP_HZ,
                final_input_rate_hz=FIR_RATE,final_decimation=FINAL_DECIMATION,
                taps=TAPS,halfband_coefficients=HALFBAND,
                halfband_shift=5,mixer_shift=3,coefficient_bits=18,coefficient_fraction_bits=17,
                pass_min_db=min(pass_db),pass_max_db=max(pass_db),stop_max_db=max(stop_db),
                halfband_fold_max_db=db(hb_alias),final_fold_max_db=db(final_alias),
                startup_iq_samples=32,coefficients=q)
    assert max(map(abs,pass_db))<0.05,report
    assert max(stop_db)<-65 and db(hb_alias)<-65 and db(final_alias)<-65,report
    (ROOT/'rtl/fir_coeff32_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k!='coefficients'},indent=2))
    return report

if __name__=='__main__':coefficients()
