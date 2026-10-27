`timescale 1ns/1ps
module tb_sample_control;
    parameter USB_MODE = 2;
    reg clk;
    reg rst_n;
    reg [159:0] command;
    reg command_valid;
    wire command_ready;
    wire [383:0] response;
    wire response_valid;
    wire [1:0] mode;
    wire running;
    rx_control #(.USB_REPLAY(USB_MODE)) dut(
        .clk(clk), .rst_n(rst_n), .command(command), .command_valid(command_valid),
        .command_ready(command_ready), .response(response), .response_valid(response_valid),
        .response_ready(1'b1), .detector_locked(1'b0), .detector_update(1'b0),
        .detector_rf(32'd0), .detector_phase_step(32'd0), .iq_valid(1'b0), .mode(mode), .running(running),
        .dsp_run(), .tuned(), .tuned_rf(), .phase_step(), .epoch(), .config_id(),
        .sample_index(), .flags(), .estimated_rf()
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    task request;
        input [31:0] opcode;
        input [31:0] argument;
        input [31:0] address;
        input [31:0] error;
        begin
            wait (command_ready);
            @(negedge clk);
            command = {32'd0, address, argument, opcode, 32'd42};
            command_valid = 1;
            @(negedge clk);
            command_valid = 0;
            wait (response_valid);
            if (response[95:64] != error || response[63:32] != opcode || response[31:0] != 42) begin
                $fatal(1, "Sample opcode/mode rejection mismatch");
            end
            @(negedge clk);
        end
    endtask
    initial begin
        rst_n = 0;
        command = 0;
        command_valid = 0;
        #20;
        @(negedge clk);
        rst_n = 1;
        if (mode != USB_MODE || !running) begin
            $fatal(1, "Wrong fixed test mode");
        end
        request(7, 0, 0, 0);
        request(9, 24'h123456, 0, 0);
        request(9, 32'h01000000, 0, 4);
        request(9, 0, 4096, 4);
        request(2, USB_MODE == 1 ? 2 : 1, 0, 4);
        request(2, USB_MODE, 0, 0);
        request(9, 0, 0, 5);
        $display("SAMPLE_CONTROL_PASS");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Sample control timeout");
    end
endmodule
