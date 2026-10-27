`timescale 1ns/1ps
module control_tb;
    reg clk=0;
    always #20.833333 clk=~clk;
    reg rst_n=0,pause=0,flagb=1,flagc=0;
    wire [7:0] dq;
    reg [7:0] fx2_data=0;
    wire ifclk,cs,rd,wr,oe,a0,a1,pkt,pa0,ready;
    wire [7:0] command;
    wire command_valid;
    rx_fx2 fx2(.clk(clk),.rst_n(rst_n),.pause(pause),.flagb(flagb),.flagc(flagc),
        .dq(dq),.ifclk(ifclk),.slcs_n(cs),.slrd_n(rd),.slwr_n(wr),.sloe_n(oe),
        .a0(a0),.a1(a1),.pktend_n(pkt),.pa0(pa0),.tx_data(8'h00),.tx_valid(1'b0),
        .tx_ready(ready),.command_data(command),.command_valid(command_valid));
    assign dq=!oe ? fx2_data : 8'bz;
    wire [31:0] step,rf,epoch;
    wire conjugate,toggle,bad;
    rx_config config_dut(.clk(clk),.rst_n(rst_n),.pause(pause),.data(command),
        .valid(command_valid),.phase_step(step),.rf_hz(rf),.epoch(epoch),
        .conjugate(conjugate),.config_toggle(toggle),.bad_command(bad));
    reg [7:0] command_bytes [0:63];
    integer pointer=0;
    // FX2 synchronous read model, external IFCLK tXFD <=15 ns.
    always @(posedge ifclk) if(!cs && !rd) begin
        if(!a1 || oe || pointer>=64) $fatal(1,"Invalid EP6 read");
        fx2_data<=#15 command_bytes[pointer]; pointer++;
        if(pointer==64) flagc<=#13.5 0;
    end
    reg [127:0] cmd;
    integer j;
    initial begin
        cmd={32'd1,32'd104000000,32'h66666666,32'h31464352};
        for(j=0;j<16;j++) command_bytes[j]=cmd>>(8*j);
        // Reject reserved bits and out-of-band RF without changing configuration.
        cmd={32'd2,32'd100000000,32'h10000000,32'h31464352};
        for(j=0;j<16;j++) command_bytes[16+j]=cmd>>(8*j);
        cmd={32'd0,32'd109000000,32'h10000000,32'h31464352};
        for(j=0;j<16;j++) command_bytes[32+j]=cmd>>(8*j);
        cmd={32'd0,32'd100000000,32'h7fffffff,32'h31464352};
        for(j=0;j<16;j++) command_bytes[48+j]=cmd>>(8*j);
        repeat(5) @(negedge clk); rst_n=1;
        repeat(10) @(negedge clk); pause=1; flagc=1;
        wait(pointer==64); repeat(10) @(negedge clk);
        if(step!=32'h66666666 || rf!=104000000 || epoch!=1 || !conjugate || !bad)
            $fatal(1,"Config parse/rejection failed");
        pause=0; repeat(10) @(negedge clk);
        if(!oe || a1 || !rd || epoch!=2) $fatal(1,"Read/write direction or epoch recovery failed");
        $display("CONTROL_PASS"); $finish;
    end
    initial begin #200000; $fatal(1,"Control timeout"); end
endmodule
