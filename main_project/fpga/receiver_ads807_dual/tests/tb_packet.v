`timescale 1ns/1ps
module tb_packet;
    reg clk;
    reg rst_n;
    reg [287:0] samples [0:335];
    wire [287:0] fifo_q;
    wire fifo_empty;
    wire fifo_read;
    reg [383:0] response;
    reg response_valid;
    wire response_ready;
    wire [7:0] byte_data;
    wire byte_valid;
    wire byte_ready;
    reg [15:0] cycle;
    reg stalled;
    reg [7:0] held_byte;
    integer read_position;
    integer transmitted;
    integer bytefile;
    integer iqfile;
    integer n;
    reg [31:0] index_value;
    reg [31:0] sample_flags;
    reg [31:0] sample_estimate;
    assign fifo_empty = read_position == 336;
    assign fifo_q = fifo_empty ? {288{1'b1}} : samples[read_position];
    assign byte_ready = cycle[2:0] < 5 && !(cycle >= 300 && cycle < 1100);
    rx_tri_packet dut(
        .clk(clk), .rst_n(rst_n), .fifo_q(fifo_q), .fifo_empty(fifo_empty), .fifo_read(fifo_read),
        .response(response), .response_valid(response_valid), .response_ready(response_ready),
        .byte_data(byte_data), .byte_valid(byte_valid), .byte_ready(byte_ready)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            cycle <= 0;
            stalled <= 0;
            held_byte <= 0;
            read_position <= 0;
            transmitted <= 0;
        end else begin
            cycle <= cycle+1'b1;
            if (stalled && (!byte_valid || byte_data !== held_byte)) begin
                $fatal(1, "Packet byte changed under backpressure");
            end
            stalled <= byte_valid && !byte_ready;
            held_byte <= byte_data;
            if (fifo_read) begin
                if (fifo_empty) begin
                    $fatal(1, "Packet consumed an empty FIFO");
                end
                $fdisplay(iqfile, "%072x", fifo_q);
                read_position <= read_position+1;
            end
            if (byte_valid && byte_ready) begin
                $fdisplay(bytefile, "%02x", byte_data);
                transmitted <= transmitted+1;
            end
        end
    end
    task send_response;
        input [31:0] sequence_value;
        begin
            @(negedge clk);
            response = {32'd500, 32'd98000000, 32'h302, 32'd77, 32'd4, 32'd3,
                32'd1086083684, 32'd98000000, 32'd2, 32'd0, 32'd1, sequence_value};
            response_valid = 1;
            wait (response_ready);
            @(posedge clk);
            @(negedge clk);
            response_valid = 0;
            response = {384{1'b1}};
        end
    endtask
    initial begin
        rst_n = 0;
        response = 0;
        response_valid = 0;
        bytefile = $fopen("packet_bytes.txt", "w");
        iqfile = $fopen("packet_iq.txt", "w");
        for (n = 0; n < 336; n = n+1) begin
            index_value = n < 160 ? 32'hffffffe0+n : n-160;
            if (n >= 251) begin
                index_value = index_value+10;
            end
            sample_flags = n < 121 ? 32'h302 : 32'h102;
            if (n == 55 || n == 208) begin
                sample_flags = sample_flags | 32'h800;
            end
            sample_estimate = n < 201 ? 32'd98000000 : 32'd100001000;
            samples[n] = {sample_estimate, (n < 160 ? 32'd1 : 32'd2), sample_flags,
                (n < 160 ? 32'd1086083684 : 32'd1283587950),
                (n < 160 ? 32'd98000000 : 32'd100000000), (n < 160 ? 32'd1 : 32'd2),
                32'd0, index_value, (32'h98760000+n)};
        end
        repeat (3) @(negedge clk);
        rst_n = 1;
        send_response(42);
        wait (read_position == 150);
        send_response(43);
        wait (fifo_empty);
        repeat (18000) @(negedge clk);
        if (transmitted == 0 || transmitted % 512 != 0) begin
            $fatal(1, "Packet stream was truncated");
        end
        $fclose(bytefile);
        $fclose(iqfile);
        $display("PACKET_PASS samples=%0d frames=%0d", read_position, transmitted/512);
        $finish;
    end
    initial begin
        #1000000;
        $fatal(1, "Packet timeout");
    end
endmodule
