`timescale 1ns/1ps
// Unknown RF stimulus only enters through ADC pins. No tuning command or force.
module full_chain_tb;
    parameter ADC_RATE=56000000;
    reg clk=0; always #20.8335 clk=~clk;
    reg rst_n=0, pause=1;
    reg [11:0] adc=2048;
    wire adc_clk;
    tri [7:0] dq;
    wire pclk,wr,rd,pa7,pa6,pa5,pa4,pa2,pa0,led;
    reg flagb=1;
    receiver_top #(.ADC_RATE(ADC_RATE)) dut(.clk(clk),.rst_n(rst_n),.adc_data(adc),
        .adc_clk(adc_clk),.usb_dq(dq),.usb_flagb(flagb),.usb_flagc(1'b0),.usb_pa1(pause),
        .usb_pclk(pclk),.usb_wr(wr),.usb_rd(rd),.usb_pa7(pa7),.usb_pa6(pa6),
        .usb_pa5(pa5),.usb_pa4(pa4),.usb_pa2(pa2),.usb_pa0(pa0),.led(led));

    integer stage=-1,kind=3,rf=98000000,n=0;
    integer received=0,usb_cycles=0,credit=8,session=0;
    integer fi,fo,fs,noise_code;
    reg host_stall=0,saw_full=0,previous_stream=0;
    reg [31:0] noise_state=32'h4a715c29;
    real t,angle,amplitude,value;

    // kind: 0=unmodulated, 1=AM, 2=FM, 3=silence, 4=wideband noise.
    // RF and modulation truth remain in this testbench; DUT sees only adc_data.
    always @(negedge adc_clk) begin
        t=1.0*n/ADC_RATE;
        amplitude=kind==1 ? 800.0*(1.0+0.5*$cos(6.283185307179586*5000.0*t)) : 800.0;
        angle=6.283185307179586*rf*t;
        if(kind==2) angle=angle+5.0*$sin(6.283185307179586*5000.0*t);
        value=kind==3 ? 0.0 : amplitude*$cos(angle);
        if(kind==4) begin
            noise_state=noise_state^(noise_state<<13);
            noise_state=noise_state^(noise_state>>17);
            noise_state=noise_state^(noise_state<<5);
            noise_code=$signed(noise_state[11:0]);
            value=600.0*noise_code/2048.0;
        end
        adc=2048+$rtoi(value>=0.0 ? value+0.5 : value-0.5);
        n=n+1;
    end

    // Keep all running-stream samples and the first reset edge. Suppressing
    // subsequent reset-only rows does not alter an independent DSP replay.
    always @(posedge adc_clk) begin
        if(dut.stream_sample_n && !previous_stream) session=session+1;
        if(dut.stream_sample_n || previous_stream)
            $fdisplay(fi,"%0d %0d %0d %0d 1 %0d %08x %0d %0d",session,dut.epoch,
                stage,dut.stream_sample_n,adc,dut.sample_phase,dut.sample_conjugate,dut.rf_hz);
        previous_stream=dut.stream_sample_n;
        if(dut.stream_sample_n && dut.fifo_full) saw_full=1;
        if(dut.stream_sample_n && dut.dsp_error) $fatal(1,"DSP deadline error");
    end

    // A small endpoint deliberately stresses FULL. It is not a USB driver or
    // bandwidth measurement. FULL propagates 13.5 ns after a consumed credit.
    always @(posedge pclk) begin
        usb_cycles=usb_cycles+1;
        if(!pa7 && !wr) begin
            if(pa5 || pa4 || !rd || !pa2 || !flagb || credit==0 || (^dq===1'bx))
                $fatal(1,"Invalid EP2 transfer stage=%0d byte=%0d",stage,received);
            credit=credit-1;
            $fdisplay(fo,"%0d %0d %02x",stage,dut.epoch,dq);
            received=received+1;
        end
        if(!pa7 && !rd) $fatal(1,"Unexpected EP6 read: test sends no configuration");
        if(!host_stall && usb_cycles%101>10 && credit<8) credit=credit+1;
        flagb<=#13.5 credit!=0;
    end

    reg stalled=0;
    reg [7:0] saved_byte;
    always @(posedge dut.usb_clk) begin
        if(dut.stream_usb_n && stalled && (!dut.tx_valid || dut.tx_data!==saved_byte))
            $fatal(1,"Packet byte changed under USB backpressure");
        stalled=dut.stream_usb_n && dut.tx_valid && !dut.tx_ready;
        saved_byte=dut.tx_data;
    end

    task snapshot;
        input [191:0] label;
        begin
            $fdisplay(fs,"%0s %0d %0d %0d %0d %0d %0d %0t",label,stage,dut.epoch,
                received,dut.dropped,dut.index,dut.detector.locked,$time);
            $display("CHAIN_EVENT %0s stage=%0d epoch=%0d bytes=%0d RF_est=%0d",
                label,stage,dut.epoch,received,dut.rf_hz);
        end
    endtask

    task select_signal;
        input integer id,signal_kind,carrier;
        begin
            @(posedge adc_clk); #1;
            stage=id; kind=signal_kind; rf=carrier; n=0;
            noise_state=32'h4a715c29;
            snapshot("STIMULUS");
        end
    endtask

    task await_stream;
        input integer old_epoch;
        integer waited;
        begin
            waited=0;
            while(!(dut.stream_sample_n && dut.stream_usb_n && dut.epoch!=old_epoch) && waited<6000000) begin
                #1000; waited=waited+1000;
            end
            if(!(dut.stream_sample_n && dut.stream_usb_n && dut.epoch!=old_epoch))
                $fatal(1,"Automatic capture timeout stage=%0d epoch=%0d",stage,dut.epoch);
            if(!dut.detector.locked || dut.sample_conjugate!==1'b1)
                $fatal(1,"Released stream without automatic RF lock/conjugation");
            snapshot("LOCK");
        end
    endtask

    task capture_frames;
        input integer frames;
        integer baseline;
        begin
            baseline=received;
            wait(received>=baseline+frames*512);
            snapshot("CAPTURE");
            if(!led || !dut.detector.locked) $fatal(1,"Automatic receiver lost lock during capture");
        end
    endtask

    task expect_quiet;
        integer waited,baseline;
        begin
            waited=0;
            while((dut.stream_sample_n || dut.stream_usb_n || dut.detector.locked) && waited<2500000) begin
                #1000; waited=waited+1000;
            end
            if(dut.stream_sample_n || dut.stream_usb_n || dut.detector.locked)
                $fatal(1,"Silence/noise did not release RF lock stage=%0d",stage);
            #1000; baseline=received;
            snapshot("LOSS");
            // Observe longer than two detector windows so noise cannot pass
            // simply because an erroneous new lock has not happened yet.
            #3500000;
            if(dut.stream_sample_n || dut.stream_usb_n || dut.detector.locked || received!=baseline)
                $fatal(1,"Silence/noise fabricated a running stream stage=%0d",stage);
            snapshot("QUIET");
        end
    endtask

    integer previous_epoch,baseline;
    initial begin
        if(ADC_RATE!=56000000) $fatal(1,"Full chain uses fixed 56 MHz ADC clock");
        fi=$fopen("chain_inputs.txt","w"); fo=$fopen("chain_bytes.txt","w");
        fs=$fopen("chain_events.txt","w");
        #500; rst_n=1;
        wait(dut.usb_reset_n);

        previous_epoch=dut.epoch;
        select_signal(0,1,98000000); pause=0;
        await_stream(previous_epoch); capture_frames(6);
        previous_epoch=dut.epoch;
        select_signal(1,2,88000000);
        await_stream(previous_epoch); capture_frames(6);
        previous_epoch=dut.epoch;
        select_signal(2,2,108000000);
        await_stream(previous_epoch); capture_frames(6);
        previous_epoch=dut.epoch;
        select_signal(3,1,93370000);
        await_stream(previous_epoch); capture_frames(6);

        select_signal(4,3,93370000); expect_quiet();
        select_signal(5,4,93370000); expect_quiet();
        previous_epoch=dut.epoch;
        select_signal(6,1,98000000);
        await_stream(previous_epoch); capture_frames(6);

        // PA1 pauses data transport only. The detector may retain its estimate;
        // the resumed stream must still restart sample/packet counters and epoch.
        pause=1;
        wait(!dut.stream_sample_n && !dut.stream_usb_n);
        #1000; snapshot("PAUSE");
        #300000;
        previous_epoch=dut.epoch;
        select_signal(7,1,98000000); pause=0;
        await_stream(previous_epoch); capture_frames(6);

        stage=8; baseline=received; saw_full=0; host_stall=1;
        snapshot("STALL");
        #2000000;
        if(!saw_full || dut.dropped==0) $fatal(1,"USB stall did not overflow acquisition FIFO");
        snapshot("FULL"); host_stall=0;
        // Pass the stored old samples and the gap, then interrupt a frame.
        wait(received>=baseline+12*512+17);
        snapshot("OVERFLOW");
        pause=1;
        wait(!dut.stream_sample_n && !dut.stream_usb_n);
        #1000; snapshot("PAUSE");
        previous_epoch=dut.epoch;
        select_signal(9,1,98000000); pause=0;
        await_stream(previous_epoch); capture_frames(4);
        pause=1;
        wait(!dut.stream_sample_n && !dut.stream_usb_n);
        #1000; snapshot("END");
        $fclose(fi); $fclose(fo); $fclose(fs);
        $display("FULL_CHAIN_PASS rate=%0d",ADC_RATE); $finish;
    end
    initial begin #80000000; $fatal(1,"Full chain timeout stage=%0d bytes=%0d",stage,received); end
endmodule
