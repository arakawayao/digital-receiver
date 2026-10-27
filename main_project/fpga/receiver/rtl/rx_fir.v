// 61-tap compensation/low-pass, Fs=500 kS/s, Q1.17 coefficients.
// One MAC per I/Q lane. Requires >=64 clocks between valid inputs.
// History RAM is zero-primed with a count, avoiding reset of RAM cells.
module rx_fir(
    input wire clk, 
    input wire rst_n, 
    input wire valid,
    input wire signed [17:0] din_i, din_q,
    input wire input_clip, 
    output reg signed [15:0] dout_i, dout_q,
    output reg out_valid, 
    output reg clipped, 
    output reg deadline_error
    );
    //reg defines
    reg signed [17:0] coeff [0:60];
    reg signed [17:0] hist_i [0:127], hist_q [0:127];
    initial $readmemh("rtl/fir_coeff.hex", coeff);
    reg [6:0] write_pos, base;
    reg [5:0] tap;
    reg [6:0] filled, active_filled;
    reg busy, last_read, read_valid, clip_q, history_zero;
    wire [6:0] read_pos = base - {1'b0,tap};
    reg signed [17:0] ri, rq, rc;
    reg signed [41:0] acc_i, acc_q, final_i, final_q;
    reg finish_pending, final_clip;
    wire signed [17:0] operand_i = history_zero ? 18'sd0 : ri;
    wire signed [17:0] operand_q = history_zero ? 18'sd0 : rq;
    wire signed [35:0] pi = operand_i * rc, pq = operand_q * rc;
    wire signed [41:0] sum_i = acc_i + {{6{pi[35]}},pi};
    wire signed [41:0] sum_q = acc_q + {{6{pq[35]}},pq};
    // Add half LSB then arithmetic shift: nearest, ties toward +infinity.
    wire signed [41:0] rounded_i = (final_i + 42'sd65536) >>> 17;
    wire signed [41:0] rounded_q = (final_q + 42'sd65536) >>> 17;
    function [15:0] sat16;
        input signed [41:0] x;
        begin
            if (x > 32767) sat16=16'h7fff;
            else if (x < -32768) sat16=16'h8000;
            else sat16=x[15:0];
        end
    endfunction
    always @(posedge clk) begin
        // Synchronous read of simple dual-port RAM and coefficient ROM.
        ri <= hist_i[read_pos]; rq <= hist_q[read_pos]; rc <= coeff[tap];
        if (!rst_n) begin
            write_pos<=0; base<=0; filled<=0; active_filled<=0;
            tap<=0; busy<=0; read_valid<=0; last_read<=0; history_zero<=1;
            acc_i<=0; acc_q<=0; out_valid<=0; clipped<=0;
            final_i<=0; final_q<=0; finish_pending<=0; final_clip<=0;
            dout_i<=0; dout_q<=0; clip_q<=0; deadline_error<=0;
        end else begin
            out_valid<=0; clipped<=0; finish_pending<=0;
            // Separate last-tap multiply/accumulate from rounding/saturation.
            // Output is 63 clocks after acceptance, before the next R112 input.
            if(finish_pending) begin
                dout_i<=sat16(rounded_i); dout_q<=sat16(rounded_q);
                clipped<=final_clip || rounded_i>32767 || rounded_i< -32768 ||
                    rounded_q>32767 || rounded_q< -32768;
                out_valid<=1;
            end
            if (valid) begin
                if (busy || read_valid) deadline_error<=1;
                else begin
                    hist_i[write_pos]<=din_i; hist_q[write_pos]<=din_q;
                    base<=write_pos; write_pos<=write_pos+1'b1;
                    if (filled<61) filled<=filled+1'b1;
                    active_filled<=filled<61 ? filled+1'b1 : filled;
                    tap<=0; busy<=1; acc_i<=0; acc_q<=0; clip_q<=input_clip;
                end
            end
            read_valid<=busy;
            history_zero <= {1'b0,tap}>=active_filled;
            last_read<=busy && tap==60;
            if (busy) begin
                // RAM output register remains unconditional for block RAM inference.
                if (tap==60) busy<=0;
                else tap<=tap+1'b1;
            end
            if (read_valid) begin
                acc_i<=sum_i; acc_q<=sum_q;
                if (last_read) begin
                    final_i<=sum_i; final_q<=sum_q;
                    final_clip<=clip_q; finish_pending<=1;
                end
            end
        end
    end
endmodule
