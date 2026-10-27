module rx_dsp #(
    parameter ADC_RATE = 43500000,
    parameter OFFSET_BINARY = 1
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire [11:0] adc,
    input wire [31:0] phase_step,
    input wire conjugate,
    output wire signed [15:0] i_out,
    output wire signed [15:0] q_out,
    output wire valid,
    output wire clipped,
    output wire deadline_error
);
    localparam R = ADC_RATE / 500000;
    wire signed [11:0] sample;
    wire capture_valid;
    wire mix_valid;
    wire ci_valid;
    wire cq_valid;
    wire ci_clip;
    wire cq_clip;
    wire signed [23:0] mi;
    wire signed [23:0] mq;
    wire signed [17:0] ci;
    wire signed [17:0] cq;
    rx_capture #(.OFFSET_BINARY(OFFSET_BINARY)) capture(
        .clk(clk), .rst_n(rst_n), .enable(enable), .adc(adc),
        .sample(sample), .valid(capture_valid)
    );
    rx_nco mixer(
        .clk(clk), .rst_n(rst_n), .valid(capture_valid), .sample(sample),
        .phase_step(phase_step), .conjugate(conjugate),
        .i_out(mi), .q_out(mq), .out_valid(mix_valid)
    );
    rx_cic #(.R(R), .SHIFT(40)) cic_i(
        .clk(clk), .rst_n(rst_n), .valid(mix_valid), .din(mi),
        .dout(ci), .out_valid(ci_valid), .clipped(ci_clip)
    );
    rx_cic #(.R(R), .SHIFT(40)) cic_q(
        .clk(clk), .rst_n(rst_n), .valid(mix_valid), .din(mq),
        .dout(cq), .out_valid(cq_valid), .clipped(cq_clip)
    );
    rx_fir fir(
        .clk(clk), .rst_n(rst_n), .valid(ci_valid && cq_valid),
        .din_i(ci), .din_q(cq), .input_clip(ci_clip || cq_clip),
        .dout_i(i_out), .dout_q(q_out), .out_valid(valid), .clipped(clipped),
        .deadline_error(deadline_error)
    );
endmodule
