// Local FCR1 proposal: fixed 512-byte transport blocks, NOT offline IQ JSON.
// Capture at most 112 consecutive samples. A gap closes a partial block;
// the sample after the gap stays at the FIFO head until the next block.
// module rx_packet #(parameter ADC_RATE=56000000)(
//     input wire clk, input wire rst_n,
//     input wire [96:0] fifo_q, input wire fifo_empty, output wire fifo_read,
//     input wire [31:0] rf_hz, phase_step, epoch, input wire conjugate,
//     output wire [7:0] byte_data, output wire byte_valid, input wire byte_ready);
//     localparam FILL=0, WAIT_RAM=1, LOAD=2, HOLD=3;
//     reg [1:0] state;
//     reg [31:0] ram [0:111];
//     reg [31:0] ram_q;
//     reg [6:0] count;
//     reg [8:0] pos;
//     reg [31:0] first_index, dropped, next_index, sequence_id;
//     reg [31:0] frame_rf, frame_phase, frame_epoch;
//     reg frame_conjugate, frame_clip;
//     reg [31:0] crc;
//     reg [7:0] data_q;
//     wire gap = count!=0 && fifo_q[63:32]!=next_index;
//     assign fifo_read = rst_n && state==FILL && !fifo_empty && !gap;
//     assign byte_valid = rst_n && state==HOLD;
//     assign byte_data = data_q;
//     wire [6:0] address = pos>=60 && pos<508 ? (pos-60)>>2 : 0;
//     wire [1:0] lane = (pos-60) & 3;
//     reg [7:0] selected;
//     reg [31:0] header_word;
//     function [31:0] crc_byte;
//         input [31:0] previous; input [7:0] value;
//         reg [31:0] c; integer k;
//         begin
//             c=previous ^ value;
//             for(k=0;k<8;k=k+1) c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
//             crc_byte=c;
//         end
//     endfunction
//     always @* begin
//         case (pos[8:2])
//             0: header_word=32'h31524346; // ASCII FCR1
//             1: header_word={16'd60,16'd2}; // v2 RF field is FPGA estimate
//             2: header_word=sequence_id;
//             3: header_word=frame_epoch;
//             4: header_word=first_index;
//             5: header_word={25'd0,count};
//             6: header_word=dropped;
//             7: header_word=ADC_RATE;
//             8: header_word=32'd500000;
//             9: header_word=frame_rf;
//             10: header_word=frame_phase;
//             11: header_word={27'd0,1'b1,(first_index<66),frame_clip,frame_conjugate,(dropped!=0)};
//             12: header_word=32'd42;
//             13: header_word=32'd112;
//             14: header_word=32'd0;
//             default: header_word=32'd0;
//         endcase
//         if (pos<60) selected=header_word >> (8*pos[1:0]);
//         else if (pos<508)
// 				//calculate the position of iq data
//             selected=address<count ? ram_q >> (8*lane) : 8'd0;
//         else selected=(~crc) >> (8*pos[1:0]);
//     end
//     always @(posedge clk) begin
//         ram_q<=ram[address];
//         if (!rst_n) begin
//             state<=FILL; count<=0; pos<=0; sequence_id<=0;
//             first_index<=0; next_index<=0; dropped<=0;
//             frame_rf<=0; frame_phase<=0; frame_epoch<=0;
//             frame_conjugate<=0; frame_clip<=0; crc<=32'hffffffff; data_q<=0;
//         end else case(state)
//             FILL: begin
//                 if (!fifo_empty) begin
//                     if (gap) begin state<=WAIT_RAM; pos<=0; crc<=32'hffffffff; end
//                     else begin
//                         ram[count]<=fifo_q[31:0];
//                         if (count==0) begin
//                             first_index<=fifo_q[63:32];
//                             frame_rf<=rf_hz; frame_phase<=phase_step;
//                             frame_epoch<=epoch; frame_conjugate<=conjugate;
//                             frame_clip<=fifo_q[96];
//                         end else frame_clip<=frame_clip || fifo_q[96];
//                         dropped<=fifo_q[95:64]; next_index<=fifo_q[63:32]+1'b1;
//                         count<=count+1'b1;
//                         if (count==111) begin state<=WAIT_RAM; pos<=0; crc<=32'hffffffff; end
//                     end
//                 end
//             end
//             WAIT_RAM: state<=LOAD;
//             LOAD: begin data_q<=selected; state<=HOLD; end
//             HOLD: if (byte_ready) begin
//                 if(pos<508) crc<=crc_byte(crc,data_q);
//                 if(pos==511) begin
//                     sequence_id<=sequence_id+1'b1; count<=0; state<=FILL;
//                 end else begin pos<=pos+1'b1; state<=WAIT_RAM; end
//             end
//             default: state<=FILL;
//         endcase
//     end
// endmodule

