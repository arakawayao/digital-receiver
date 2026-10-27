// Asynchronous assertion; synchronous release followed by 32 startup clocks.
module rx_reset(
    input wire clk,
    input wire arst_n,
    output wire rst_n
);
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] sync;
    reg [5:0] wait_count;
    assign rst_n = sync[1] && wait_count[5];
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            sync <= 0;
        end else begin
            sync <= {sync[0], 1'b1};
        end
    end
    // Only the synchronizer sees asynchronous release; the startup counter
    // stays synchronously reset until the second stage has settled.
    always @(posedge clk) begin
        if (!sync[1]) begin
            wait_count <= 0;
        end else if (!wait_count[5]) begin
            wait_count <= wait_count + 1'b1;
        end
    end
endmodule
