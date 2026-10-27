module rx_capture #(parameter OFFSET_BINARY=1)(
    input wire clk, input wire rst_n, input wire enable,
    input wire [11:0] adc, output reg signed [11:0] sample,
    output reg valid);
    always @(posedge clk) begin
        if (!rst_n) begin sample <= 0; valid <= 0; end
        else begin
            valid <= enable;
            if (enable) sample <= {adc[11] ^ (OFFSET_BINARY != 0), adc[10:0]};
        end
    end
endmodule
