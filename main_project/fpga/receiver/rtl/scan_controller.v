// Independent sweep controller. FCW configurations and threshold latch at start.
// Equal powers keep the lower frequency. Invalid config gives done + error.
module scan_controller #(
    parameter integer SETTLE_SAMPLES = 8,
    parameter integer MEASURE_LOG2 = 10
)(
    input wire clk, rst_n, scan_start,
    input wire [31:0] start_fcw, stop_fcw, step_fcw,
    input wire [32:0] power_threshold,
    input wire signed [15:0] iq_i, iq_q,
    input wire iq_valid,
    output wire ddc_clear,
    output reg [31:0] current_fcw,
    output reg scan_busy, scan_done, config_error, signal_found,
    output reg point_valid,
    output reg [31:0] point_fcw,
    output reg [32:0] point_power,
    output reg [31:0] best_fcw,
    output reg [32:0] best_power
);
    localparam [3:0] IDLE=0, CLEAR=1, SETTLE=2, MEASURE=3,
                     REPORT=4, STEP=5, FINISH=6, LOCK_CLEAR=7, LOCK_WAIT=8;
    localparam [31:0] MEASURE_N = 32'd1 << MEASURE_LOG2;
    localparam integer WAIT_N = (SETTLE_SAMPLES < 4) ? 4 : SETTLE_SAMPLES;
    reg [3:0] state;
    reg start_d;
    reg [31:0] stop_r, step_r, sample_count;
    reg [32:0] threshold_r;
    reg [63:0] power_sum;
    reg have_best;
    reg [31:0] square_i, square_q;
    reg square_valid, power_valid;
    reg [32:0] sample_power;
    wire [63:0] sum_next = power_sum + {{31{1'b0}}, sample_power};
    wire [63:0] mean_power = sum_next >> MEASURE_LOG2;
    wire [32:0] fcw_next = {1'b0,current_fcw} + {1'b0,step_r};
    assign ddc_clear = (state == CLEAR) || (state == LOCK_CLEAR);
    // Two-stage power pipeline, valid is flushed on frequency changes.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            square_i<=0; square_q<=0; square_valid<=0;
            sample_power<=0; power_valid<=0;
        end else if (ddc_clear) begin
            square_i<=0; square_q<=0; square_valid<=0;
            sample_power<=0; power_valid<=0;
        end else begin
            square_valid <= iq_valid;
            power_valid <= square_valid;
            if (iq_valid) begin
                square_i <= $signed(iq_i) * $signed(iq_i);
                square_q <= $signed(iq_q) * $signed(iq_q);
            end
            if (square_valid)
                sample_power <= {1'b0,square_i} + {1'b0,square_q};
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; start_d<=0; stop_r<=0; step_r<=0; threshold_r<=0;
            sample_count<=0; power_sum<=0; have_best<=0; current_fcw<=0;
            scan_busy<=0; scan_done<=0; config_error<=0; signal_found<=0;
            point_valid<=0; point_fcw<=0; point_power<=0; best_fcw<=0; best_power<=0;
        end else begin
            start_d <= scan_start;
            scan_done <= 0;
            point_valid <= 0;
            case (state)
                IDLE: if (scan_start && !start_d) begin
                    signal_found<=0; config_error<=0; best_fcw<=0; best_power<=0;
                    have_best<=0; power_sum<=0; sample_count<=0;
                    if ((step_fcw == 0) || (start_fcw > stop_fcw)) begin
                        config_error<=1; scan_done<=1;
                    end else begin
                        stop_r<=stop_fcw; step_r<=step_fcw;
                        threshold_r<=power_threshold; current_fcw<=start_fcw;
                        scan_busy<=1; state<=CLEAR;
                    end
                end
                CLEAR: begin sample_count<=0; power_sum<=0; state<=SETTLE; end
                SETTLE: if (power_valid) begin
                    if (sample_count == WAIT_N-1) begin
                        sample_count<=0; power_sum<=0; state<=MEASURE;
                    end else sample_count <= sample_count + 1'b1;
                end
                MEASURE: if (power_valid) begin
                    power_sum <= sum_next;
                    if (sample_count == MEASURE_N-1) begin
                        // Average includes the final sample of this window.
                        point_power <= mean_power[32:0];
                        point_fcw <= current_fcw; state<=REPORT;
                    end else sample_count <= sample_count + 1'b1;
                end
                REPORT: begin
                    point_valid<=1;
                    if (!have_best || point_power > best_power) begin
                        best_power<=point_power; best_fcw<=current_fcw; have_best<=1;
                    end
                    state<=STEP;
                end
                STEP: begin
                    if (current_fcw == stop_r) state<=FINISH;
                    else begin
                        // Always include stop; prevent 32-bit FCW wraparound.
                        if (fcw_next >= {1'b0,stop_r}) current_fcw<=stop_r;
                        else current_fcw<=fcw_next[31:0];
                        state<=CLEAR;
                    end
                end
                FINISH: begin current_fcw<=best_fcw; state<=LOCK_CLEAR; end
                LOCK_CLEAR: begin sample_count<=0; state<=LOCK_WAIT; end
                LOCK_WAIT: if (power_valid) begin
                    if (sample_count == WAIT_N-1) begin
                        signal_found <= have_best && (best_power >= threshold_r)
                                        && (best_power != 0);
                        scan_busy<=0; scan_done<=1; state<=IDLE;
                    end else sample_count <= sample_count + 1'b1;
                end
                default: begin state<=IDLE; scan_busy<=0; end
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if (MEASURE_LOG2 < 0 || MEASURE_LOG2 > 30 || SETTLE_SAMPLES < 0) begin
            $display("ERROR: scan_controller parameter out of range."); $finish;
        end
    end
    // synthesis translate_on
endmodule
