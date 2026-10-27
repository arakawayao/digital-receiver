`timescale 1ns/1ps

module adc_capture_tb;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg den = 1'b0;
    reg [11:0] din = 12'd0;
    wire signed [11:0] offset_data;
    wire signed [11:0] twos_data;
    wire offset_valid;
    wire twos_valid;
    integer expected_offset = 0;
    integer expected_twos = 0;
    integer code;
    integer cycles = 0;

    always #5 clk = ~clk;

    adc_capture dut_offset (
        .clk(clk), .rst_n(rst_n), .den(den), .din(din),
        .dout(offset_data), .dvalid(offset_valid)
    );

    adc_capture #(.OFFSET_BINARY(1'b0)) dut_twos (
        .clk(clk), .rst_n(rst_n), .den(den), .din(din),
        .dout(twos_data), .dvalid(twos_valid)
    );

    task automatic step(input bit reset_released, input bit enabled,
                        input reg [11:0] raw_code);
        reg signed [11:0] previous_offset;
        reg signed [11:0] previous_twos;
        reg previous_valid;
        begin
            @(negedge clk);
            previous_offset = offset_data;
            previous_twos = twos_data;
            previous_valid = offset_valid;
            rst_n = reset_released;
            den = enabled;
            din = raw_code;
            #1;
            // Synchronous reset and input changes must wait for the capture edge.
            if (offset_data !== previous_offset || twos_data !== previous_twos ||
                offset_valid !== previous_valid || twos_valid !== previous_valid)
                $fatal(1, "Outputs changed before capture edge");
            if (!reset_released) begin
                expected_offset = 0;
                expected_twos = 0;
            end else if (enabled) begin
                expected_offset = integer'(raw_code) - 2048;
                expected_twos = raw_code >= 2048 ? integer'(raw_code) - 4096
                                                : integer'(raw_code);
            end
            @(posedge clk);
            #1;
            if (offset_data !== expected_offset[11:0] ||
                twos_data !== expected_twos[11:0])
                $fatal(1, "Data mismatch: code=%0d rst_n=%0b den=%0b", raw_code,
                       reset_released, enabled);
            if (offset_valid !== (enabled && reset_released) ||
                twos_valid !== (enabled && reset_released))
                $fatal(1, "Valid mismatch at cycle %0d", cycles);
            if (integer'(offset_data) != expected_offset ||
                integer'(twos_data) != expected_twos)
                $fatal(1, "Signed value mismatch");
            cycles = cycles + 1;
        end
    endtask

    initial begin
        step(0, 1, 12'hfff);
        step(0, 0, 12'h800);
        step(1, 0, 12'h123);
        for (code = 0; code < 4096; code = code + 1)
            step(1, 1, code[11:0]);
        for (code = 0; code < 128; code = code + 1)
            step(1, code % 2, (code * 137) % 4096);
        step(1, 1, 12'h7ff);
        step(0, 1, 12'hfff);
        step(1, 0, 12'h800);
        step(1, 1, 12'h800);
        step(1, 0, 12'h000);
        step(1, 1, 12'hfff);
        $display("ADC_CAPTURE_PASS cycles=%0d", cycles);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
