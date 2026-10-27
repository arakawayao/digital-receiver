// Autonomous single-carrier estimator for a fixed 56 MHz real ADC.
// RF 88..108 MHz aliases to -24..-4 MHz: RF = 112 MHz - |alias|.
// Offset-binary ADC12; DC IIR Q10, Schmitt crossings +/-16 ADC codes.
// Window = 65536 clocks (1.170286 ms). Counts resolve 854.4921875 Hz.
// No AM/FM classifier: this block only qualifies and estimates one carrier.
module rx_frequency #(
    parameter QUALIFY_BINS=32,       // 27.344 kHz candidate-to-candidate margin
    parameter REACQUIRE_BINS=32,     // 27.344 kHz locked-to-current margin
    parameter GAP_SPREAD=3,         // allowed sampled crossing-period spread
    parameter MIN_ABS_MEAN=32,
    parameter HYSTERESIS=16
)(
    input wire clk, 
	 input wire rst_n, 
	 input wire [11:0] adc,
    output reg [31:0] phase_step, 
	 output reg [31:0] rf_hz,
    output reg locked, 
	 output reg update,
    output reg valid_window, 
	 output reg [15:0] measured_bins
);
	/*wire / reg define*/
	//convert unsigned number to signed
    wire signed [11:0] sample;
	 assign	sample = {~adc[11], adc[10:0]};
	 //use estimated dc to get the center voltage
    reg signed [23:0] dc_acc;
    wire signed [12:0] centered;
	 assign	centered = sample - (dc_acc >>> 10);
	 
    wire [12:0] magnitude=centered[12] ? -centered : centered;
	 
    reg armed;
    wire crossing;
	 assign	crossing = armed && (centered >= HYSTERESIS);
	 
    reg [15:0] cycle_count, crossings;
    reg [28:0] abs_sum;
    reg [8:0] clip_count;
    reg have_crossing;
    reg [7:0] gap_count, min_gap, max_gap;
    wire [7:0] gap=gap_count==255 ? 8'd255 : gap_count+1'b1;
    wire [15:0] next_crossings=crossings+crossing;
    wire [28:0] next_abs_sum=abs_sum+magnitude;
    // Saturate above the acceptance threshold; a fully clipped 65536-sample
    // window must not wrap its count to zero and become accepted.
    wire [8:0] next_clip_count=clip_count==511 ? 9'd511 :
        clip_count+(adc==0 || adc==4095);
    wire [7:0] next_min_gap=(crossing && have_crossing && gap<min_gap) ? gap : min_gap;
    wire [7:0] next_max_gap=(crossing && have_crossing && gap>max_gap) ? gap : max_gap;
    // +/- four count tolerance at range endpoints accounts for finite window
    // count quantization and the mean instantaneous frequency of FM.
    wire good_window=next_crossings>=4677 && next_crossings<=28091 &&
        next_abs_sum>=(MIN_ABS_MEAN*65536) && next_clip_count<=256 &&
        next_min_gap>=2 && next_max_gap<=17 &&
        (next_max_gap-next_min_gap)<=GAP_SPREAD;
    reg candidate_valid;
    reg [15:0] candidate_bins, locked_bins;
    wire [15:0] candidate_delta=next_crossings>=candidate_bins ?
        next_crossings-candidate_bins : candidate_bins-next_crossings;
    wire [15:0] locked_delta=next_crossings>=locked_bins ?
        next_crossings-locked_bins : locked_bins-next_crossings;
    // Average two consecutive windows: the half-bin gives 427.246 Hz LO
    // resolution. Constant multiplication synthesizes to shift/add logic.
    wire [16:0] pair_sum={1'b0,candidate_bins}+{1'b0,next_crossings};
    // Conversion is a four-clock pipeline after qualification. Keeping each
    // arithmetic operation behind registers avoids chaining ADC DC correction,
    // crossing count, multiplication, RF subtraction, and clamp at 56 MHz.
    // locked/update stay low until phase and metadata can commit together.
    reg [2:0] acquire_state;
    reg [16:0] acquired_pair;
    reg [42:0] hz_product;
    reg [31:0] alias_hz, new_rf;
    always @(posedge clk) begin
        if(!rst_n) begin
            dc_acc<=0; armed<=0; cycle_count<=0; crossings<=0;
            abs_sum<=0; clip_count<=0; have_crossing<=0;
            gap_count<=0; min_gap<=255; max_gap<=0;
            candidate_valid<=0; candidate_bins<=0; locked_bins<=0;
            phase_step<=0; rf_hz<=0; locked<=0; update<=0;
            valid_window<=0; measured_bins<=0;
            acquire_state<=0; acquired_pair<=0; hz_product<=0;
            alias_hz<=0; new_rf<=0;
        end else begin
            dc_acc<=dc_acc+sample-(dc_acc>>>10);
            update<=0; valid_window<=0;
            if(centered<=-HYSTERESIS) armed<=1;
            else if(centered>=HYSTERESIS) armed<=0;
            if(crossing) begin
                gap_count<=0; have_crossing<=1;
            end else if(gap_count!=255) gap_count<=gap_count+1'b1;
            case(acquire_state)
                1: begin
                    hz_product<=acquired_pair*26'd56000000;
                    acquire_state<=2;
                end
                2: begin
                    alias_hz<=(hz_product+43'd65536)>>17;
                    acquire_state<=3;
                end
                3: begin
                    new_rf<=32'd112000000-alias_hz;
                    acquire_state<=4;
                end
                4: begin
                    phase_step<={acquired_pair,15'b0};
                    // Finite-window estimates at exact RF endpoints are clamped
                    // only in metadata; phase retains its measured value.
                    rf_hz<=new_rf<88000000 ? 32'd88000000 :
                        new_rf>108000000 ? 32'd108000000 : new_rf;
                    locked_bins<=(acquired_pair+1'b1)>>1;
                    locked<=1; update<=1; acquire_state<=0;
                end
                default: acquire_state<=0;
            endcase
            if(cycle_count==16'hffff) begin
                cycle_count<=0; crossings<=0; abs_sum<=0; clip_count<=0;
                // Keep crossing history across windows: otherwise one long
                // dropout exactly at a boundary could evade the interval test.
                min_gap<=255; max_gap<=0;
                measured_bins<=next_crossings;
                valid_window<=good_window;
                if(!good_window) begin locked<=0; candidate_valid<=0; end
                else if(locked) begin
                    if(locked_delta>REACQUIRE_BINS) begin
                        locked<=0; candidate_valid<=1; candidate_bins<=next_crossings;
                    end
                end else if(candidate_valid && candidate_delta<=QUALIFY_BINS && acquire_state==0) begin
                    acquired_pair<=pair_sum; //acquire_state<=1;
                    candidate_valid<=0;
                end else begin candidate_valid<=1; candidate_bins<=next_crossings; end
            end else begin
                cycle_count<=cycle_count+1'b1;
                crossings<=next_crossings; abs_sum<=next_abs_sum;
                clip_count<=next_clip_count;
                min_gap<=next_min_gap; max_gap<=next_max_gap;
            end
        end
    end
endmodule
