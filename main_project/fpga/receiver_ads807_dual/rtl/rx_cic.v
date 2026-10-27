// Intel CIC II: signed24, N=5, M=1, R=87, Hogenauer pruning to signed20.
// The core removes 37 LSBs; this wrapper removes three more, preserving /2^40.
// Continuous input: sample indices 0,87,... appear 20 clocks later. Valid gaps
// may hold the final in-flight result until input resumes; reset discards it.
module rx_cic #(
    parameter R = 87,
    parameter SHIFT = 40
)(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire signed [23:0] din,
    output wire signed [17:0] dout,
    output wire out_valid,
    output wire clipped
);
    wire signed [19:0] core_data;
    wire core_valid;
    assign dout = core_data >>> 3;
    assign out_valid = core_valid && rst_n;
    // Signed20 >>> 3 always fits signed18, so this conversion cannot clip.
    assign clipped = 1'b0;
    generate
        if (R != 87 || SHIFT != 40) begin : unsupported_configuration
            RX_CIC_REQUIRES_R87_SHIFT40 invalid_parameters();
        end
    endgenerate
    rx_cic_intel_core core(
        .clk(clk),
        .reset_n(rst_n),
        .clken(1'b1),
        .in_data(din),
        .in_valid(valid),
        .in_ready(),
        .in_error(2'b00),
        .out_data(core_data),
        .out_valid(core_valid),
        .out_ready(1'b1),
        .out_error()
    );
endmodule
