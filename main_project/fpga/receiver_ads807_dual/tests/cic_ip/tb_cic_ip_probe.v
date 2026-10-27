`timescale 1ns/1ps
module tb_cic_ip_probe;
    parameter OUT_WIDTH = 57;
    reg clk;
    reg rst_n;
    reg valid;
    reg signed [23:0] din;
    wire signed [56:0] dout;
    wire out_valid;
    wire ready;
    integer n;
    integer infile;
    integer outfile;
    integer fields;
    integer reset_value;
    integer valid_value;
    integer sample_value;
    cic_ip_probe #(.OUT_WIDTH(OUT_WIDTH)) dut(
        .clk(clk), .rst_n(rst_n), .valid(valid), .din(din),
        .dout(dout), .out_valid(out_valid), .ready(ready)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
        rst_n = 0;
        valid = 0;
        din = 0;
        n = 0;
        infile = $fopen("inputs.txt", "r");
        outfile = $fopen("probe.txt", "w");
        if (!infile || !outfile) begin
            $fatal(1, "CIC vector file open");
        end
        while (!$feof(infile)) begin
            @(negedge clk);
            fields = $fscanf(infile, "%d %d %d\n", reset_value, valid_value, sample_value);
            if (fields != 3) begin
                $fatal(1, "CIC vector row");
            end
            rst_n = reset_value;
            valid = valid_value;
            din = sample_value;
            @(posedge clk);
            #1;
            $fdisplay(outfile, "%0d %0d %0d %0d", n, ready, out_valid, dout);
            n = n + 1;
        end
        $fclose(outfile);
        $display("CIC_PROBE_PASS cycles=%0d", n);
        $finish;
    end
endmodule
