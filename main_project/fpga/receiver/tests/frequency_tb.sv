`timescale 1ns/1ps
module frequency_tb;
    reg clk=0; always #8.928571 clk=~clk;
    reg rst_n=0; reg [11:0] adc=2048;
    wire [31:0] phase_step,rf_hz;
    wire locked,update,valid_window;
    wire [15:0] measured_bins;
    rx_frequency dut(.*);
    integer infile,outfile,status,r,n,scenario,count=0;
    reg [31:0] previous_phase=0,previous_rf=0;
    reg [63:0] expected_alias,expected_rf;
    always @(posedge clk) begin
        #0.002;
        if(rst_n) begin
            if((phase_step!=previous_phase || rf_hz!=previous_rf) && !update)
                $fatal(1,"Frequency metadata changed without update");
            if(update) begin
                if(!locked) $fatal(1,"Frequency update without lock");
                expected_alias=phase_step;
                expected_alias=(expected_alias*56000000+64'd2147483648)>>32;
                expected_rf=112000000-expected_alias;
                if(expected_rf<88000000) expected_rf=88000000;
                if(expected_rf>108000000) expected_rf=108000000;
                if(rf_hz!=expected_rf)
                    $fatal(1,"Frequency phase/metadata pipeline misalignment");
            end
        end
        previous_phase=phase_step; previous_rf=rf_hz;
    end
    initial begin
        infile=$fopen("inputs.txt","r"); outfile=$fopen("outputs.txt","w");
        if(!infile || !outfile) $fatal(1,"Frequency file open");
        while(!$feof(infile)) begin
            status=$fscanf(infile,"%d %d %d\n",r,n,scenario);
            if(status==3) begin
                @(negedge clk); rst_n=r; adc=n;
                @(posedge clk); #0.001;
                if(update || dut.cycle_count==0)
                    $fdisplay(outfile,"%d %d %d %d %d %d %d %d %d %d",
                        count,scenario,locked,update,valid_window,measured_bins,
                        phase_step,rf_hz,dut.min_gap,dut.max_gap);
                count=count+1;
            end
        end
        $fclose(infile); $fclose(outfile);
        $display("FREQUENCY_PASS cycles=%0d",count); $finish;
    end
endmodule
