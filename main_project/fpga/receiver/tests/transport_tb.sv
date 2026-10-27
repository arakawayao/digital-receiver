`timescale 1ns/1ps
module transport_tb;
    reg wrclk=0, clk=0;
    always #8.928571 wrclk=~wrclk;
    always #20.833333 clk=~clk;
    reg rst_n=0, aclr=1, wrreq=0, pause=0;
    reg [96:0] data=0;
    wire [96:0] q;
    wire full,empty,rdreq;
    rx_fifo fifo(.aclr(aclr),.data(data),.wrclk(wrclk),.wrreq(wrreq),.wrfull(full),
        .rdclk(clk),.rdreq(rdreq),.rdempty(empty),.q(q));
    wire [7:0] bytes;
    wire valid,ready;
    rx_packet packet(.clk(clk),.rst_n(rst_n),.fifo_q(q),.fifo_empty(empty),.fifo_read(rdreq),
        .rf_hz(32'd98000000),.phase_step(32'h40000000),.epoch(32'd7),.conjugate(1'b1),
        .byte_data(bytes),.byte_valid(valid),.byte_ready(ready));
    wire [7:0] dq;
    wire ifclk,cs,rd,wr,oe,a0,a1,pkt,pa0;
    reg flagb=0;
    rx_fx2 fx2(.clk(clk),.rst_n(rst_n),.pause(pause),.flagb(flagb),
        .dq(dq),.ifclk(ifclk),.slcs_n(cs),.slrd_n(rd),.slwr_n(wr),.sloe_n(oe),
        .a0(a0),.a1(a1),.pktend_n(pkt),.pa0(pa0),.tx_data(bytes),.tx_valid(valid),
        .tx_ready(ready));
    integer cycle=0, received=0, file_out, credit=0;
    reg [7:0] saved_data;
    reg stalled=0;
    always @(posedge clk) begin
        if(rst_n && stalled && (!valid || bytes!==saved_data))
            $fatal(1,"TX changed under backpressure");
        stalled=rst_n && valid && !ready; saved_data=bytes;
    end
    always @(posedge ifclk) begin
        cycle++;
        if(!cs && !wr) begin
            if(a1 || !rd || !oe || !flagb || credit==0) $fatal(1,"Invalid FX2 write");
            credit--;
            $fdisplay(file_out,"%02x",dq); received++;
        end
        // FULL can only assert as a result of a write; host reads free space.
        if(cycle>3500 && cycle%37>8 && credit<16) credit++;
        flagb<=#13.5 credit!=0;
    end
    task automatic push(input integer index);
        @(negedge wrclk);
        data={1'b0,32'd5,32'(index),16'(index^16'h5678),16'(index^16'h1234)};
        wrreq=1;
        if(full) $fatal(1,"Unexpected FIFO full before 512 entries");
        @(negedge wrclk); wrreq=0;
    endtask
    integer j;
    initial begin
        file_out=$fopen("transport_bytes.txt","w");
        repeat(5) @(negedge clk); aclr=0;
        repeat(20) @(negedge clk); rst_n=1;
        for(j=0;j<40;j++) push(j);
        // A real gap forces partial frame count=40 with zero padding.
        for(j=45;j<45+224;j++) push(j);
        wait(received==1536); repeat(10) @(posedge clk);
        $fclose(file_out);
        // Fill the IP to FULL, then exercise asynchronous reset with data pending.
        rst_n=0; aclr=1; repeat(6) @(negedge clk); aclr=0;
        repeat(20) @(negedge clk);
        for(j=0;j<512;j++) push(j);
        repeat(10) @(negedge wrclk);
        if(!full) $fatal(1,"FIFO FULL missing");
        aclr=1; repeat(6) @(negedge clk); aclr=0;
        repeat(20) @(negedge clk);
        if(!empty || full) $fatal(1,"FIFO reset did not clear flags");
        $display("TRANSPORT_PASS bytes=%0d",received); $finish;
    end
    initial begin #2000000; $fatal(1,"Transport timeout"); end
endmodule
