// Qualified real-input crossing estimator. RF = 87 MHz + positive alias.
// ADC input is registered by the top level before entering this block.
module rx_frequency #(
    parameter QUALIFY_BINS = 32,
    parameter REACQUIRE_BINS = 32,
    parameter GAP_SPREAD = 3,
    parameter MIN_ABS_MEAN = 32,
    parameter HYSTERESIS = 16
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
    localparam MIN_BINS = (64'd65536 * 1000000) / 43500000;
    localparam MAX_BINS = (64'd65536 * 21000000) / 43500000;
    reg signed [23:0] dc_acc;
    reg armed;
    reg [15:0] cycle_count;
    reg [15:0] crossings;
    reg [28:0] abs_sum;
    reg [8:0] clip_count;
    reg have_crossing;
    reg [7:0] gap_count;
    reg [7:0] min_gap;
    reg [7:0] max_gap;
    reg candidate_valid;
    reg [15:0] candidate_bins;
    reg [15:0] locked_bins;
    reg [2:0] acquire_state;
    reg [16:0] acquired_pair;
    reg [42:0] hz_product;
    reg [31:0] alias_hz;
    reg [31:0] new_rf;
    wire signed [11:0] sample;
    wire signed [12:0] centered;
    wire [12:0] magnitude;
    wire crossing;
    wire [7:0] gap;
    wire [15:0] next_crossings;
    wire [28:0] next_abs_sum;
    wire [8:0] next_clip_count;
    wire [7:0] next_min_gap;
    wire [7:0] next_max_gap;
    wire good_window;
    wire [15:0] candidate_delta;
    wire [15:0] locked_delta;
    wire [16:0] pair_sum;
    assign sample = {~adc[11], adc[10:0]};
    assign centered = sample - (dc_acc >>> 10);
    assign magnitude = centered[12] ? -centered : centered;
    assign crossing = armed && centered >= HYSTERESIS;
    assign gap = gap_count == 255 ? 8'd255 : gap_count + 1'b1;
    assign next_crossings = crossings + crossing;
    assign next_abs_sum = abs_sum + magnitude;
    assign next_clip_count = clip_count == 511 ? 9'd511 :
        clip_count + (adc == 0 || adc == 4095);
    assign next_min_gap = crossing && have_crossing && gap < min_gap ? gap : min_gap;
    assign next_max_gap = crossing && have_crossing && gap > max_gap ? gap : max_gap;
    assign good_window = next_crossings >= MIN_BINS-4 &&
        next_crossings <= MAX_BINS+4 && next_abs_sum >= MIN_ABS_MEAN*65536 &&
        next_clip_count <= 256 && next_min_gap >= 2 && next_max_gap <= 46 &&
        next_max_gap-next_min_gap <= GAP_SPREAD;
    assign candidate_delta = next_crossings >= candidate_bins ?
        next_crossings-candidate_bins : candidate_bins-next_crossings;
    assign locked_delta = next_crossings >= locked_bins ?
        next_crossings-locked_bins : locked_bins-next_crossings;
    assign pair_sum = {1'b0, candidate_bins} + {1'b0, next_crossings};
    always @(posedge clk) begin
        if (!rst_n) begin
            dc_acc <= 0;
            armed <= 0;
            cycle_count <= 0;
            crossings <= 0;
            abs_sum <= 0;
            clip_count <= 0;
            have_crossing <= 0;
            gap_count <= 0;
            min_gap <= 255;
            max_gap <= 0;
            candidate_valid <= 0;
            candidate_bins <= 0;
            locked_bins <= 0;
            phase_step <= 0;
            rf_hz <= 0;
            locked <= 0;
            update <= 0;
            valid_window <= 0;
            measured_bins <= 0;
            acquire_state <= 0;
            acquired_pair <= 0;
            hz_product <= 0;
            alias_hz <= 0;
            new_rf <= 0;
        end else begin
            dc_acc <= dc_acc + sample - (dc_acc >>> 10);
            update <= 0;
            valid_window <= 0;
            if (centered <= -HYSTERESIS) begin
                armed <= 1;
            end else if (centered >= HYSTERESIS) begin
                armed <= 0;
            end
            if (crossing) begin
                gap_count <= 0;
                have_crossing <= 1;
            end else if (gap_count != 255) begin
                gap_count <= gap_count + 1'b1;
            end
            // Keep each conversion stage behind a register; metadata commits together.
            case (acquire_state)
                1: begin
                    hz_product <= acquired_pair * 26'd43500000;
                    acquire_state <= 2;
                end
                2: begin
                    alias_hz <= (hz_product + 43'd65536) >> 17;
                    acquire_state <= 3;
                end
                3: begin
                    new_rf <= 32'd87000000 + alias_hz;
                    acquire_state <= 4;
                end
                4: begin
                    phase_step <= {acquired_pair, 15'b0};
                    rf_hz <= new_rf < 88000000 ? 32'd88000000 :
                        new_rf > 108000000 ? 32'd108000000 : new_rf;
                    locked_bins <= (acquired_pair + 1'b1) >> 1;
                    locked <= 1;
                    update <= 1;
                    acquire_state <= 0;
                end
                default: begin
                    acquire_state <= 0;
                end
            endcase
            if (cycle_count == 16'hffff) begin
                cycle_count <= 0;
                crossings <= 0;
                abs_sum <= 0;
                clip_count <= 0;
                min_gap <= 255;
                max_gap <= 0;
                measured_bins <= next_crossings;
                valid_window <= good_window;
                if (!good_window) begin
                    locked <= 0;
                    candidate_valid <= 0;
                end else if (locked) begin
                    if (locked_delta > REACQUIRE_BINS) begin
                        locked <= 0;
                        candidate_valid <= 1;
                        candidate_bins <= next_crossings;
                    end
                end else if (candidate_valid && candidate_delta <= QUALIFY_BINS &&
                             acquire_state == 0) begin
                    acquired_pair <= pair_sum;
                    acquire_state <= 1;
                    candidate_valid <= 0;
                end else begin
                    candidate_valid <= 1;
                    candidate_bins <= next_crossings;
                end
            end else begin
                cycle_count <= cycle_count + 1'b1;
                crossings <= next_crossings;
                abs_sum <= next_abs_sum;
                clip_count <= next_clip_count;
                min_gap <= next_min_gap;
                max_gap <= next_max_gap;
            end
        end
    end
endmodule
