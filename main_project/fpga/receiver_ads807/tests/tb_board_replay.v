`timescale 1ns/1ps
module tb_board_replay;
    reg clk;
    reg rst_n;
    wire [7:0] dq;
    wire pclk;
    wire wr_n;
    wire rd_n;
    wire cs_n;
    wire oe_n;
    wire a0;
    wire a1;
    wire pktend;
    wire pa0;
    wire led;
    reg [7:0] commands [0:4095];
    integer command_position;
    integer command_limit;
    integer bytes_file;
    integer iq_file;
    integer samples_file;
    integer sample_count;
    integer packet;
    wire flagb;
    wire flagc;
    assign #13.5 flagb = 1'b1;
    assign #13.5 flagc = a1 && command_position < command_limit;
    assign #15 dq = !oe_n && a1 && command_position < command_limit ? commands[command_position] : 8'bz;
    receiver_top dut(
        .clk(clk), .rst_n(rst_n), .usb_dq(dq), .usb_flagb(flagb), .usb_flagc(flagc),
        .usb_pa1(1'b1), .usb_pclk(pclk), .usb_wr(wr_n), .usb_rd(rd_n),
        .usb_pa7(cs_n), .usb_pa6(pktend), .usb_pa5(a1), .usb_pa4(a0),
        .usb_pa2(oe_n), .usb_pa0(pa0), .led(led)
    );
    initial begin
        clk = 0;
        forever #20.833333 clk = ~clk;
    end
    always @(posedge pclk) begin
        if (!cs_n && !rd_n && a1) begin
            if (command_position >= command_limit) begin
                $fatal(1, "Read empty FX2 OUT");
            end
            command_position = command_position + 1;
        end
        if (!cs_n && !wr_n && !a1) begin
            if (^dq === 1'bx) begin
                $fatal(1, "FX2 bus contention");
            end
            $fdisplay(bytes_file, "%02x", dq);
        end
    end
    always @(posedge dut.sample_clk) begin
        if (dut.sample_rst_n) begin
            if (sample_count < 20000) begin
                $fdisplay(samples_file, "%0d", dut.adc_registered);
            end
            sample_count = sample_count + 1;
        end
        if (dut.dsp_run && dut.iq_valid) begin
            if (dut.fifo_full || dut.dsp_error) begin
                $fatal(1, "DSP deadline or FIFO overflow");
            end
            $fdisplay(iq_file, "%0d %0d %0d %0d", dut.epoch, dut.sample_index, dut.iq_i, dut.iq_q);
        end
    end
    initial begin
        rst_n = 0;
        command_position = 0;
        command_limit = 0;
        sample_count = 0;
        bytes_file = $fopen("bytes.txt", "w");
        iq_file = $fopen("iq.txt", "w");
        samples_file = $fopen("samples.txt", "w");
        $readmemh("commands.hex", commands);
        #1000;
        rst_n = 1;
        #200000;
        for (packet = 0; packet < 5; packet = packet + 1) begin
            command_limit = (packet+1)*512;
            wait (command_position == command_limit);
            #180000;
        end
        #6000000;
        command_limit = 6*512;
        wait (command_position == command_limit);
        #300000;
        $fclose(bytes_file);
        $fclose(iq_file);
        $fclose(samples_file);
        $display("BOARD_REPLAY_PASS");
        $finish;
    end
    initial begin
        #12000000;
        $fatal(1, "Simulation watchdog");
    end
endmodule
