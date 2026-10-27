`timescale 1ns/1ps

module ddc_mixer_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg den = 1'b0;
    reg signed [11:0] din = 12'sd0;
    reg [31:0] phase_inc = 32'd0;
    wire signed [23:0] dout_i;
    wire signed [23:0] dout_q;
    wire dvalid;
    integer inputs, outputs, fields, cycles;

    ddc_mixer dut (
        .clk(clk), .rst_n(rst_n), .den(den), .din(din),
        .phase_inc(phase_inc), .dout_i(dout_i), .dout_q(dout_q),
        .dvalid(dvalid)
    );

    always #50 clk = ~clk; // 10 MHz capture/DDC domain.

    initial begin
        inputs = $fopen("inputs.txt", "r");
        outputs = $fopen("outputs.txt", "w");
        if (!inputs || !outputs) $fatal(1, "Cannot open simulation vectors");
        cycles = 0;
        while (!$feof(inputs)) begin
            @(negedge clk);
            fields = $fscanf(inputs, "%d %d %d %h\n", rst_n, den, din, phase_inc);
            if (fields != 4) $fatal(1, "Malformed input row %0d", cycles);
            @(posedge clk);
            #1;
            $fdisplay(outputs, "%b %0d %0d", dvalid, dout_i, dout_q);
            cycles = cycles + 1;
        end
        $fclose(inputs);
        $fclose(outputs);
        $display("DDC_MIXER_PASS cycles=%0d", cycles);
        $finish;
    end

    initial begin
        #10000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