// Local FCR1 proposal: fixed 512-byte transport blocks, NOT offline IQ JSON.
// Capture at most 112 consecutive samples. A gap closes a partial block;
// the sample after the gap stays at the FIFO head until the next block.
module rx_packet #(parameter ADC_RATE=56000000)(
    input wire clk,
    input wire rst_n,
    input wire [96:0] fifo_q,
    input wire fifo_empty,
    output wire fifo_read,
    input wire [31:0] rf_hz,
    input wire [31:0] phase_step,
    input wire [31:0] epoch,
    input wire conjugate,
    output wire [7:0] byte_data,
    output wire byte_valid,
    input wire byte_ready
);

    localparam FILL = 0;
    localparam WAIT_RAM = 1;
    localparam LOAD = 2;
    localparam HOLD = 3;

    reg [1:0] state;
    reg [31:0] ram [0:111];
    reg [31:0] ram_q;
    reg [6:0] count;
    reg [8:0] pos;
    reg [31:0] first_index;
    reg [31:0] dropped;
    reg [31:0] next_index;
    reg [31:0] sequence_id;
    reg [31:0] frame_rf;
    reg [31:0] frame_phase;
    reg [31:0] frame_epoch;
    reg frame_conjugate;
    reg frame_clip;
    reg [31:0] crc;
    reg [7:0] data_q;

    wire gap;
    assign gap = count != 0 && fifo_q[63:32] != next_index;

    assign fifo_read = rst_n && state == FILL && !fifo_empty && !gap;
    assign byte_valid = rst_n && state == HOLD;
    assign byte_data = data_q;

    wire [6:0] address;
    assign address = pos >= 60 && pos < 508 ? (pos - 60) >> 2 : 0;

    wire [1:0] lane;
    assign lane = (pos - 60) & 3;

    reg [7:0] selected;
    reg [31:0] header_word;

    function [31:0] crc_byte;
        input [31:0] previous;
        input [7:0] value;
        reg [31:0] c;
        integer k;
        begin
            c = previous ^ value;
            for (k = 0; k < 8; k = k + 1)
                c = c[0] ? (c >> 1) ^ 32'hedb88320 : c >> 1;
            crc_byte = c;
        end
    endfunction

    always @* begin
        case (pos[8:2])
            0: header_word = 32'h31524346; // ASCII FCR1
            1: header_word = {16'd60, 16'd2}; // v2 RF field is FPGA estimate
            2: header_word = sequence_id;
            3: header_word = frame_epoch;
            4: header_word = first_index;
            5: header_word = {25'd0, count};
            6: header_word = dropped;
            7: header_word = ADC_RATE;
            8: header_word = 32'd500000;
            9: header_word = frame_rf;
            10: header_word = frame_phase;
            11: header_word = {27'd0, 1'b1, (first_index < 66), frame_clip, frame_conjugate, (dropped != 0)};
            12: header_word = 32'd42;
            13: header_word = 32'd112;
            14: header_word = 32'd0;
            default: header_word = 32'd0;
        endcase
        if (pos < 60)
            selected = header_word >> (8 * pos[1:0]);
        else if (pos < 508)
            // calculate the position of iq data
            selected = address < count ? ram_q >> (8 * lane) : 8'd0;
        else
            selected = (~crc) >> (8 * pos[1:0]);
    end

    always @(posedge clk) begin
        ram_q <= ram[address];
        if (!rst_n) begin
            state <= FILL;
            count <= 0;
            pos <= 0;
            sequence_id <= 0;
            first_index <= 0;
            next_index <= 0;
            dropped <= 0;
            frame_rf <= 0;
            frame_phase <= 0;
            frame_epoch <= 0;
            frame_conjugate <= 0;
            frame_clip <= 0;
            crc <= 32'hffffffff;
            data_q <= 0;
        end else begin
            case (state)
                FILL: begin
                    if (!fifo_empty) begin
                        if (gap) begin
                            state <= WAIT_RAM;
                            pos <= 0;
                            crc <= 32'hffffffff;
                        end else begin
                            ram[count] <= fifo_q[31:0];
                            if (count == 0) begin
                                first_index <= fifo_q[63:32];
                                frame_rf <= rf_hz;
                                frame_phase <= phase_step;
                                frame_epoch <= epoch;
                                frame_conjugate <= conjugate;
                                frame_clip <= fifo_q[96];
                            end else begin
                                frame_clip <= frame_clip || fifo_q[96];
                            end
                            dropped <= fifo_q[95:64];
                            next_index <= fifo_q[63:32] + 1'b1;
                            count <= count + 1'b1;
                            if (count == 111) begin
                                state <= WAIT_RAM;
                                pos <= 0;
                                crc <= 32'hffffffff;
                            end
                        end
                    end
                end
                WAIT_RAM: begin
                    state <= LOAD;
                end
                LOAD: begin
                    data_q <= selected;
                    state <= HOLD;
                end
                HOLD: begin
                    if (byte_ready) begin
                        if (pos < 508) begin
                            crc <= crc_byte(crc, data_q);
                        end
                        if (pos == 511) begin
                            sequence_id <= sequence_id + 1'b1;
                            count <= 0;
                            state <= FILL;
                        end else begin
                            pos <= pos + 1'b1;
                            state <= WAIT_RAM;
                        end
                    end
                end
                default: begin
                    state <= FILL;
                end
            endcase
        end
    end

endmodule