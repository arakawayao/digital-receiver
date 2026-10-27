`timescale 1ns/1ps
module top_tb;
    parameter ADC_RATE=40000000;
    reg clk=0; always #20.8335 clk=~clk;
    reg rst_n=0;
    reg [11:0] adc=2048;
    wire adc_clk;
    tri [7:0] dq;
    wire pclk,wr,rd,pa7,pa6,pa5,pa4,pa2,pa0,led;
    reg flagb=1;
    receiver_top #(.ADC_RATE(ADC_RATE)) dut(.clk(clk),.rst_n(rst_n),.adc_data(adc),
        .adc_clk(adc_clk),.usb_dq(dq),.usb_flagb(flagb),.usb_flagc(1'b0),.usb_pa1(1'b0),
        .usb_pclk(pclk),.usb_wr(wr),.usb_rd(rd),.usb_pa7(pa7),.usb_pa6(pa6),
        .usb_pa5(pa5),.usb_pa4(pa4),.usb_pa2(pa2),.usb_pa0(pa0),.led(led));
    integer n=0,usb_cycles=0,received=0,fi,fo,credit=8;
    real v;
    always @(negedge adc_clk) begin
        v=800*$cos(6.283185307179586*98000000.0*n/ADC_RATE);
        adc=2048+$rtoi(v>=0 ? v+0.5 : v-0.5); n++;
    end
    always @(posedge adc_clk)
        $fdisplay(fi,"%d 1 %d %h %d",dut.stream_sample_n,adc,dut.sample_phase,dut.sample_conjugate);
    always @(posedge pclk) begin
        usb_cycles++;
        if(!pa7 && !wr) begin
            if(pa5 || pa4 || !rd || !pa2 || !flagb || credit==0) $fatal(1,"Top USB write");
            credit--;
            $fdisplay(fo,"%02x",dq); received++;
        end
        if(usb_cycles%101>10 && credit<8) credit++;
        flagb<=#13.5 credit!=0;
    end
    initial begin
        fi=$fopen("top_inputs.txt","w"); fo=$fopen("top_bytes.txt","w");
        #500; rst_n=1;
        wait(received==1536); #100;
        $fclose(fi); $fclose(fo);
        if(!led) $fatal(1,"Top status error");
        $display("TOP_PASS rate=%0d",ADC_RATE); $finish;
    end
    initial begin #3000000; $fatal(1,"Top timeout"); end
endmodule
