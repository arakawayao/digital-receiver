`timescale 1ns/1ps
module tb_control;
    reg clk;
    reg rst_n;
    reg [159:0] command;
    reg command_valid;
    wire command_ready;
    wire [383:0] response;
    reg response_ready;
    wire response_valid;
    reg detector_locked;
    reg [31:0] detector_rf;
    reg [31:0] detector_step;
    reg iq_valid;
    wire [31:0] flags;
    wire dsp_run;
    wire tuned;
    wire running;
    wire [31:0] tuned_rf;
    wire [31:0] phase_step;
    wire [31:0] epoch;
    wire [31:0] config_id;
    wire [31:0] sample_index;
    reg [383:0] last_response;
    reg [31:0] previous_epoch;
    reg [31:0] previous_config;
    reg [31:0] previous_index;
    integer warmup_sample;
    rx_control dut(
        .clk(clk), .rst_n(rst_n), .command(command), .command_valid(command_valid),
        .command_ready(command_ready), .response(response), .response_valid(response_valid),
        .response_ready(response_ready), .detector_locked(detector_locked), .detector_update(1'b0),
        .detector_rf(detector_rf), .detector_phase_step(detector_step), .iq_valid(iq_valid),
        .mode(), .running(running), .dsp_run(dsp_run), .tuned(tuned), .tuned_rf(tuned_rf),
        .phase_step(phase_step), .epoch(epoch), .config_id(config_id), .sample_index(sample_index),
        .flags(flags), .estimated_rf()
    );
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    task request;
        input [31:0] opcode;
        input [31:0] argument;
        input [31:0] rf;
        input [31:0] error;
        begin
            wait (command_ready);
            @(negedge clk);
            command = {32'd0, rf, argument, opcode, 32'd42};
            command_valid = 1;
            @(negedge clk);
            command_valid = 0;
            wait (response_valid);
            #1;
            last_response = response;
            if (response[95:64] != error || response[63:32] != opcode || response[31:0] != 42) begin
                $fatal(1, "Control ACK mismatch");
            end
            repeat (4) begin
                @(negedge clk);
                if (response !== last_response || !response_valid || command_ready) begin
                    $fatal(1, "ACK changed before mailbox consumption");
                end
            end
            response_ready = 1;
            @(negedge clk);
            response_ready = 0;
        end
    endtask
    task check_response_stall;
        begin
            wait (command_ready);
            @(negedge clk);
            command = {32'd0, 32'd0, 32'd0, 32'd1, 32'd43};
            command_valid = 1;
            @(negedge clk);
            command_valid = 0;
            wait (response_valid);
            #1;
            last_response = response;
            previous_config = config_id;
            previous_index = sample_index;
            detector_locked = 0;
            detector_rf = detector_rf + 1000;
            detector_step = detector_step + 98735;
            repeat (70) begin
                @(negedge clk);
                if (response !== last_response || !response_valid || command_ready) begin
                    $fatal(1, "ACK changed while live IQ and quality advanced");
                end
            end
            if (sample_index <= previous_index || flags[12] || flags[9] ||
                !last_response[300] || !last_response[297]) begin
                $fatal(1, "ACK stall did not exercise changing live status");
            end
            detector_locked = 1;
            repeat (4) begin
                @(negedge clk);
                if (response !== last_response || config_id != previous_config) begin
                    $fatal(1, "Automatic retune changed a pending ACK");
                end
            end
            response_ready = 1;
            @(negedge clk);
            response_ready = 0;
            wait (config_id != previous_config);
            #1;
            if (phase_step != detector_step || tuned_rf != detector_rf || !dsp_run) begin
                $fatal(1, "Automatic retune did not resume after ACK consumption");
            end
        end
    endtask
    task check_warmup;
        begin
            for (warmup_sample = 0; warmup_sample < 66; warmup_sample = warmup_sample+1) begin
                @(negedge clk);
                if (!flags[12]) begin
                    $fatal(1, "Warmup ended before 66 valid samples");
                end
                iq_valid = 1;
                @(negedge clk);
                iq_valid = 0;
                repeat (2) @(negedge clk);
                if (flags[12] != (warmup_sample < 65)) begin
                    $fatal(1, "Warmup changed during a gap or exceeded 66 samples");
                end
            end
        end
    endtask
    initial begin
        rst_n = 0;
        command = 0;
        command_valid = 0;
        response_ready = 0;
        detector_locked = 0;
        detector_rf = 0;
        detector_step = 0;
        iq_valid = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        request(2, 2, 0, 0);
        request(3, 1086083684, 98000000, 0);
        if (last_response[159:128] != 98000000 || last_response[191:160] != 1086083684 ||
            last_response[223:192] != epoch || last_response[255:224] != config_id) begin
            $fatal(1, "ACK did not snapshot the committed tune");
        end
        wait (dsp_run);
        check_warmup;
        iq_valid = 1;
        previous_epoch = epoch;
        previous_config = config_id;
        request(3, 0, 98000000, 4);
        request(3, 2073432489, 98000000, 4);
        request(3, 98734879, 98000000, 4);
        if (epoch != previous_epoch || config_id != previous_config || phase_step != 1086083684 || !dsp_run) begin
            $fatal(1, "Rejected step changed the running channel");
        end
        request(3, 98734880, 88000000, 0);
        if (phase_step != 98734880 || tuned_rf != 88000000) begin
            $fatal(1, "Lower manual endpoint failed");
        end
        request(3, 2073432488, 108000000, 0);
        if (phase_step != 2073432488 || tuned_rf != 108000000) begin
            $fatal(1, "Upper manual endpoint failed");
        end
        request(2, 1, 0, 0);
        @(negedge clk);
        detector_rf = 98000000;
        detector_step = 1086083685;
        detector_locked = 1;
        wait (tuned && dsp_run);
        if (phase_step != detector_step || tuned_rf != detector_rf) begin
            $fatal(1, "Automatic tune recalculated the detector step");
        end
        previous_epoch = epoch;
        previous_config = config_id;
        previous_index = sample_index;
        @(negedge clk);
        detector_rf = 98001000;
        detector_step = 1086182420;
        wait (config_id != previous_config);
        #1;
        if (!dsp_run || epoch != previous_epoch || sample_index <= previous_index || phase_step != detector_step) begin
            $fatal(1, "Small automatic retune reset the stream");
        end
        @(negedge clk);
        iq_valid = 0;
        if (dut.warmup_remaining != 66) begin
            $fatal(1, "Small retune did not restart warmup");
        end
        repeat (65) @(negedge clk);
        if (!flags[12]) begin
            $fatal(1, "Warmup advanced without valid samples");
        end
        check_warmup;
        iq_valid = 1;
        previous_config = config_id;
        @(negedge clk);
        detector_step = 1086182421;
        wait (config_id != previous_config);
        #1;
        if (!dsp_run || epoch != previous_epoch || phase_step != detector_step) begin
            $fatal(1, "Phase-only update was ignored or reset the stream");
        end
        check_response_stall;
        @(negedge clk);
        detector_locked = 0;
        previous_config = config_id;
        previous_index = sample_index;
        repeat (10) @(negedge clk);
        if (!dsp_run || epoch != previous_epoch || config_id != previous_config || sample_index <= previous_index) begin
            $fatal(1, "Detector unlock reset the channel");
        end
        detector_rf = 100000000;
        detector_step = 1283587950;
        detector_locked = 1;
        wait (config_id != previous_config);
        #1;
        if (dsp_run || epoch != previous_epoch+1 || sample_index != 0 || phase_step != detector_step) begin
            $fatal(1, "Large automatic retune did not restart the DSP");
        end
        wait (dsp_run);
        request(7, 0, 0, 0);
        if (running || tuned || dsp_run) begin
            $fatal(1, "STOP failed");
        end
        $display("CONTROL_PASS");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Control timeout");
    end
endmodule
