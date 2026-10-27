`timescale 1ns/1ps
module tb_dsp;
    parameter ADC_RATE = 43500000;
    reg clk;
    reg rst_n;
    reg enable;
    reg [11:0] adc;
    reg [31:0] step;
    reg conjugate;
    wire signed [15:0] oi;
    wire signed [15:0] oq;
    wire valid;
    wire clipped;
    wire error;
    integer infile;
    integer outfile;
    integer fields;
    integer cycle;
    integer raw;
    integer reset_value;
    integer enable_value;
    integer direction;
    rx_dsp #(.ADC_RATE(ADC_RATE)) dut(
        .clk(clk), .rst_n(rst_n), .enable(enable), .adc(adc),
        .phase_step(step), .conjugate(conjugate), .i_out(oi), .q_out(oq),
        .valid(valid), .clipped(clipped), .deadline_error(error)
    );
    initial begin
        clk = 0;
        forever #(500000000.0/ADC_RATE) clk = ~clk;
    end
    initial begin
        rst_n = 0;
        enable = 0;
        adc = 2048;
        step = 0;
        conjugate = 0;
        cycle = 0;
        infile = $fopen("dsp_inputs.txt", "r");
        outfile = $fopen("dsp_outputs.txt", "w");
        if (!infile || !outfile) begin
            $fatal(1, "DSP vector file open");
        end
        while (!$feof(infile)) begin
            @(negedge clk);
            fields = $fscanf(infile, "%d %d %d %h %d\n", reset_value,
                enable_value, raw, step, direction);
            if (fields != 5) begin
                $fatal(1, "DSP vector row");
            end
            rst_n = reset_value;
            enable = enable_value;
            adc = raw;
            conjugate = direction;
            @(posedge clk);
            #1;
            $fdisplay(outfile, "%d %d %d %d %d", valid, oi, oq, clipped, error);
            cycle = cycle + 1;
        end
        $fclose(outfile);
        $display("DSP_PASS cycles=%0d", cycle);
        $finish;
    end
    initial begin
        #30000000;
        $fatal(1, "DSP timeout");
    end
endmodule
