`timescale 1ns/1ps
// Isolate the actual Intel FIFO from host scheduling and packet arbitration.
module tb_fifo_budget;
    parameter DEPTH = 256;
    reg sample_clk = 0;
    reg usb_clk = 0;
    reg rst_n = 0;
    reg producing = 0;
    reg accepting = 0;
    integer phase = 0;
    reg [31:0] sample_index = 0;
    reg [31:0] dropped = 0;
    wire [287:0] data;
    wire [287:0] q;
    wire full;
    wire empty;
    wire valid;
    reg [287:0] expected [0:8191];
    integer written = 0;
    integer received = 0;
    integer gaps = 0;
    reg [31:0] previous_index = 0;
    reg [31:0] last_reported_drop = 0;

    always #11.494252874 sample_clk = !sample_clk;
    always #20.833333333 usb_clk = !usb_clk;
    assign valid = producing && phase == 86;
    assign data = {192'd0, dropped, sample_index, sample_index[15:0], sample_index[15:0]};
    rx_fifo_tri fifo(
        .aclr(!rst_n), .data(data), .wrclk(sample_clk),
        .wrreq(rst_n && valid && !full), .wrfull(full),
        .rdclk(usb_clk), .rdreq(rst_n && accepting && !empty),
        .rdempty(empty), .q(q)
    );

    always @(posedge sample_clk) begin
        if (!rst_n) begin
            phase <= 0;
            sample_index <= 0;
            dropped <= 0;
            written = 0;
        end else begin
            phase <= phase == 86 ? 0 : phase + 1;
            if (valid) begin
                sample_index <= sample_index + 1'b1;
                if (full) begin
                    dropped <= dropped + 1'b1;
                end else begin
                    expected[written] = data;
                    written = written + 1;
                end
            end
        end
    end

    always @(posedge usb_clk) begin
        if (!rst_n) begin
            received = 0;
            gaps = 0;
            previous_index = 0;
            last_reported_drop = 0;
        end else if (accepting && !empty) begin
            if (received >= written || q !== expected[received]) begin
                $fatal(1, "FIFO payload/order mismatch at %0d", received);
            end
            if (received != 0 && q[63:32] != previous_index + 1) begin
                gaps = gaps + 1;
            end
            previous_index = q[63:32];
            last_reported_drop = q[95:64];
            received = received + 1;
        end
    end

    task check_pause;
        input integer pause_us;
        integer paused_samples;
        integer paused_drops;
        integer expected_drops;
        begin
            @(negedge sample_clk);
            rst_n = 0;
            producing = 0;
            accepting = 0;
            #1000;
            @(negedge sample_clk);
            rst_n = 1;
            #20000;
            @(negedge sample_clk);
            producing = 1;
            #(pause_us * 1000);
            @(negedge sample_clk);
            paused_samples = sample_index;
            paused_drops = dropped;
            expected_drops = paused_samples > DEPTH ? paused_samples - DEPTH : 0;
            if (paused_drops != expected_drops) begin
                $fatal(1, "Capacity mismatch: samples=%0d dropped=%0d expected=%0d",
                    paused_samples, paused_drops, expected_drops);
            end
            accepting = 1;
            #150000;
            @(negedge sample_clk);
            producing = 0;
            #100000;
            if (!empty || received != written || sample_index != written + dropped ||
                last_reported_drop != dropped || gaps != (dropped != 0 ? 1 : 0)) begin
                $fatal(1, "Drain/accounting mismatch");
            end
            $display("FIFO_BUDGET depth=%0d pause_us=%0d produced_during_pause=%0d dropped_during_pause=%0d total_dropped=%0d delivered=%0d gaps=%0d",
                DEPTH, pause_us, paused_samples, paused_drops, dropped, received, gaps);
        end
    endtask

    initial begin
        check_pause(250);
        check_pause(500);
        check_pause(750);
        check_pause(1000);
        check_pause(2000);
        check_pause(5000);
        $display("FIFO_BUDGET_PASS");
        $finish;
    end

    initial begin
        #20000000;
        $fatal(1, "FIFO budget simulation watchdog expired");
    end
endmodule
