// EP6 command: "RCF1", phase_step u32, RF Hz u32, flags u32 (bit0 conjugate).
// Send only while PA1 pause is high; bundled values stay stable across toggle transfer.
// RF is tuning metadata, not a measured center frequency. Clock rate is per build.
module rx_config #(parameter ADC_RATE=40000000)(
    input wire clk, input wire rst_n, input wire pause,
    input wire [7:0] data, input wire valid,
    output reg [31:0] phase_step, rf_hz, epoch,
    output reg conjugate, config_toggle, output reg bad_command);
    reg [127:0] bytes;
    reg [3:0] count;
    reg apply;
    reg previous_pause;
    reg [127:0] complete;
    wire [31:0] requested_rf=complete[95:64];
    wire [31:0] requested_step=complete[63:32];
    localparam MIN_STEP=ADC_RATE==32000000 ? 32'd20132659 : 32'd16106128;
    wire direction_ok=complete[96] == (ADC_RATE==32000000 ? requested_rf<96000000 : requested_rf>100000000);
    wire band_ok=ADC_RATE==32000000 ?
        (requested_rf<=95850000 || requested_rf>=96150000) :
        (requested_rf<=99850000 || requested_rf>=100150000);
    always @(posedge clk) begin
        if(!rst_n) begin
            // Mathematical tuning example: 98 MHz -> +2 MHz at 32 MHz,
            // 98 MHz -> +18 MHz at 40 MHz, neither spectrally inverted.
            phase_step<=ADC_RATE==32000000 ? 32'h10000000 : 32'h73333333;
            rf_hz<=98000000; conjugate<=0;
            epoch<=0; config_toggle<=0; bad_command<=0;
            count<=0; bytes<=0; complete<=0; apply<=0; previous_pause<=0;
        end else begin
            apply<=0;
            previous_pause<=pause;
            if(previous_pause && !pause) epoch<=epoch+1'b1;
            if(!pause) count<=0;
            else if(valid) begin
                bytes[8*count +: 8]<=data;
                count<=count+1'b1;
                if(count==15) begin complete<={data,bytes[119:0]}; apply<=1; end
            end
            if(apply) begin
                if(complete[31:0]==32'h31464352 && complete[127:97]==0 &&
                    requested_rf>=88000000 && requested_rf<=108000000 &&
                    requested_step>=MIN_STEP && requested_step<=32'h80000000-MIN_STEP &&
                    band_ok && direction_ok) begin
                    phase_step<=complete[63:32]; rf_hz<=complete[95:64];
                    conjugate<=complete[96]; epoch<=epoch+1'b1;
                    config_toggle<=~config_toggle;
                end else bad_command<=1;
            end
        end
    end
endmodule
