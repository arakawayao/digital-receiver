`timescale 1ns/1ps
// Actual estimator/controller, continuous AM across STOP/MODE and RF changes.
module tb_am_restart;
    reg clk;
    reg rst_n;
    reg [11:0] adc;
    reg [159:0] command;
    reg command_valid;
    wire command_ready;
    wire [383:0] response;
    wire response_valid;
    wire detector_locked;
    wire detector_update;
    wire [31:0] detector_rf;
    wire [31:0] detector_phase;
    wire running;
    wire dsp_run;
    wire tuned;
    wire [31:0] tuned_rf;
    wire [31:0] epoch;
    wire [31:0] config_id;
    reg [31:0] request_sequence;
    reg [31:0] random_state;
    integer carrier;
    integer input_mode;
    integer raw;
    integer random_value;
    integer case_index;
    integer level_index;
    integer frequency_index;
    integer wait_count;
    integer error_hz;
    integer checks;
    real phase;
    real message_phase;
    real amplitude;
    real modulation_depth;

    rx_frequency detector(
        .clk(clk), .rst_n(rst_n && running), .adc(adc), .phase_step(detector_phase),
        .rf_hz(detector_rf), .locked(detector_locked), .update(detector_update),
        .valid_window(), .measured_bins()
    );
    rx_control control(
        .clk(clk), .rst_n(rst_n), .command(command), .command_valid(command_valid),
        .command_ready(command_ready), .response(response), .response_valid(response_valid),
        .response_ready(1'b1), .detector_locked(detector_locked), .detector_update(detector_update),
        .detector_rf(detector_rf), .detector_phase_step(detector_phase), .iq_valid(1'b0),
        .mode(), .running(running), .dsp_run(dsp_run), .tuned(tuned), .tuned_rf(tuned_rf),
        .phase_step(), .epoch(epoch), .config_id(config_id), .sample_index(),
        .flags(), .estimated_rf()
    );

    initial begin
        clk = 0;
        forever #11.494253 clk = ~clk;
    end
    always @(negedge clk) begin
        phase = phase+6.283185307179586*(carrier-87000000.0)/43500000.0;
        message_phase = message_phase+6.283185307179586*500.0/43500000.0;
        random_state = {random_state[30:0], random_state[31]^random_state[21]^random_state[1]^random_state[0]};
        random_value = random_state[11:0]-2048;
        case (input_mode)
            0: raw = $rtoi(amplitude*(1.0+modulation_depth*$cos(message_phase))*$cos(phase));
            1: raw = 0;
            2: raw = $rtoi(8.0*$cos(phase));
            3: raw = $rtoi(2400.0*$cos(phase));
            4: raw = random_value/16;
            default: raw = 0;
        endcase
        if (raw > 2047) begin
            raw = 2047;
        end
        if (raw < -2048) begin
            raw = -2048;
        end
        adc = 2048+raw;
    end

    task request;
        input [31:0] opcode;
        input [31:0] argument;
        begin
            @(negedge clk);
            wait_count = 0;
            while (!command_ready && wait_count < 100) begin
                @(negedge clk);
                wait_count = wait_count+1;
            end
            if (!command_ready) begin
                $fatal(1, "Command readiness timeout");
            end
            request_sequence = request_sequence+1;
            command = {32'd0, 32'd0, argument, opcode, request_sequence};
            command_valid = 1;
            @(negedge clk);
            command_valid = 0;
            wait_count = 0;
            while (!response_valid && wait_count < 100) begin
                @(negedge clk);
                wait_count = wait_count+1;
            end
            if (!response_valid || response[31:0] != request_sequence ||
                response[63:32] != opcode || response[95:64] != 0) begin
                $fatal(1, "Missing or inconsistent command response");
            end
            @(negedge clk);
        end
    endtask

    initial begin
        rst_n = 0;
        adc = 2048;
        command = 0;
        command_valid = 0;
        request_sequence = 0;
        random_state = 32'h1b807ace;
        carrier = 98000000;
        input_mode = 0;
        amplitude = 400;
        modulation_depth = 0.5;
        phase = 0.17;
        message_phase = 0;
        checks = 0;
        repeat (4) @(negedge clk);
        rst_n = 1;
        // No reset or CW burst between these starts; AM stays enabled.
        for (level_index = 0; level_index < 3; level_index = level_index+1) begin
            case (level_index)
                0: amplitude = 80;
                1: amplitude = 400;
                2: amplitude = 800;
            endcase
            // Keep AM on through all retunes, including the reported 98 MHz.
            for (frequency_index = 0; frequency_index < 3; frequency_index = frequency_index+1) begin
                request(7, 0);
                if (running || tuned || dsp_run) begin
                    $fatal(1, "STOP did not disable DSP");
                end
                case (frequency_index)
                    0: carrier = 98000000;
                    1: carrier = 103700000;
                    2: carrier = 99500000;
                    default: carrier = 98000000;
                endcase
                repeat (128) @(negedge clk);
                request(2, 1);
                request(8, 500);
                repeat (393216) @(negedge clk);
                error_hz = tuned_rf-carrier;
                if (error_hz < 0) begin
                    error_hz = -error_hz;
                end
                if (!running || !detector_locked || !tuned || !dsp_run || error_hz > 2000) begin
                    $fatal(1, "AM restart failed: RF=%0d level=%0.0f tuned=%0d locked=%0d enabled=%0d measured=%0d",
                        carrier, amplitude, tuned, detector_locked, dsp_run, tuned_rf);
                end
                checks = checks+1;
                $display("AM_RESTART RF=%0d depth=0.5 level=%0.0f measured=%0d epoch=%0d config=%0d",
                    carrier, amplitude, tuned_rf, epoch, config_id);
            end
        end
        // Qualifying windows must still reject absent, weak, clipped and noise inputs.
        for (case_index = 1; case_index <= 4; case_index = case_index+1) begin
            request(7, 0);
            input_mode = case_index;
            repeat (393216) @(negedge clk);
            request(2, 1);
            repeat (393216) @(negedge clk);
            if (detector_locked || tuned || dsp_run) begin
                $fatal(1, "Rejected input acquired: case=%0d", case_index);
            end
            checks = checks+1;
            $display("AM_REJECT case=%0d", case_index);
        end
        $display("AM_RESTART_PASS checks=%0d", checks);
        $finish;
    end
    initial begin
        #300000000;
        $fatal(1, "AM restart test timeout");
    end
endmodule
