`timescale 1ns/1ps
module tb_dual;
    reg clk;
    reg rst_n;
    reg [11:0] adc;
    reg signal_present;
    reg tx_allowed;
    wire adc_clk;
    wire [7:0] dq;
    wire ifclk;
    wire wr_n;
    wire rd_n;
    wire cs_n;
    wire oe_n;
    wire a0;
    wire a1;
    wire led;
    reg [7:0] commands [0:12287];
    integer out_position;
    integer out_limit;
    integer sample_number;
    integer raw;
    integer bytefile;
    integer iqfile;
    integer epoch_before;
    integer index_before;
    real t;

    assign dq = !cs_n && !oe_n && a1 && out_position < out_limit ? commands[out_position] : 8'bz;
    receiver_top dut(
        .clk(clk), .rst_n(rst_n), .adc_data(adc), .adc_otr(1'b0), .adc_clk(adc_clk),
        .usb_dq(dq), .usb_flagb(!a1 && tx_allowed),
        .usb_flagc(a1 && out_position < out_limit), .usb_pa1(1'b0),
        .usb_pclk(ifclk), .usb_wr(wr_n), .usb_rd(rd_n), .usb_pa7(cs_n),
        .usb_pa2(oe_n), .usb_pa4(a0), .usb_pa5(a1), .led(led),
        .usb_pa6(), .usb_pa0()
    );
    initial begin
        clk = 0;
        forever #20.833333 clk = ~clk;
    end
    always @(negedge adc_clk) begin
        t = sample_number/43500000.0;
        raw = signal_present ? $rtoi(800.0*(1.0+0.5*$cos(6.28318530718*5000.0*t))*
            $cos(6.28318530718*98000000.0*t)) : 0;
        adc = 2048+raw;
        sample_number = sample_number+1;
    end
    always @(posedge ifclk) begin
        if (!cs_n && !rd_n && a1 && !oe_n) begin
            if (out_position >= out_limit) begin
                $fatal(1, "OUT read consumed empty FIFO");
            end
            out_position = out_position+1;
        end
        if (!cs_n && !wr_n && !a1) begin
            if (!tx_allowed) begin
                $fatal(1, "IN write ignored backpressure");
            end
            $fdisplay(bytefile, "%02x", dq);
        end
    end
    always @(posedge adc_clk) begin
        if (dut.dsp_run && dut.iq_valid) begin
            if (dut.dsp_error) begin
                $fatal(1, "DSP deadline error");
            end
            if (!dut.fifo_full) begin
                $fdisplay(iqfile, "%072x", {dut.estimate, dut.config_id, dut.sample_flags,
                    dut.phase_step, dut.tuned_rf, dut.epoch, dut.dropped,
                    dut.sample_index, dut.iq_q, dut.iq_i});
            end
        end
    end
    task send_command;
        input integer number;
        begin
            @(negedge ifclk);
            out_limit = (number+1)*512;
            wait (out_position == out_limit);
            #300000;
        end
    endtask
    initial begin
        rst_n = 0;
        adc = 2048;
        signal_present = 1;
        tx_allowed = 1;
        out_position = 0;
        out_limit = 0;
        sample_number = 0;
        bytefile = $fopen("dual_bytes.txt", "w");
        iqfile = $fopen("dual_iq.txt", "w");
        $readmemh("commands.hex", commands);
        #100;
        rst_n = 1;
        wait (dut.tuned && dut.dsp_run);
        if (dut.phase_step != dut.detector_step) begin
            $fatal(1, "Automatic tuning did not use the detector phase step");
        end
        #600000;
        send_command(0);
        send_command(1);
        signal_present = 0;
        send_command(2);
        if (!dut.tuned || !dut.dsp_run || dut.tuned_rf != 98000000 || dut.phase_step != 1086083684) begin
            $fatal(1, "Manual tuning requires estimator lock");
        end
        send_command(3);
        send_command(4);
        send_command(5);
        epoch_before = dut.epoch;
        index_before = dut.sample_index;
        #4000000;
        if (!dut.dsp_run || dut.epoch != epoch_before || dut.sample_index <= index_before || !dut.flags[10]) begin
            $fatal(1, "Low confidence reset the stream or hold timer failed");
        end
        send_command(6);
        send_command(7);
        @(negedge ifclk);
        tx_allowed = 0;
        #1500000;
        @(negedge ifclk);
        tx_allowed = 1;
        #1000000;
        if (dut.dropped == 0) begin
            $fatal(1, "FIFO backpressure did not expose loss");
        end
        send_command(8);
        send_command(9);
        send_command(10);
        send_command(11);
        send_command(12);
        if (dut.running || dut.dsp_run) begin
            $fatal(1, "STOP failed");
        end
        signal_present = 1;
        send_command(13);
        wait (dut.tuned && dut.dsp_run);
        #600000;
        send_command(14);
        signal_present = 0;
        epoch_before = dut.epoch;
        #4000000;
        if (dut.detector_locked || !dut.dsp_run || dut.epoch != epoch_before) begin
            $fatal(1, "Automatic holdover reset tuned DSP");
        end
        send_command(15);
        send_command(16);
        send_command(17);
        send_command(18);
        if (!dut.dsp_run || dut.epoch != epoch_before) begin
            $fatal(1, "Rejected command changed the stream");
        end
        send_command(19);
        epoch_before = dut.epoch;
        send_command(20);
        send_command(21);
        send_command(22);
        if (dut.tuned || dut.epoch != epoch_before) begin
            $fatal(1, "Invalid phase step changed tuning");
        end
        send_command(23);
        if (!dut.dsp_run || dut.tuned_rf != 98000000 || dut.phase_step != 1086083684) begin
            $fatal(1, "Version 2 manual tune failed");
        end
        #500000;
        $fclose(bytefile);
        $fclose(iqfile);
        $display("DUAL_PASS");
        $finish;
    end
    initial begin
        #40000000;
        $fatal(1, "Dual receiver timeout");
    end
endmodule
