// RPL1 upload commands (512 bytes, CRC32), RPA1 acknowledgements (512 bytes).
// Upload a finite offset-binary ADC12 record, then cyclically replay at 56 MHz.
// No USB timing gaps are interpreted as ADC sampling gaps.
module rx_usb_replay(input wire usb_clk,sample_clk,usb_rst_n,sample_rst_n,
    input wire [7:0] rx_data,input wire rx_valid,output wire rx_ready,
    output wire [7:0] ack_data,output wire ack_valid,input wire ack_ready,
    output reg [11:0] adc_data,output reg active);
    localparam COLLECT=0,CHECK=1,APPLY=2,QUIESCE=3,START_WAIT=4;
    reg [2:0] state;
    reg [11:0] memory [0:8191];
    reg [11:0] payload [0:255];
    reg [11:0] payload_q;
    reg [8:0] pos;
    reg [159:0] header;
    reg reserved_bad;
    reg [31:0] input_crc,received_crc;
    reg [7:0] low_byte;
    reg payload_bad;
    reg [13:0] length,loaded;
    reg run_usb;
    (* altera_attribute="-name SYNCHRONIZER_IDENTIFICATION FORCED" *) reg [1:0] run_sync,active_sync;
    reg [12:0] read_address;
    reg [13:0] sample_length;
    // Capture the stable USB length while stopped; playback only uses local registers.
    always @(posedge sample_clk) if(!run_sync[1])sample_length<=length;
    reg [7:0] apply_index;
    reg [12:0] apply_address;
    reg apply_valid;
    reg ack_pending;
    reg [8:0] ack_pos;
    reg [31:0] ack_crc,ack_seq;
    reg [15:0] ack_op;
    reg [15:0] ack_status;
    reg [31:0] ack_word;
    wire [15:0] operation=header[63:48];
    wire [13:0] argument=header[109:96];
    wire [7:0] count=header[135:128];
    wire argument_bad=|header[127:110],count_bad=|header[159:136];
    assign rx_ready=usb_rst_n && state==COLLECT && !ack_pending;
    assign ack_valid=usb_rst_n && ack_pending;
    function [31:0] crc_byte;
        input [31:0] previous;input [7:0] value;
        reg [31:0] c;integer k;
        begin c=previous^value;
            for(k=0;k<8;k=k+1)c=c[0] ? (c>>1)^32'hedb88320 : c>>1;
            crc_byte=c;
        end
    endfunction
    always @* begin
        case(ack_pos[8:2])
            0:ack_word=32'h31415052; // RPA1
            1:ack_word={ack_status,16'd1};
            2:ack_word=ack_seq;
            3:ack_word={16'd0,ack_op};
            4:ack_word={18'd0,loaded};
            5:ack_word={18'd0,length};
            6:ack_word={31'd0,run_usb};
            default:ack_word=0;
        endcase
    end
    assign ack_data=ack_pos<508 ? (ack_word>>(8*ack_pos[1:0])) : ((~ack_crc)>>(8*ack_pos[1:0]));
    // Length is a bundled stable bus. It is written while run=0 and remains
    // stable through synchronisation, playback, and the stop acknowledgement.
    always @(posedge sample_clk or negedge sample_rst_n) begin
        if(!sample_rst_n) run_sync<=0;
        else run_sync<={run_sync[0],run_usb};
    end
    always @(posedge sample_clk) begin
        if(!sample_rst_n || !run_sync[1]) begin
            read_address<=0;adc_data<=2048;active<=0;
        end else begin
            adc_data<=memory[read_address];active<=1;
            if({1'b0,read_address}==sample_length-1'b1)read_address<=0;
            else read_address<=read_address+1'b1;
        end
    end
    always @(posedge usb_clk or negedge usb_rst_n) begin
        if(!usb_rst_n)active_sync<=0;
        else active_sync<={active_sync[0],active};
    end
    // Synchronous staging RAM read; the following clock commits each sample.
    always @(posedge usb_clk) payload_q<=payload[apply_index];
    always @(posedge usb_clk) begin
        if(!usb_rst_n) begin
            state<=COLLECT;pos<=0;header<=0;reserved_bad<=0;input_crc<=32'hffffffff;received_crc<=0;
            low_byte<=0;payload_bad<=0;length<=0;loaded<=0;run_usb<=0;
            apply_index<=0;apply_address<=0;apply_valid<=0;
            ack_pending<=0;ack_pos<=0;ack_crc<=32'hffffffff;ack_seq<=0;ack_op<=0;ack_status<=0;
        end else begin
            if(!ack_pending) begin ack_pos<=0;ack_crc<=32'hffffffff;end
            else if(ack_ready) begin
                if(ack_pos<508)ack_crc<=crc_byte(ack_crc,ack_data);
                if(ack_pos==511)begin ack_pending<=0;ack_pos<=0;end
                else ack_pos<=ack_pos+1'b1;
            end
            case(state)
                COLLECT: if(rx_valid && rx_ready) begin
                    if(pos==0)begin payload_bad<=0;reserved_bad<=0;end
                    if(pos<508)input_crc<=crc_byte(input_crc,rx_data);
                    if(pos<20)header<={rx_data,header[159:8]};
                    else if(pos<28)begin if(rx_data!=0)reserved_bad<=1;end
                    else if(pos<508)begin
                        if(!pos[0])low_byte<=rx_data;
                        else begin
                            payload[(pos-28)>>1]<={rx_data[3:0],low_byte};
                            if(rx_data[7:4]!=0)payload_bad<=1;
                        end
                    end else received_crc<={rx_data,received_crc[31:8]};
                    if(pos==511)begin state<=CHECK;pos<=0;end
                    else pos<=pos+1'b1;
                end
                CHECK: begin
                    input_crc<=32'hffffffff;ack_seq<=header[95:64];ack_op<=operation;
                    ack_status<=0;state<=COLLECT;
                    if(received_crc!=(~input_crc))begin ack_status<=1;ack_pending<=1;end
                    else if(header[31:0]!=32'h314c5052 || header[47:32]!=1 || reserved_bad)begin
                        ack_status<=2;ack_pending<=1;
                    end else if(argument_bad || count_bad)begin ack_status<=3;ack_pending<=1;end
                    else case(operation)
                        1: if(argument==0 || argument>8192 || count!=0)begin ack_status<=3;ack_pending<=1;end
                           else begin run_usb<=0;length<=argument[13:0];loaded<=0;state<=QUIESCE;end
                        2: if(run_usb || active_sync[1] || length==0 || argument!=loaded ||
                                  count==0 || count>240 || count>(length-loaded))begin
                               ack_status<=3;ack_pending<=1;
                           end else if(payload_bad)begin ack_status<=4;ack_pending<=1;end
                           else begin apply_index<=0;apply_valid<=0;state<=APPLY;end
                        3: if(argument!=0 || count!=0 || length==0 || loaded!=length)begin ack_status<=5;ack_pending<=1;end
                           else begin run_usb<=1;state<=START_WAIT;end
                        4: if(argument!=0 || count!=0)begin ack_status<=3;ack_pending<=1;end
                           else begin run_usb<=0;state<=QUIESCE;end
                        default:begin ack_status<=2;ack_pending<=1;end
                    endcase
                end
                APPLY: begin
                    if(apply_valid)memory[apply_address]<=payload_q;
                    if(apply_index<count)begin
                        apply_address<=loaded[12:0]+apply_index;apply_index<=apply_index+1'b1;apply_valid<=1;
                    end else apply_valid<=0;
                    if(apply_valid && apply_index==count)begin
                        loaded<=loaded+count;apply_valid<=0;state<=COLLECT;ack_pending<=1;
                    end
                end
                QUIESCE: if(!active_sync[1])begin state<=COLLECT;ack_pending<=1;end
                START_WAIT: if(active_sync[1])begin state<=COLLECT;ack_pending<=1;end
                default:state<=COLLECT;
            endcase
        end
    end
endmodule
