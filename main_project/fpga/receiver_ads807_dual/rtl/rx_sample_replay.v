// Test-only source: ordered USB writes fill 8192 ADC12 samples before circular replay.
module rx_sample_replay(
    input wire clk,
    input wire rst_n,
    input wire write_enable,
    input wire [11:0] write_address,
    input wire [23:0] write_data,
    output wire [11:0] adc_data,
    output reg loaded
);
    reg [23:0] samples [0:4095];
    reg [23:0] pair;
    reg [12:0] read_index;
    reg select_high;
    reg [12:0] written;
    assign adc_data = loaded ? (select_high ? pair[23:12] : pair[11:0]) : 12'd2048;
    // Neither the memory array nor its registered read port is reset.
    always @(posedge clk) begin
        if (write_enable) begin
            samples[write_address] <= write_data;
        end
        pair <= samples[read_index[12:1]];
        select_high <= read_index[0];
        if (!rst_n) begin
            loaded <= 0;
            read_index <= 0;
            written <= 0;
        end else if (write_enable) begin
            read_index <= 0;
            if (write_address == 0) begin
                loaded <= 0;
                written <= 1;
            end else if (!loaded && written == {1'b0, write_address}) begin
                written <= written + 1'b1;
                if (write_address == 4095) begin
                    loaded <= 1;
                end
            end else begin
                loaded <= 0;
                written <= 0;
            end
        end else if (loaded) begin
            read_index <= read_index + 1'b1;
        end
    end
endmodule
