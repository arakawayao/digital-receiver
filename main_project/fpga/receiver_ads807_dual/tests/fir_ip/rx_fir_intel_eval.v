// Isolated FIR II adapter: one I/Q pair per >=87 clocks, signed Q1.17 coefficients.
// A reset preserves IP history RAM; suppress the first 60 output pairs after reset.
module rx_fir_intel_eval (
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire signed [17:0] din_i,
    input wire signed [17:0] din_q,
    input wire input_clip,
    output reg signed [15:0] dout_i,
    output reg signed [15:0] dout_q,
    output reg out_valid,
    output reg clipped,
    output reg deadline_error
);
    reg signed [17:0] pending_q;
    reg q_valid;
    reg pair_pending;
    reg saved_clip;
    reg [6:0] cooldown;
    reg [5:0] warm_count;
    reg have_i;
    reg signed [15:0] saved_i;
    reg saved_i_clip;
    wire accept;
    wire sink_valid;
    wire signed [17:0] sink_data;
    wire signed [41:0] raw;
    wire raw_valid;
    wire raw_sop;
    wire raw_eop;
    wire raw_channel;
    wire [1:0] raw_error;
    wire signed [41:0] rounded;
    wire saturated;
    wire signed [15:0] result;

    assign accept = rst_n && valid && cooldown == 0 && !pair_pending;
    assign sink_valid = accept || q_valid;
    assign sink_data = q_valid ? pending_q : din_i;
    assign rounded = (raw + 42'sd65536) >>> 17;
    assign saturated = rounded > 32767 || rounded < -32768;
    assign result = rounded > 32767 ? 16'sh7fff :
        rounded < -32768 ? 16'sh8000 : rounded[15:0];

    rx_fir_intel_core core (
        .clk(clk),
        .reset_n(rst_n),
        .ast_sink_data(sink_data),
        .ast_sink_valid(sink_valid),
        .ast_sink_sop(accept),
        .ast_sink_eop(q_valid),
        .ast_sink_error(2'b00),
        .ast_source_data(raw),
        .ast_source_valid(raw_valid),
        .ast_source_sop(raw_sop),
        .ast_source_eop(raw_eop),
        .ast_source_channel(raw_channel),
        .ast_source_error(raw_error)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            pending_q <= 0;
            q_valid <= 0;
            pair_pending <= 0;
            saved_clip <= 0;
            cooldown <= 0;
            warm_count <= 0;
            have_i <= 0;
            saved_i <= 0;
            saved_i_clip <= 0;
            dout_i <= 0;
            dout_q <= 0;
            out_valid <= 0;
            clipped <= 0;
            deadline_error <= 0;
        end else begin
            out_valid <= 0;
            clipped <= 0;
            q_valid <= accept;
            if (cooldown != 0) begin
                cooldown <= cooldown - 1'b1;
            end
            if (valid && !accept) begin
                deadline_error <= 1;
            end
            if (accept) begin
                pending_q <= din_q;
                saved_clip <= input_clip;
                pair_pending <= 1;
                cooldown <= 86;
            end
            if (raw_valid) begin
                if (raw_error != 0 || !pair_pending ||
                    raw_sop != !raw_channel || raw_eop != raw_channel) begin
                    deadline_error <= 1;
                end
                if (!raw_channel) begin
                    saved_i <= result;
                    saved_i_clip <= saturated;
                    have_i <= 1;
                end else begin
                    pair_pending <= 0;
                    have_i <= 0;
                    if (!have_i) begin
                        deadline_error <= 1;
                    end
                    if (warm_count < 60) begin
                        warm_count <= warm_count + 1'b1;
                    end else begin
                        dout_i <= saved_i;
                        dout_q <= result;
                        clipped <= saved_clip || saved_i_clip || saturated;
                        out_valid <= have_i && pair_pending && raw_error == 0;
                    end
                end
            end
        end
    end
endmodule
