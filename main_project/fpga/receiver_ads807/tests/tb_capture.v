`timescale 1ns/1ps
module tb_capture;
    reg clk;
    reg rst_n;
    reg enable;
    reg [11:0] adc;
    wire signed [11:0] sample;
    wire valid;
    integer code;
    rx_capture dut(
        .clk(clk), .rst_n(rst_n), .enable(enable), .adc(adc),
        .sample(sample), .valid(valid)
    );
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end
    initial begin
        rst_n = 0;
        enable = 0;
        adc = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        for (code = 0; code < 4096; code = code + 1) begin
            adc = code;
            enable = 1;
            @(posedge clk);
            #1;
            if (sample != code-2048 || !valid) begin
                $fatal(1, "ADC offset binary conversion");
            end
            @(negedge clk);
        end
        enable = 0;
        @(posedge clk);
        #1;
        if (valid) begin
            $fatal(1, "ADC enable bubble");
        end
        $display("CAPTURE_PASS all_codes=4096");
        $finish;
    end
endmodule
