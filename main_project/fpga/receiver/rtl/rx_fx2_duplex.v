// FX2 synchronous byte FIFO: EP2 IN (00) TX, EP6 OUT (10) RX.
// Indexed flags (PINFLAGSAB=PINFLAGSCD=0): FLAGB=selected FIFO not-full,
// FLAGC=selected FIFO not-empty. Select the endpoint and settle BEFORE testing.
// RX captures the current FIFO head BEFORE the SLRD consuming IFCLK edge.
module rx_fx2_duplex(input wire clk,rst_n,
    input wire flagb,flagc,inout wire [7:0] dq,
    output wire ifclk,slcs_n,slrd_n,slwr_n,sloe_n,a0,a1,pktend_n,pa0,
    input wire [7:0] tx_data,input wire tx_valid,output wire tx_ready,
    output reg [7:0] rx_data,output reg rx_valid,input wire rx_ready);
    localparam TX_TURN=0,TX_READY=1,TX_STROBE=2,TX_GUARD=3,
               RX_TURN=4,RX_ENABLE=5,RX_READY=6,RX_STROBE=7,RX_GUARD=8;
    reg [3:0] state;
    reg [2:0] wait_count;
    reg [7:0] data_q;
    reg flagb_q,flagc_q;
    wire receive_mode=state>=RX_TURN;
    rx_ifclk clock_forward(.datain_h(1'b0),.datain_l(1'b1),
        .outclock(clk),.outclocken(1'b1),.dataout(ifclk));
    assign slcs_n=!rst_n;
    assign a0=1'b0; assign a1=receive_mode;
    assign slrd_n=state!=RX_STROBE || !rst_n;
    assign slwr_n=state!=TX_STROBE || !rst_n;
    assign sloe_n=!(rst_n && state>=RX_ENABLE);
    assign pktend_n=1'b1;assign pa0=1'b1;
    assign dq=rst_n && (state==TX_STROBE || state==TX_GUARD) ? data_q : 8'bz;
    assign tx_ready=rst_n && state==TX_READY && flagb_q;
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=TX_TURN;wait_count<=0;data_q<=0;flagb_q<=0;flagc_q<=0;
            rx_data<=0;rx_valid<=0;
        end else begin
            flagb_q<=flagb;flagc_q<=flagc;
            if(rx_valid && rx_ready) rx_valid<=0;
            case(state)
                TX_TURN: if(wait_count==3) begin state<=TX_READY;wait_count<=0;end
                         else wait_count<=wait_count+1'b1;
                TX_READY: if(tx_valid && flagb_q) begin data_q<=tx_data;state<=TX_STROBE;end
                          else if(rx_ready) begin state<=RX_TURN;wait_count<=0;end
                TX_STROBE: state<=TX_GUARD;
                TX_GUARD: state<=TX_READY;
                RX_TURN: if(wait_count==3) begin state<=RX_ENABLE;wait_count<=0;end
                         else wait_count<=wait_count+1'b1;
                RX_ENABLE: if(wait_count==2) begin state<=RX_READY;wait_count<=0;end
                           else wait_count<=wait_count+1'b1;
                RX_READY: if(!rx_valid) begin
                    if(flagc_q && rx_ready) begin rx_data<=dq;rx_valid<=1;state<=RX_STROBE;end
                    else if(tx_valid) begin state<=TX_TURN;wait_count<=0;end
                end
                RX_STROBE: begin state<=RX_GUARD;wait_count<=0;end
                RX_GUARD: if(wait_count==1) begin state<=RX_READY;wait_count<=0;end
                          else wait_count<=wait_count+1'b1;
                default: begin state<=TX_TURN;wait_count<=0;end
            endcase
        end
    end
endmodule
