`timescale 1ns/1ps
module tb_pll;
    reg clk;
    reg reset;
    wire [4:0] clocks;
    wire locked;
    real previous;
    real period;
    rx_pll_ads807 dut(
        .inclk({1'b0, clk}), .areset(reset), .clk(clocks), .locked(locked)
    );
    initial begin
        clk = 0;
        forever #20.833333 clk = ~clk;
    end
    initial begin
        reset = 1;
        #100;
        reset = 0;
        wait (locked);
        repeat (10) @(posedge clocks[0]);
        previous = $realtime;
        @(posedge clocks[0]);
        period = $realtime-previous;
        if (period < 22.95 || period > 23.03) begin
            $fatal(1, "ADS807 PLL is not 43.5 MHz");
        end
        @(posedge clocks[1]);
        previous = $realtime;
        @(posedge clocks[1]);
        period = $realtime-previous;
        if (period < 41.6 || period > 41.8) begin
            $fatal(1, "USB PLL is not 24 MHz");
        end
        $display("PLL_PASS");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "PLL timeout");
    end
endmodule
