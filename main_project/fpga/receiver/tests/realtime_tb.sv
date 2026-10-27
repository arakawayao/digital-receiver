`timescale 1ns/1ps
// Autonomous acquisition first, then a continuous locked stream. The reference
// input is only adc_data: no RF truth, host command, or forced DUT state is used.
module realtime_tb;
    localparam real SOURCE_PERIOD_NS=41.667;
    reg clk=0; always #(SOURCE_PERIOD_NS/2.0) clk=~clk;
    reg rst_n=0, pause=1;
    reg [11:0] adc=2048;
    wire adc_clk;
    tri [7:0] dq;
    wire pclk,wr,rd,pa7,pa6,pa5,pa4,pa2,pa0,led;
    reg flagb=1;
    receiver_top dut(.clk(clk),.rst_n(rst_n),.adc_data(adc),
        .adc_clk(adc_clk),.usb_dq(dq),.usb_flagb(flagb),.usb_flagc(1'b0),.usb_pa1(pause),
        .usb_pclk(pclk),.usb_wr(wr),.usb_rd(rd),.usb_pa7(pa7),.usb_pa6(pa6),
        .usb_pa5(pa5),.usb_pa4(pa4),.usb_pa2(pa2),.usb_pa0(pa0),.led(led));

    integer n=0,received=0,usb_cycles=0,credit=16,byte_file,stats_file,iq_file;
    integer adc_cycles=0,capture_cycles=0,mix_cycles=0,cic_outputs=0,iq_outputs=0;
    integer fifo_writes=0,fifo_reads=0,last_cic=-1,last_iq=-1;
    integer backpressure_cycles=0,minimum_credit=16;
    reg audit=0;
    reg [31:0] locked_phase,locked_rf,locked_epoch;
    reg signed [11:0] pin_sample;
    reg [31:0] phase_before;
    reg [6:0] cic_count_before;
    reg fifo_write_before,iq_valid_before;
    time stimulus_time,audit_start,audit_end;
    real t,amplitude,value,adc_period;
    realtime first_adc_edge,last_adc_edge;

    always @(negedge adc_clk) begin
        t=1.0*n/56000000.0;
        amplitude=800.0*(1.0+0.5*$cos(6.283185307179586*5000.0*t));
        value=amplitude*$cos(6.283185307179586*93370000.0*t);
        adc=2048+$rtoi(value>=0.0 ? value+0.5 : value-0.5);
        n=n+1;
    end

    // Check the whole locked interval on the external ADC clock. No stream
    // reset is accepted, and no log is filtered by internal valid/enable bits.
    always @(posedge adc_clk) begin
        if(audit) begin
            if(adc_cycles==0) first_adc_edge=$realtime;
            last_adc_edge=$realtime;
            pin_sample=$signed({1'b0,adc})-13'sd2048;
            phase_before=dut.dsp.mixer.phase;
            cic_count_before=dut.dsp.cic_i.count;
            fifo_write_before=dut.fifo.wrreq;
            iq_valid_before=dut.iq_valid;
            if(!dut.stream_sample_n || !dut.stream_usb_n || !dut.detector.locked)
                $fatal(1,"Locked interval unexpectedly reset or lost lock");
            if(dut.sample_phase!==locked_phase || dut.rf_hz!==locked_rf || dut.epoch!==locked_epoch)
                $fatal(1,"Locked tuning/epoch unexpectedly changed");
            if(dut.fifo_full || dut.dropped!=0 || dut.dsp_error)
                $fatal(1,"Normal USB reception lost IQ or exceeded DSP deadline");
            if(fifo_write_before!==iq_valid_before)
                $fatal(1,"Produced IQ was not accepted by acquisition FIFO");
            if(fifo_write_before) begin
                fifo_writes=fifo_writes+1;
                $fdisplay(iq_file,"%0d %0d %0d %0d",dut.index,$signed(dut.iq_i),
                    $signed(dut.iq_q),dut.iq_clip);
            end
            #1;
            adc_cycles=adc_cycles+1;
            if(dut.dsp.capture_valid!==1'b1 || dut.dsp.sample!==pin_sample)
                $fatal(1,"ADC capture missing/misaligned at continuous clock %0d",adc_cycles);
            if(dut.dsp.mix_valid!==1'b1)
                $fatal(1,"Mixer skipped continuous ADC clock %0d",adc_cycles);
            if(dut.dsp.mixer.phase!==(phase_before+locked_phase))
                $fatal(1,"NCO phase did not advance exactly once per ADC sample");
            if(dut.dsp.cic_i.count!==(cic_count_before==111 ? 7'd0 : cic_count_before+7'd1))
                $fatal(1,"CIC input sample count skipped/repeated a clock");
            if(dut.dsp.cic_q.count!==dut.dsp.cic_i.count || dut.dsp.ci_valid!==dut.dsp.cq_valid)
                $fatal(1,"CIC I/Q lanes misaligned");
            capture_cycles=capture_cycles+1;
            mix_cycles=mix_cycles+1;
            if(dut.dsp.ci_valid) begin
                if(last_cic>=0 && adc_cycles-last_cic!=112)
                    $fatal(1,"CIC output cadence is not 112 ADC clocks");
                last_cic=adc_cycles; cic_outputs=cic_outputs+1;
            end
            if(dut.iq_valid) begin
                if(last_iq>=0 && adc_cycles-last_iq!=112)
                    $fatal(1,"FIR/IQ output cadence is not 112 ADC clocks");
                last_iq=adc_cycles; iq_outputs=iq_outputs+1;
            end
        end
    end

    // Average credit refill is 6 MB/s, with 2.5 us stalls every 41.5 us.
    // This endpoint is intentionally limited but can sustain the 2.286 MB/s
    // framed stream. Its short backpressure must never propagate into capture.
    always @(posedge pclk) begin
        usb_cycles=usb_cycles+1;
        if(!pa7 && !wr) begin
            if(pa5 || pa4 || !rd || !pa2 || !flagb || credit==0 || (^dq===1'bx))
                $fatal(1,"Invalid normal EP2 write");
            credit=credit-1;
            $fdisplay(byte_file,"%02x",dq);
            received=received+1;
        end
        if(!pa7 && !rd) $fatal(1,"Unexpected host configuration read");
        if(usb_cycles%4==0 && usb_cycles%997>=60 && credit<16) credit=credit+1;
        if(credit<minimum_credit) minimum_credit=credit;
        flagb<=#13.5 credit!=0;
    end

    reg held=0;
    reg [7:0] held_byte;
    always @(posedge dut.usb_clk) begin
        if(dut.stream_usb_n && held && (!dut.tx_valid || dut.tx_data!==held_byte))
            $fatal(1,"Packet byte changed during normal USB backpressure");
        held=dut.stream_usb_n && dut.tx_valid && !dut.tx_ready;
        held_byte=dut.tx_data;
        if(audit && held) backpressure_cycles=backpressure_cycles+1;
        if(audit && dut.fifo_read) fifo_reads=fifo_reads+1;
    end

    initial begin
        byte_file=$fopen("realtime_bytes.txt","w");
        stats_file=$fopen("realtime_stats.txt","w");
        iq_file=$fopen("realtime_iq.txt","w");
        #500; rst_n=1;
        wait(dut.usb_reset_n); pause=0; stimulus_time=$time;
        wait(dut.stream_sample_n && dut.stream_usb_n);
        // Allow only the fixed capture/mixer startup latency, before any IQ is
        // generated. The audit subsequently accepts zero skipped ADC clocks.
        repeat(5) @(negedge adc_clk);
        locked_phase=dut.sample_phase; locked_rf=dut.rf_hz; locked_epoch=dut.epoch;
        if(received!=0 || dut.index!=0) $fatal(1,"Audit began after output samples were already produced");
        audit_start=$time; audit=1;
        #6000000;
        // Finish after a complete USB frame. Acquisition remains running while
        // queued trailing IQ awaits future frames; it is counted separately.
        wait(received>=512 && received%512==0);
        @(negedge adc_clk); audit_end=$time; audit=0;
        adc_period=(last_adc_edge-first_adc_edge)/(adc_cycles-1);
        $fdisplay(stats_file,"%0t %0t %0t %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %08x %0d %0d",
            stimulus_time,audit_start,audit_end,adc_cycles,capture_cycles,mix_cycles,
            cic_outputs,iq_outputs,fifo_writes,fifo_reads,received,backpressure_cycles,
            minimum_credit,locked_rf,locked_phase,locked_epoch,dut.index);
        $fflush(stats_file);
        // Observe the real generated ADC edges. At 1 ps simulator resolution
        // #20.8335 ns is rounded, and the vendor PLL also rounds its phases.
        // Each actual edge is asserted above; there is no allowed missing-edge
        // budget inferred from an ideal nominal frequency.
        if(audit_end-audit_start<6000000 || adc_cycles<2 || adc_period<17.855 ||
           adc_period>17.860 || capture_cycles!=adc_cycles || mix_cycles!=adc_cycles)
            $fatal(1,"Insufficient uninterrupted locked capture");
        if(iq_outputs<2900 || cic_outputs-iq_outputs<0 || cic_outputs-iq_outputs>1)
            $fatal(1,"CIC to FIR produced missing output samples");
        if(fifo_writes<iq_outputs-1 || fifo_writes>iq_outputs)
            $fatal(1,"FIFO did not accept every produced IQ sample");
        if(fifo_reads>fifo_writes || backpressure_cycles==0 || minimum_credit!=0)
            $fatal(1,"Normal backpressure scenario not exercised correctly");
        $fclose(byte_file); $fclose(stats_file); $fclose(iq_file);
        $display("REALTIME_PASS ADC clocks=%0d IQ=%0d USB bytes=%0d ADC period=%0.9f ns",
            adc_cycles,iq_outputs,received,adc_period);
        $finish;
    end
    initial begin #12000000; $fatal(1,"Realtime acquisition timeout"); end
endmodule
