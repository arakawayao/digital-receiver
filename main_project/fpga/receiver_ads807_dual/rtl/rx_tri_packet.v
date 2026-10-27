// TRI1 two-mode packet scheduler: ACK priority, immutable IQ metadata per sample.
module rx_tri_packet(
    input wire clk,
    input wire rst_n,
    input wire [287:0] fifo_q,
    input wire fifo_empty,
    output wire fifo_read,
    input wire [383:0] response,
    input wire response_valid,
    output wire response_ready,
    output wire [7:0] byte_data,
    output wire byte_valid,
    input wire byte_ready
);
    localparam IDLE = 0;
    localparam IQ_FILL = 1;
    localparam ACK_FILL = 2;
    localparam RAM_WAIT = 7;
    localparam LOAD = 8;
    localparam HOLD = 9;
    reg [3:0] state;
    reg [31:0] payload [0:110];
    reg [31:0] payload_q;
    reg [3:0] fill_word;
    reg [6:0] count;
    reg [8:0] position;
    reg [13:0] fill_timeout;
    reg [1:0] kind;
    reg [31:0] sequence_id;
    reg [31:0] frame_epoch;
    reg [31:0] first_index;
    reg [31:0] frame_rf;
    reg [31:0] frame_step;
    reg [31:0] frame_flags;
    reg [31:0] frame_aux;
    reg [31:0] frame_config;
    reg [31:0] frame_estimate;
    reg [31:0] crc;
    reg [7:0] data_q;
    reg [7:0] header_byte;
    reg [31:0] response_word;
    reg [7:0] selected;
    wire [6:0] payload_address;
    wire [8:0] payload_bytes;
    wire [4:0] byte_shift;
    wire gap;
    assign payload_address = position >= 64 && position < 508 ? (position-64) >> 2 : 0;
    assign payload_bytes = kind == 1 ? {count, 2'b00} : {2'd0, count};
    assign byte_shift = {position[1:0], 3'b000};
    assign response_ready = state == ACK_FILL && fill_word == 11;
    // An empty showahead FIFO has no valid head to compare against the frame.
    assign gap = !fifo_empty && count != 0 && (fifo_q[63:32] != first_index+count ||
        fifo_q[127:96] != frame_epoch || fifo_q[159:128] != frame_rf ||
        fifo_q[191:160] != frame_step || fifo_q[255:224] != frame_config ||
        fifo_q[287:256] != frame_estimate ||
        ((fifo_q[223:192] ^ frame_flags) & 32'hfffff7ff) != 0);
    assign fifo_read = state == IQ_FILL && !fifo_empty && !gap && count < 111 &&
        !(count != 0 && (fill_timeout == 12000 || response_valid));
    assign byte_data = data_q;
    assign byte_valid = state == HOLD;
    function [31:0] crc_byte;
        input [31:0] previous;
        input [7:0] value;
        reg [31:0] c;
        integer k;
        begin
            c = previous ^ value;
            for (k = 0; k < 8; k = k + 1) begin
                c = c[0] ? (c >> 1) ^ 32'hedb88320 : c >> 1;
            end
            crc_byte = c;
        end
    endfunction
    always @* begin
        case (fill_word)
            0: response_word = response[31:0];
            1: response_word = response[63:32];
            2: response_word = response[95:64];
            3: response_word = response[127:96];
            4: response_word = response[159:128];
            5: response_word = response[191:160];
            6: response_word = response[223:192];
            7: response_word = response[255:224];
            8: response_word = response[287:256];
            9: response_word = response[319:288];
            10: response_word = response[351:320];
            11: response_word = response[383:352];
            default: response_word = 0;
        endcase
    end
    always @* begin
        case (position[8:2])
            0: header_byte = 32'h31495254 >> byte_shift;
            1: header_byte = 32'h00400001 >> byte_shift;
            2: header_byte = {30'd0, kind} >> byte_shift;
            3: header_byte = sequence_id >> byte_shift;
            4: header_byte = frame_epoch >> byte_shift;
            5: header_byte = first_index >> byte_shift;
            6: header_byte = {25'd0, count} >> byte_shift;
            7: header_byte = 32'd43500000 >> byte_shift;
            8: header_byte = 32'd500000 >> byte_shift;
            9: header_byte = frame_rf >> byte_shift;
            10: header_byte = frame_step >> byte_shift;
            11: header_byte = frame_flags >> byte_shift;
            12: header_byte = frame_aux >> byte_shift;
            13: header_byte = frame_config >> byte_shift;
            14: header_byte = frame_estimate >> byte_shift;
            15: header_byte = kind == 1 && position[1:0] == 0 ? 8'd40 : 8'd0;
            default: header_byte = 0;
        endcase
        if (position < 64) begin
            selected = header_byte;
        end else if (position < 508) begin
            selected = position-64 < payload_bytes ? payload_q >> byte_shift : 8'd0;
        end else begin
            selected = (~crc) >> byte_shift;
        end
    end
    always @(posedge clk) begin
        payload_q <= payload[payload_address];
        if (!rst_n) begin
            state <= IDLE;
            fill_word <= 0;
            count <= 0;
            position <= 0;
            fill_timeout <= 0;
            kind <= 0;
            sequence_id <= 0;
            frame_epoch <= 0;
            first_index <= 0;
            frame_rf <= 0;
            frame_step <= 0;
            frame_flags <= 0;
            frame_aux <= 0;
            frame_config <= 0;
            frame_estimate <= 0;
            crc <= 32'hffffffff;
            data_q <= 0;
        end else begin
            case (state)
                IDLE: begin
                    position <= 0;
                    crc <= 32'hffffffff;
                    fill_word <= 0;
                    fill_timeout <= 0;
                    if (response_valid) begin
                        kind <= 3;
                        count <= 48;
                        frame_epoch <= response[223:192];
                        first_index <= response[287:256];
                        frame_rf <= response[159:128];
                        frame_step <= response[191:160];
                        frame_flags <= response[319:288];
                        frame_aux <= response[31:0];
                        frame_config <= response[255:224];
                        frame_estimate <= response[351:320];
                        state <= ACK_FILL;
                    end else if (!fifo_empty) begin
                        kind <= 1;
                        count <= 0;
                        state <= IQ_FILL;
                    end
                end
                IQ_FILL: begin
                    fill_timeout <= fill_timeout + 1'b1;
                    if (count == 111 || (count != 0 &&
                        (gap || fill_timeout == 12000 || response_valid))) begin
                        state <= RAM_WAIT;
                    end else if (fifo_read) begin
                        payload[count] <= fifo_q[31:0];
                        count <= count + 1'b1;
                        if (count == 0) begin
                            first_index <= fifo_q[63:32];
                            frame_aux <= fifo_q[95:64];
                            frame_epoch <= fifo_q[127:96];
                            frame_rf <= fifo_q[159:128];
                            frame_step <= fifo_q[191:160];
                            frame_flags <= fifo_q[223:192];
                            frame_config <= fifo_q[255:224];
                            frame_estimate <= fifo_q[287:256];
                        end else begin
                            frame_flags <= frame_flags | (fifo_q[223:192] & 32'h00000800);
                        end
                    end
                end
                ACK_FILL: begin
                    payload[fill_word] <= response_word;
                    fill_word <= fill_word + 1'b1;
                    if (fill_word == 11) begin
                        state <= RAM_WAIT;
                    end
                end
                RAM_WAIT: begin
                    state <= LOAD;
                end
                LOAD: begin
                    data_q <= selected;
                    state <= HOLD;
                end
                HOLD: begin
                    if (byte_ready) begin
                        if (position < 508) begin
                            crc <= crc_byte(crc, data_q);
                        end
                        if (position == 511) begin
                            sequence_id <= sequence_id + 1'b1;
                            state <= IDLE;
                        end else begin
                            position <= position + 1'b1;
                            state <= RAM_WAIT;
                        end
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
