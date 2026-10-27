`timescale 1ns/1ps
module tb_usb_replay;
    reg clk;
    reg rst_n;
    wire [7:0] dq;
    wire ifclk;
    wire wr_n;
    wire rd_n;
    wire cs_n;
    wire oe_n;
    wire a0;
    wire a1;
    wire pktend_n;
    wire pa0;
    wire led;
    wire flagb;
    wire flagc;
    reg [7:0] commands [0:32767];
    reg [11:0] pattern [0:8191];
    reg [7:0] packet [0:511];
    integer command_count;
    integer pattern_length;
    integer host_head;
    integer host_tail;
    integer byte_count;
    integer ack_count;
    integer iq_frames;
    integer iq_samples;
    integer replay_samples;
    integer replay_index;
    integer sample_cycles;
    integer last_iq_cycle;
    integer output_file;
    integer iq_file;
    integer n;
    reg capture;

    assign #13.5 flagb = !a1;
    assign #13.5 flagc = a1 && host_head < host_tail;
    assign #15 dq = !oe_n && a1 && host_head < host_tail ? commands[host_head] : 8'bz;
    receiver_replay_top dut(
        .clk(clk), .rst_n(rst_n), .usb_dq(dq), .usb_flagb(flagb),
        .usb_flagc(flagc), .usb_pa1(1'b1), .usb_pclk(ifclk),
        .usb_wr(wr_n), .usb_rd(rd_n), .usb_pa7(cs_n), .usb_pa6(pktend_n),
        .usb_pa5(a1), .usb_pa4(a0), .usb_pa2(oe_n), .usb_pa0(pa0), .led(led)
    );
    initial begin
        clk = 0;
        forever #20.833333 clk = ~clk;
    end
    always @(posedge ifclk) begin
        if (!cs_n && !rd_n) begin
            if (!a1 || oe_n || host_head >= host_tail || !wr_n) begin
                $fatal(1, "Invalid FX2 OUT read/direction");
            end
            host_head = host_head + 1;
        end
        if (!cs_n && !wr_n) begin
            if (a1 || !oe_n || !rd_n || (^dq) === 1'bx) begin
                $fatal(1, "FX2 bus contention or invalid IN write");
            end
            packet[byte_count] = dq;
            byte_count = byte_count + 1;
            if (byte_count == 512) begin
                byte_count = 0;
                if ({packet[3], packet[2], packet[1], packet[0]} == 32'h31415052) begin
                    ack_count = ack_count + 1;
                end else if ({packet[3], packet[2], packet[1], packet[0]} == 32'h31524346 && capture) begin
                    iq_frames = iq_frames + 1;
                end
            end
            $fdisplay(output_file, "%02x", dq);
        end
    end
    always @(negedge dut.sample_clk) begin
        if (dut.source_active !== 1'b1) begin
            replay_index = 0;
        end else begin
            if (dut.source_adc !== pattern[replay_index]) begin
                $fatal(1, "Replay mismatch at %0d: %0d", replay_index, dut.source_adc);
            end
            replay_index = replay_index + 1;
            replay_samples = replay_samples + 1;
            if (replay_index == pattern_length) begin
                replay_index = 0;
            end
        end
    end
    always @(posedge dut.sample_clk) begin
        sample_cycles = sample_cycles + 1;
        if (dut.stream_sample_n && (dut.dsp_error || dut.fifo_full || dut.dropped != 0)) begin
            $fatal(1, "Unexpected DSP deadline/overflow");
        end
        if (dut.iq_valid && dut.stream_sample_n) begin
            if (iq_samples > 0 && sample_cycles - last_iq_cycle != 87) begin
                $fatal(1, "IQ output cadence is not 87 sample clocks");
            end
            last_iq_cycle = sample_cycles;
            iq_samples = iq_samples + 1;
            $fdisplay(iq_file, "%d %d %d", dut.index, dut.iq_i, dut.iq_q);
        end
    end
    initial begin
        rst_n = 0;
        host_head = 0;
        host_tail = 0;
        byte_count = 0;
        ack_count = 0;
        iq_frames = 0;
        iq_samples = 0;
        replay_samples = 0;
        replay_index = 0;
        sample_cycles = 0;
        last_iq_cycle = 0;
        capture = 1;
        if (!$value$plusargs("commands=%d", command_count)) begin
            $fatal(1, "Missing commands count");
        end
        if (!$value$plusargs("length=%d", pattern_length)) begin
            $fatal(1, "Missing waveform length");
        end
        $readmemh("commands.hex", commands);
        $readmemh("pattern.hex", pattern);
        output_file = $fopen("usb_bytes.txt", "w");
        iq_file = $fopen("iq_samples.txt", "w");
        #100;
        rst_n = 1;
        wait (dut.usb_rst_n);
        // Submit each command only after the previous ACK completed on the bus.
        for (n = 0; n < command_count - 1; n = n + 1) begin
            host_tail = host_tail + 512;
            wait (ack_count == n + 1);
        end
        wait (iq_frames >= 16);
        host_tail = host_tail + 512;
        wait (ack_count == command_count);
        #2000;
        if (dut.source_active || dut.frequency_locked || replay_samples < 131072) begin
            $fatal(1, "STOP or sustained replay failed");
        end
        $fclose(output_file);
        $fclose(iq_file);
        $display("USB_REPLAY_PASS ACK=%0d frames=%0d samples=%0d replay=%0d",
            ack_count, iq_frames, iq_samples, replay_samples);
        $finish;
    end
    initial begin
        #30000000;
        $fatal(1, "USB replay timeout");
    end
endmodule
