// EP2 IN / EP6 OUT indexed flags. Both directions have bounded byte budgets.
module rx_fx2_tri(
    input wire clk,
    input wire rst_n,
    input wire flagb,
    input wire flagc,
    inout wire [7:0] dq,
    output wire ifclk,
    output wire slcs_n,
    output wire slrd_n,
    output wire slwr_n,
    output wire sloe_n,
    output wire a0,
    output wire a1,
    output wire pktend_n,
    output wire pa0,
    input wire [7:0] tx_data,
    input wire tx_valid,
    output wire tx_ready,
    output reg [7:0] rx_data,
    output reg rx_valid,
    input wire rx_ready
);
    localparam TX_TURN = 0;
    localparam TX_READY = 1;
    localparam TX_STROBE = 2;
    localparam TX_GUARD = 3;
    localparam RX_TURN = 4;
    localparam RX_ENABLE = 5;
    localparam RX_READY = 6;
    localparam RX_STROBE = 7;
    localparam RX_GUARD = 8;
    reg [3:0] state;
    reg [2:0] wait_count;
    reg [5:0] budget;
    reg [7:0] data_q;
    reg [7:0] dq_sample;
    reg flagb_q;
    reg flagc_q;
    wire receive_mode;
    assign receive_mode = state >= RX_TURN;
    assign slcs_n = !rst_n;
    assign a0 = 1'b0;
    assign a1 = receive_mode;
    assign slrd_n = !rst_n || state != RX_STROBE;
    assign slwr_n = !rst_n || state != TX_STROBE;
    assign sloe_n = !(rst_n && state >= RX_ENABLE);
    assign pktend_n = 1'b1;
    assign pa0 = 1'b1;
    assign dq = rst_n && (state == TX_STROBE || state == TX_GUARD) ? data_q : 8'bz;
    assign tx_ready = rst_n && state == TX_READY && flagb_q;
    rx_ifclk clock_forward(
        .datain_h(1'b0), .datain_l(1'b1), .outclock(clk),
        .outclocken(1'b1), .dataout(ifclk)
    );
    // Continuous input register can pack into the I/O cell. RX_ENABLE settles
    // the selected FIFO head before RX_READY consumes this registered value.
    always @(posedge clk) begin
        dq_sample <= dq;
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= TX_TURN;
            wait_count <= 0;
            budget <= 0;
            data_q <= 0;
            flagb_q <= 0;
            flagc_q <= 0;
            rx_data <= 0;
            rx_valid <= 0;
        end else begin
            flagb_q <= flagb;
            flagc_q <= flagc;
            if (rx_valid && rx_ready) begin
                rx_valid <= 0;
            end
            case (state)
                TX_TURN: begin
                    if (wait_count == 3) begin
                        state <= TX_READY;
                        wait_count <= 0;
                        budget <= 0;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end
                TX_READY: begin
                    if (tx_valid && flagb_q) begin
                        data_q <= tx_data;
                        state <= TX_STROBE;
                    end else if (rx_ready) begin
                        state <= RX_TURN;
                        wait_count <= 0;
                    end
                end
                TX_STROBE: begin
                    state <= TX_GUARD;
                end
                TX_GUARD: begin
                    budget <= budget + 1'b1;
                    if (budget == 63 && rx_ready) begin
                        state <= RX_TURN;
                        wait_count <= 0;
                    end else begin
                        state <= TX_READY;
                    end
                end
                RX_TURN: begin
                    if (wait_count == 3) begin
                        state <= RX_ENABLE;
                        wait_count <= 0;
                        budget <= 0;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end
                RX_ENABLE: begin
                    if (wait_count == 2) begin
                        state <= RX_READY;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end
                RX_READY: begin
                    if (!rx_valid && flagc_q && rx_ready) begin
                        rx_data <= dq_sample;
                        rx_valid <= 1;
                        state <= RX_STROBE;
                    end else if (!flagc_q || !rx_ready) begin
                        state <= TX_TURN;
                        wait_count <= 0;
                    end
                end
                RX_STROBE: begin
                    state <= RX_GUARD;
                    wait_count <= 0;
                end
                RX_GUARD: begin
                    if (wait_count == 1) begin
                        budget <= budget + 1'b1;
                        state <= budget == 63 ? TX_TURN : RX_READY;
                        wait_count <= 0;
                    end else begin
                        wait_count <= wait_count + 1'b1;
                    end
                end
                default: begin
                    state <= TX_TURN;
                    wait_count <= 0;
                end
            endcase
        end
    end
endmodule
