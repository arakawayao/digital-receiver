// Source holds data and valid until src_ready acknowledges destination consumption.
module rx_mailbox #(
    parameter WIDTH = 160
)(
    input wire src_clk,
    input wire src_rst_n,
    input wire [WIDTH-1:0] src_data,
    input wire src_valid,
    output wire src_ready,
    input wire dst_clk,
    input wire dst_rst_n,
    output wire [WIDTH-1:0] dst_data,
    output reg dst_valid,
    input wire dst_ready
);
    reg source_busy;
    assign dst_data = src_data;
    reg request_toggle;
    reg acknowledge_toggle;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] request_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] acknowledge_sync;
    assign src_ready = source_busy && request_toggle == acknowledge_sync[1];
    always @(posedge src_clk or negedge src_rst_n) begin
        if (!src_rst_n) begin
            source_busy <= 0;
            request_toggle <= 0;
            acknowledge_sync <= 0;
        end else begin
            acknowledge_sync <= {acknowledge_sync[0], acknowledge_toggle};
            if (src_valid && !source_busy) begin
                source_busy <= 1;
                request_toggle <= !request_toggle;
            end else if (src_ready) begin
                source_busy <= 0;
            end
        end
    end
    always @(posedge dst_clk or negedge dst_rst_n) begin
        if (!dst_rst_n) begin
            request_sync <= 0;
            acknowledge_toggle <= 0;
            dst_valid <= 0;
        end else begin
            request_sync <= {request_sync[0], request_toggle};
            if (!dst_valid && request_sync[1] != acknowledge_toggle) begin
                dst_valid <= 1;
            end else if (dst_valid && dst_ready) begin
                dst_valid <= 0;
                acknowledge_toggle <= request_sync[1];
            end
        end
    end
endmodule
