`timescale 1ns/1ps
module dsp_tb;
    parameter ADC_RATE=56000000;
    reg clk=0;
    always #(500000000.0/ADC_RATE) clk=~clk;
    reg rst_n=0, enable=0, conjugate=0;
    reg [11:0] adc=0;
    reg [31:0] step=0;
    wire signed [15:0] i_out,q_out;
    wire valid,clip,error;
    rx_dsp #(.ADC_RATE(ADC_RATE)) dut(.clk(clk),.rst_n(rst_n),.enable(enable),
        .adc(adc),.phase_step(step),.conjugate(conjugate),.i_out(i_out),.q_out(q_out),
        .valid(valid),.clipped(clip),.deadline_error(error));
    integer fi,fo,fields,cycle=0;
    initial begin
        fi=$fopen("dsp_inputs.txt","r"); fo=$fopen("dsp_outputs.txt","w");
        if(!fi || !fo) $fatal(1,"Cannot open vectors");
        while(!$feof(fi)) begin
            @(negedge clk);
            fields=$fscanf(fi,"%d %d %d %h %d\n",rst_n,enable,adc,step,conjugate);
            if(fields!=5) $fatal(1,"Input row %0d",cycle);
            @(posedge clk); #1;
            $fdisplay(fo,"%d %d %d %d %d",valid,i_out,q_out,clip,error);
            cycle++;
        end
        $fclose(fi); $fclose(fo);
        $display("DSP_PASS rate=%0d cycles=%0d",ADC_RATE,cycle); $finish;
    end
    initial begin #50000000; $fatal(1,"DSP timeout"); end
endmodule
