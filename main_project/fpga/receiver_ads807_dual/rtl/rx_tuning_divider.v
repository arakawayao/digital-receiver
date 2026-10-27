// Constant-denominator restoring division; 64 cycles, rounded NCO phase increment.
module rx_tuning_divider(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] rf_hz,
    output reg done,
    output reg [31:0] phase_step
);
    reg active;
    reg [6:0] remaining;
    reg [63:0] quotient;
    reg [26:0] remainder;
    wire [27:0] shifted;
    wire subtract;
    wire [27:0] reduced;
    assign shifted = {remainder, quotient[63]};
    assign subtract = shifted >= 28'd43500000;
    assign reduced = subtract ? shifted - 28'd43500000 : shifted;
    always @(posedge clk) begin
        if (!rst_n) begin
            active <= 0;
            remaining <= 0;
            quotient <= 0;
            remainder <= 0;
            done <= 0;
            phase_step <= 0;
        end else begin
            done <= 0;
            if (start && !active) begin
                quotient <= {rf_hz - 32'd87000000, 32'd0} + 64'd21750000;
                remainder <= 0;
                remaining <= 64;
                active <= 1;
            end else if (active) begin
                quotient <= {quotient[62:0], subtract};
                remainder <= reduced[26:0];
                remaining <= remaining - 1'b1;
                if (remaining == 1) begin
                    active <= 0;
                    phase_step <= {quotient[30:0], subtract};
                    done <= 1;
                end
            end
        end
    end
endmodule
