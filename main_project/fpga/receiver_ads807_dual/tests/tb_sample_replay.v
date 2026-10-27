`timescale 1ns/1ps
module tb_sample_replay;
    reg clk;
    reg rst_n;
    reg write_enable;
    reg [11:0] write_address;
    reg [23:0] write_data;
    wire [11:0] adc_data;
    wire loaded;
    integer n;
    integer expected;
    rx_sample_replay dut(
        .clk(clk), .rst_n(rst_n), .write_enable(write_enable),
        .write_address(write_address), .write_data(write_data), .adc_data(adc_data), .loaded(loaded)
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    initial begin
        rst_n = 0;
        write_enable = 0;
        write_address = 0;
        write_data = 0;
        #20;
        @(negedge clk);
        rst_n = 1;
        write_enable = 1;
        write_address = 1;
        write_data = 24'h123456;
        @(negedge clk);
        if (loaded || adc_data != 2048) begin
            $fatal(1, "Partial/out-of-order upload became active");
        end
        for (n = 0; n < 4096; n = n + 1) begin
            write_address = n;
            write_data = {12'habc, n[11:0]};
            @(negedge clk);
            if (n < 4095 && loaded) begin
                $fatal(1, "Replay enabled before complete upload");
            end
        end
        write_enable = 0;
        if (!loaded) begin
            $fatal(1, "Complete upload did not enable replay");
        end
        // Wait through read-port startup; then check more than two full loops.
        @(negedge clk);
        for (n = 0; n < 17000; n = n + 1) begin
            expected = n % 8192;
            if (adc_data !== (expected % 2 ? 12'habc : expected/2)) begin
                $fatal(1, "Circular replay data/order mismatch at %0d: %h", n, adc_data);
            end
            @(negedge clk);
        end
        write_enable = 1;
        write_address = 0;
        @(negedge clk);
        if (loaded || adc_data != 2048) begin
            $fatal(1, "Replacement upload did not mute source");
        end
        $display("SAMPLE_REPLAY_PASS");
        $finish;
    end
endmodule
