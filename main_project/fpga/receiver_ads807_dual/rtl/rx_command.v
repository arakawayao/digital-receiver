// TCM1 fixed packet parser. Consume the complete CRC-protected command before apply.
module rx_command(
    input wire clk,
    input wire rst_n,
    input wire [7:0] rx_data,
    input wire rx_valid,
    output wire rx_ready,
    output reg [159:0] command,
    output reg command_valid,
    input wire command_ready
);
    reg [9:0] position;
    reg [31:0] magic_shift;
    reg [31:0] crc;
    reg [31:0] received_crc;
    reg [31:0] version;
    reg bad_reserved;
    wire [31:0] next_magic;
    wire [31:0] final_crc;
    assign rx_ready = !command_valid;
    assign next_magic = {rx_data, magic_shift[31:8]};
    assign final_crc = {rx_data, received_crc[23:0]};
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
    always @(posedge clk) begin
        if (!rst_n) begin
            position <= 0;
            magic_shift <= 0;
            crc <= 32'hffffffff;
            received_crc <= 0;
            version <= 0;
            bad_reserved <= 0;
            command <= 0;
            command_valid <= 0;
        end else begin
            if (command_valid && command_ready) begin
                command_valid <= 0;
            end
            if (rx_valid && rx_ready) begin
                if (position == 0) begin
                    magic_shift <= next_magic;
                    if (next_magic == 32'h314d4354) begin
                        position <= 4;
                        crc <= crc_byte(crc_byte(crc_byte(crc_byte(32'hffffffff,
                            8'h54), 8'h43), 8'h4d), 8'h31);
                        bad_reserved <= 0;
                    end
                end else begin
                    position <= position + 1'b1;
                    if (position < 508) begin
                        crc <= crc_byte(crc, rx_data);
                    end
                    case (position[9:2])
                        1: version[8*position[1:0] +: 8] <= rx_data;
                        2: command[8*position[1:0] +: 8] <= rx_data;
                        3: command[32+8*position[1:0] +: 8] <= rx_data;
                        4: command[64+8*position[1:0] +: 8] <= rx_data;
                        5: command[96+8*position[1:0] +: 8] <= rx_data;
                        127: received_crc[8*position[1:0] +: 8] <= rx_data;
                        default: begin
                            if (rx_data != 0) begin
                                bad_reserved <= 1;
                            end
                        end
                    endcase
                    if (position == 511) begin
                        command[159:128] <= final_crc != ~crc ? 32'd1 :
                            (version != 2 || bad_reserved ? 32'd2 : 32'd0);
                        command_valid <= 1;
                        position <= 0;
                        magic_shift <= 0;
                    end
                end
            end
        end
    end
endmodule
