// phase32, 1024-entry signed12 Q1.11 ROM; sample/valid follow ROM latency.
module rx_nco(
    input wire clk,
    input wire rst_n,
    input wire valid,
    input wire signed [11:0] sample,
    input wire [31:0] phase_step,
    input wire conjugate,
    output reg signed [23:0] i_out,
    output reg signed [23:0] q_out,
    output reg out_valid
);
    reg signed [11:0] rom [0:1023];
    reg [31:0] phase;
    reg signed [11:0] sin_q;
    reg signed [11:0] cos_q;
    reg signed [11:0] sample_q;
    reg v_q;
    reg conjugate_q;
    wire [9:0] sine_address;
    wire [9:0] cosine_address;
    assign sine_address = phase[31:22];
    assign cosine_address = sine_address + 10'd256;
    initial begin
        $readmemh("rtl/nco_sine.hex", rom);
    end
    always @(posedge clk) begin
        sin_q <= rom[sine_address];
        cos_q <= rom[cosine_address];
        if (!rst_n) begin
            phase <= 0;
            sample_q <= 0;
            v_q <= 0;
            conjugate_q <= 0;
            i_out <= 0;
            q_out <= 0;
            out_valid <= 0;
        end else begin
            v_q <= valid;
            if (valid) begin
                sample_q <= sample;
                conjugate_q <= conjugate;
                phase <= phase + phase_step;
            end
            out_valid <= v_q;
            if (v_q) begin
                i_out <= sample_q * cos_q;
                q_out <= sample_q * (conjugate_q ? sin_q : -sin_q);
            end
        end
    end
endmodule
