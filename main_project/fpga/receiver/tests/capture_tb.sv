`timescale 1ns/1ps
module capture_tb;
    reg clk=0; always #12.5 clk=~clk;
    reg rst_n=0,enable=0;
    reg [11:0] adc=0;
    wire signed [11:0] offset_sample,twos_sample;
    wire ov,tv;
    rx_capture a(.clk(clk),.rst_n(rst_n),.enable(enable),.adc(adc),.sample(offset_sample),.valid(ov));
    rx_capture #(.OFFSET_BINARY(0)) b(.clk(clk),.rst_n(rst_n),.enable(enable),.adc(adc),.sample(twos_sample),.valid(tv));
    integer eo=0,et=0,k;
    task automatic step(input bit reset_released,input bit en,input integer value);
        reg signed [11:0] old_o,old_t;
        reg old_valid;
        begin
            @(negedge clk);
            old_o=offset_sample;old_t=twos_sample;old_valid=ov;
            rst_n=reset_released;enable=en;adc=value;
            #1;
            if(offset_sample!==old_o || twos_sample!==old_t || ov!==old_valid || tv!==old_valid)
                $fatal(1,"Capture changed before edge");
            if(!reset_released) begin eo=0;et=0; end
            else if(en) begin eo=value-2048;et=value>=2048 ? value-4096 : value;end
            @(posedge clk); #1;
            if(offset_sample!==eo[11:0] || twos_sample!==et[11:0] ||
               ov!==(reset_released && en) || tv!==ov) $fatal(1,"Capture format/valid");
        end
    endtask
    initial begin
        step(0,1,4095);
        for(k=0;k<4096;k++) step(1,1,k);
        for(k=0;k<100;k++) step(1,k%2,(k*117)%4096);
        step(0,1,0);step(1,0,4095);step(1,1,2048);
        $display("CAPTURE_PASS all_codes=4096 formats=2");$finish;
    end
    initial begin #200000;$fatal(1,"Capture timeout");end
endmodule
