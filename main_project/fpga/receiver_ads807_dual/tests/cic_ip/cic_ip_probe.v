module cic_ip_probe #(
    parameter OUT_WIDTH = 57
)(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire signed [23:0] din,
    output wire signed [56:0] dout,
    output wire out_valid,
    output wire ready
);
    wire signed [OUT_WIDTH-1:0] core_data;
    assign dout = core_data;
    rx_cic_intel_core core(
        .clk(clk),
        .reset_n(rst_n),
        .clken(1'b1),
        .in_data(din),
        .in_valid(valid),
        .in_ready(ready),
        .in_error(2'b00),
        .out_data(core_data),
        .out_valid(out_valid),
        .out_ready(1'b1),
        .out_error()
    );
endmodule
