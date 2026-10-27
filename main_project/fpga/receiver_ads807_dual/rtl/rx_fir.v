// 61 tap, signed Q1.17 CIC compensation at 500 kS/s. R87 allows 87 clocks/input.
// RAM is primed through filled; nearest rounding ties toward positive infinity.
module rx_fir(
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
    reg signed [17:0] coeff [0:60];
    reg signed [17:0] hist_i [0:127];
    reg signed [17:0] hist_q [0:127];
    reg [6:0] write_pos;
    reg [6:0] base;
    reg [5:0] tap;
    reg [6:0] filled;
    reg [6:0] active_filled;
    reg busy;
    reg last_read;
    reg read_valid;
    reg clip_q;
    reg history_zero;
    reg signed [17:0] ri;
    reg signed [17:0] rq;
    reg signed [17:0] rc;
    reg signed [41:0] acc_i;
    reg signed [41:0] acc_q;
    reg signed [41:0] final_i;
    reg signed [41:0] final_q;
    reg finish_pending;
    reg final_clip;
    wire [6:0] read_pos;
    wire signed [17:0] operand_i;
    wire signed [17:0] operand_q;
    wire signed [35:0] product_i;
    wire signed [35:0] product_q;
    wire signed [41:0] sum_i;
    wire signed [41:0] sum_q;
    wire signed [41:0] rounded_i;
    wire signed [41:0] rounded_q;
    assign read_pos = base - {1'b0, tap};
    assign operand_i = history_zero ? 18'sd0 : ri;
    assign operand_q = history_zero ? 18'sd0 : rq;
    assign product_i = operand_i * rc;
    assign product_q = operand_q * rc;
    assign sum_i = acc_i + {{6{product_i[35]}}, product_i};
    assign sum_q = acc_q + {{6{product_q[35]}}, product_q};
    assign rounded_i = (final_i + 42'sd65536) >>> 17;
    assign rounded_q = (final_q + 42'sd65536) >>> 17;
    initial begin
        $readmemh("rtl/fir_coeff.hex", coeff);
    end
    function [15:0] sat16;
        input signed [41:0] value;
        begin
            if (value > 32767) begin
                sat16 = 16'h7fff;
            end else if (value < -32768) begin
                sat16 = 16'h8000;
            end else begin
                sat16 = value[15:0];
            end
        end
    endfunction
    always @(posedge clk) begin
        ri <= hist_i[read_pos];
        rq <= hist_q[read_pos];
        rc <= coeff[tap];
        if (!rst_n) begin
            write_pos <= 0;
            base <= 0;
            filled <= 0;
            active_filled <= 0;
            tap <= 0;
            busy <= 0;
            read_valid <= 0;
            last_read <= 0;
            history_zero <= 1;
            acc_i <= 0;
            acc_q <= 0;
            out_valid <= 0;
            clipped <= 0;
            final_i <= 0;
            final_q <= 0;
            finish_pending <= 0;
            final_clip <= 0;
            dout_i <= 0;
            dout_q <= 0;
            clip_q <= 0;
            deadline_error <= 0;
        end else begin
            out_valid <= 0;
            clipped <= 0;
            finish_pending <= 0;
            if (finish_pending) begin
                dout_i <= sat16(rounded_i);
                dout_q <= sat16(rounded_q);
                clipped <= final_clip || rounded_i > 32767 || rounded_i < -32768 ||
                    rounded_q > 32767 || rounded_q < -32768;
                out_valid <= 1;
            end
            if (valid) begin
                if (busy || read_valid || finish_pending) begin
                    deadline_error <= 1;
                end else begin
                    hist_i[write_pos] <= din_i;
                    hist_q[write_pos] <= din_q;
                    base <= write_pos;
                    write_pos <= write_pos + 1'b1;
                    if (filled < 61) begin
                        filled <= filled + 1'b1;
                    end
                    active_filled <= filled < 61 ? filled + 1'b1 : filled;
                    tap <= 0;
                    busy <= 1;
                    acc_i <= 0;
                    acc_q <= 0;
                    clip_q <= input_clip;
                end
            end
            read_valid <= busy;
            history_zero <= {1'b0, tap} >= active_filled;
            last_read <= busy && tap == 60;
            if (busy) begin
                if (tap == 60) begin
                    busy <= 0;
                end else begin
                    tap <= tap + 1'b1;
                end
            end
            if (read_valid) begin
                acc_i <= sum_i;
                acc_q <= sum_q;
                if (last_read) begin
                    final_i <= sum_i;
                    final_q <= sum_q;
                    final_clip <= clip_q;
                    finish_pending <= 1;
                end
            end
        end
    end
endmodule
