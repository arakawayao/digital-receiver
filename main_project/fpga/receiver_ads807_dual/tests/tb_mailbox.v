`timescale 1ns/1ps
module tb_mailbox;
    reg src_clk;
    reg dst_clk;
    reg rst_n;
    reg [31:0] src_data;
    reg src_valid;
    wire src_ready;
    wire [31:0] dst_data;
    wire dst_valid;
    reg dst_ready;
    reg blocked;
    reg [31:0] previous_data;
    integer cycle;
    integer received;
    integer n;
    rx_mailbox #(.WIDTH(32)) dut(
        .src_clk(src_clk), .src_rst_n(rst_n), .src_data(src_data),
        .src_valid(src_valid), .src_ready(src_ready), .dst_clk(dst_clk),
        .dst_rst_n(rst_n), .dst_data(dst_data), .dst_valid(dst_valid), .dst_ready(dst_ready)
    );
    initial begin
        src_clk = 0;
        forever #5 src_clk = ~src_clk;
    end
    initial begin
        dst_clk = 0;
        forever #7 dst_clk = ~dst_clk;
    end
    always @(negedge dst_clk) begin
        cycle = cycle+1;
        dst_ready = rst_n && cycle % 13 >= 9;
    end
    always @(posedge dst_clk) begin
        if (!rst_n) begin
            received <= 0;
            blocked <= 0;
            previous_data <= 0;
        end else begin
            if (blocked && (!dst_valid || dst_data != previous_data)) begin
                $fatal(1, "Mailbox changed payload during destination backpressure");
            end
            if (dst_valid && dst_ready) begin
                if (dst_data != received) begin
                    $fatal(1, "Mailbox lost or duplicated transfer");
                end
                received <= received+1;
            end
            blocked <= dst_valid && !dst_ready;
            previous_data <= dst_data;
        end
    end
    task transfer;
        input integer value;
        begin
            @(negedge src_clk);
            src_data = value;
            src_valid = 1;
            @(posedge src_clk);
            while (!src_ready) @(posedge src_clk);
            @(negedge src_clk);
            src_valid = 0;
        end
    endtask
    initial begin
        rst_n = 0;
        src_data = 0;
        src_valid = 0;
        dst_ready = 0;
        cycle = 0;
        #100;
        rst_n = 1;
        for (n = 0; n < 100; n = n+1) begin
            transfer(n);
        end
        repeat (10) @(posedge src_clk);
        if (received != 100) begin
            $fatal(1, "Mailbox transfer count mismatch");
        end
        @(negedge src_clk);
        src_data = 100;
        src_valid = 1;
        #12;
        rst_n = 0;
        src_valid = 0;
        #100;
        rst_n = 1;
        for (n = 0; n < 10; n = n+1) begin
            transfer(n);
        end
        repeat (10) @(posedge src_clk);
        if (received != 10) begin
            $fatal(1, "Mailbox reset recovery failed");
        end
        $display("MAILBOX_PASS");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Mailbox timeout");
    end
endmodule
