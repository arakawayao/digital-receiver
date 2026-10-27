`timescale 1ns/1ps
// module fir_tb;
//     reg clk=0; always #12.5 clk=~clk;
//     reg rst_n=0,valid=0;
//     reg signed [17:0] di=0,dq=0;
//     wire signed [15:0] oi,oq;
//     wire ov,clip,error;
//     rx_fir dut(.clk(clk),.rst_n(rst_n),.valid(valid),.din_i(di),.din_q(dq),
//         .input_clip(1'b0),.dout_i(oi),.dout_q(oq),.out_valid(ov),
//         .clipped(clip),.deadline_error(error));
//     integer k,n;
//     reg expect_saturation=0;
//     always @(posedge clk) begin
//         #1;
//         if(error) $fatal(1,"FIR deadline failure at 64-cycle spacing");
//         if(ov && expect_saturation && (!clip || oi!=32767 || oq!= -32768))
//             $fatal(1,"FIR saturation wrong %0d %0d %b",oi,oq,clip);
//     end
//     initial begin
//         repeat(4) @(negedge clk); rst_n=1;
//         for(n=0;n<70;n++) begin
//             valid=1; di=131071; dq= -131072;
//             @(negedge clk); valid=0;
//             repeat(63) @(negedge clk);
//             if(n==65) expect_saturation=1;
//         end
//         expect_saturation=0; rst_n=0;
//         repeat(4) @(negedge clk); rst_n=1;
//         valid=1; di=0; dq=0;
//         @(negedge clk); valid=0;
//         wait(ov); #1;
//         if(oi!=0 || oq!=0 || clip) $fatal(1,"Stale FIR history after reset");
//         $display("FIR_PASS"); $finish;
//     end
//     initial begin #200000; $fatal(1,"FIR timeout"); end
// endmodule
module fir_tb;
