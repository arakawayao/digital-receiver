// 32-bit phase, 1024 phase positions, signed Q1.11 sine/cosine.
// Two ROM reads are synchronous; sample and valid follow the same pipeline.
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
    //initialize
    initial $readmemh("rtl/nco_sine.hex", rom);

    reg [31:0] phase;
    wire [9:0] sa;
    wire [9:0] ca;
    //
    assign sa = phase[31:22];
    assign ca = sa + 10'd256;

    reg signed [11:0] sin_q, cos_q, sample_q;
    reg v_q, conjugate_q;

    always @(posedge clk) begin
        sin_q <= rom[sa];
        cos_q <= rom[ca];
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
                sample_q <= sample; conjugate_q <= conjugate;
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
