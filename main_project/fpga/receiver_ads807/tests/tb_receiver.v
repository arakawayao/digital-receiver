`timescale 1ns/1ps
module tb_receiver;
    reg clk;
    reg rst_n;
    reg [11:0] adc;
    reg signal_present;
    wire adc_clk;
    wire [7:0] usb_dq;
    wire usb_pclk;
    wire usb_wr;
    wire usb_rd;
    wire usb_pa7;
    wire usb_pa6;
    wire usb_pa5;
    wire usb_pa4;
    wire usb_pa2;
    wire usb_pa0;
    wire led;
    integer sample_number;
    integer raw;
    integer bytefile;
    integer iqfile;
    integer iq_count;
    integer adc_count;
    integer byte_count;
    integer last_iq_cycle;
    integer audit;
    real sample_time;
    real amplitude;
    receiver_top dut(
        .clk(clk), .rst_n(rst_n), .adc_data(adc), .adc_clk(adc_clk),
        .usb_dq(usb_dq), .usb_flagb(1'b1), .usb_flagc(1'b0), .usb_pa1(1'b0),
        .usb_pclk(usb_pclk), .usb_wr(usb_wr), .usb_rd(usb_rd),
        .usb_pa7(usb_pa7), .usb_pa6(usb_pa6), .usb_pa5(usb_pa5),
        .usb_pa4(usb_pa4), .usb_pa2(usb_pa2), .usb_pa0(usb_pa0), .led(led)
    );
    initial begin
        clk = 0;
        forever #20.833333 clk = ~clk;
    end
    // Only the real ADC bus is driven; RF/LO truth is never injected into the DUT.
    always @(negedge adc_clk) begin
        sample_time = sample_number/43500000.0;
        amplitude = 800.0*(1.0+0.5*$cos(6.283185307179586*5000.0*sample_time));
        raw = signal_present ? $rtoi(amplitude*$cos(6.283185307179586*98000000.0*sample_time)) : 0;
        adc = 2048+raw;
        sample_number = sample_number+1;
    end
    always @(posedge adc_clk) begin
        if (dut.stream_sample_n) begin
            adc_count = adc_count+1;
            if (dut.dsp_error || dut.fifo_full || dut.dropped != 0) begin
                $fatal(1, "Normal receive path lost samples or FIR deadline");
            end
            if (dut.iq_valid && audit) begin
                if (iq_count > 0 && adc_count-last_iq_cycle != 87) begin
                    $fatal(1, "I/Q spacing is not 87 ADC clocks");
                end
                last_iq_cycle = adc_count;
                iq_count = iq_count+1;
                $fdisplay(iqfile, "%d %d %d", dut.index, dut.iq_i, dut.iq_q);
            end
        end
    end
    always @(posedge usb_pclk) begin
        if (!usb_pa7 && !usb_wr && audit) begin
            $fdisplay(bytefile, "%02x", usb_dq);
            byte_count = byte_count+1;
        end
    end
    initial begin
        rst_n = 0;
        adc = 2048;
        signal_present = 1;
        sample_number = 0;
        iq_count = 0;
        adc_count = 0;
        byte_count = 0;
        last_iq_cycle = 0;
        audit = 1;
        bytefile = $fopen("receiver_bytes.txt", "w");
        iqfile = $fopen("receiver_iq.txt", "w");
        #100;
        rst_n = 1;
        wait (dut.stream_sample_n);
        $display("RECEIVER_LOCK time=%0t RF=%0d", $time, dut.detected_rf);
        #3000000;
        if (iq_count < 1400 || byte_count < 5120 || !led) begin
            $fatal(1, "Insufficient continuous receiver output");
        end
        @(negedge adc_clk);
        audit = 0;
        $fclose(bytefile);
        $fclose(iqfile);
        signal_present = 0;
        #4000000;
        if (dut.frequency_locked || dut.stream_sample_n) begin
            $fatal(1, "Silence did not release lock");
        end
        $display("RECEIVER_PASS IQ=%0d USBbytes=%0d", iq_count, byte_count);
        $finish;
    end
    initial begin
        #14000000;
        $fatal(1, "Receiver lock/output timeout");
    end
endmodule
