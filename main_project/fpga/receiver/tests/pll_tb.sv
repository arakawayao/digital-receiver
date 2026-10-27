`timescale 1ns/1ps
module pll_tb;
    reg ref_clk=0,reset=1;
    always #20.8335 ref_clk=~ref_clk;
    wire [4:0] c56;
    wire l56;
    rx_pll56 p56(.inclk({1'b0,ref_clk}),.areset(reset),.clk(c56),.locked(l56));
    wire stream_n;
    rx_reset r(.clk(c56[0]),.arst_n(!reset && l56),.rst_n(stream_n));
    realtime t;
    initial begin
        #200; reset=0; wait(l56); wait(stream_n);
        @(posedge c56[0]); t=$realtime; @(posedge c56[0]);
        if($realtime-t<17.75 || $realtime-t>17.95) $fatal(1,"56 MHz PLL period");
        @(posedge c56[1]); t=$realtime; @(posedge c56[1]);
        if($realtime-t<41.5 || $realtime-t>41.9) $fatal(1,"24 MHz USB period");
        reset=1; #1; if(stream_n) $fatal(1,"Reset assertion not asynchronous");
        #200; reset=0; wait(l56 && stream_n);
        $display("PLL_PASS"); $finish;
    end
    initial begin #100000; $fatal(1,"PLL timeout"); end
endmodule
