// All ports synchronous to adc_clk. Fs is the ADC sample rate, not crystal rate.
module adc_scan_top #(
    parameter integer SAMPLE_RATE_HZ = 240000000,
    parameter integer START_FREQ_HZ = 88000000,
    parameter integer STOP_FREQ_HZ = 108000000,
    parameter integer STEP_FREQ_HZ = 100000,
    parameter integer ADC_OFFSET_BINARY = 1,
    parameter integer DECIM_LOG2 = 9,
    parameter integer SETTLE_SAMPLES = 8,
    parameter integer MEASURE_LOG2 = 10
)(
    input wire adc_clk, rst_n,
    input wire [11:0] adc_data,
    input wire adc_valid, scan_start,
    input wire [32:0] power_threshold,
    output wire scan_busy, scan_done, config_error, signal_found,
    output wire [31:0] current_fcw,
    output wire point_valid,
    output wire [31:0] point_fcw,
    output wire [32:0] point_power,
    output wire [31:0] best_fcw,
    output wire [32:0] best_power,
    output wire signed [15:0] iq_i, iq_q,
    output wire iq_valid
);
    // Constant 64-bit calculation at elaboration, no hardware divider.
    localparam [63:0] START_FCW_WIDE =
        (64'd4294967296 * START_FREQ_HZ + SAMPLE_RATE_HZ/2) / SAMPLE_RATE_HZ;
    localparam [63:0] STOP_FCW_WIDE =
        (64'd4294967296 * STOP_FREQ_HZ + SAMPLE_RATE_HZ/2) / SAMPLE_RATE_HZ;
    localparam [63:0] STEP_FCW_WIDE =
        (64'd4294967296 * STEP_FREQ_HZ + SAMPLE_RATE_HZ/2) / SAMPLE_RATE_HZ;
    localparam [31:0] START_FCW = START_FCW_WIDE[31:0];
    localparam [31:0] STOP_FCW = STOP_FCW_WIDE[31:0];
    localparam [31:0] STEP_FCW = STEP_FCW_WIDE[31:0];

    wire ddc_clear, raw_iq_valid;
    assign iq_valid = raw_iq_valid && !scan_busy && signal_found;

    ddc_adc12 #(.ADC_OFFSET_BINARY(ADC_OFFSET_BINARY), .DECIM_LOG2(DECIM_LOG2))
    u_ddc (
        .clk(adc_clk), .rst_n(rst_n), .clear(ddc_clear),
        .adc_data(adc_data), .adc_valid(adc_valid), .nco_fcw(current_fcw),
        .iq_i(iq_i), .iq_q(iq_q), .iq_valid(raw_iq_valid)
    );
    
    scan_controller #(.SETTLE_SAMPLES(SETTLE_SAMPLES), .MEASURE_LOG2(MEASURE_LOG2))
    u_scan (
        .clk(adc_clk), .rst_n(rst_n), .scan_start(scan_start),
        .start_fcw(START_FCW), .stop_fcw(STOP_FCW), .step_fcw(STEP_FCW),
        .power_threshold(power_threshold), .iq_i(iq_i), .iq_q(iq_q),
        .iq_valid(raw_iq_valid), .ddc_clear(ddc_clear),
        .current_fcw(current_fcw), .scan_busy(scan_busy), .scan_done(scan_done),
        .config_error(config_error), .signal_found(signal_found),
        .point_valid(point_valid), .point_fcw(point_fcw), .point_power(point_power),
        .best_fcw(best_fcw), .best_power(best_power)
    );
    // synthesis translate_off
    initial begin
        if (SAMPLE_RATE_HZ <= 0 || START_FREQ_HZ < 0 ||
            STOP_FREQ_HZ < START_FREQ_HZ || STEP_FREQ_HZ <= 0 ||
            STOP_FREQ_HZ > SAMPLE_RATE_HZ/2) begin
            $display("ERROR: adc_scan_top requires 0 <= start <= stop <= Fs/2, step > 0.");
            $finish;
        end
    end
    // synthesis translate_on
endmodule