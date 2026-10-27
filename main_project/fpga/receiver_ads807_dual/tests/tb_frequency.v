`timescale 1ns/1ps
module tb_frequency;
    reg clk;
    reg rst_n;
    reg [11:0] adc;
    wire [31:0] step;
    wire [31:0] rf;
    wire locked;
    wire update;
    wire valid_window;
    wire [15:0] measured_count;
    integer scenario;
    integer sample_number;
    integer raw;
    integer expected_rf;
    integer delta;
    integer accepted;
    real frequency;
    real phase;
    real message;
    rx_frequency dut(
        .clk(clk), .rst_n(rst_n), .adc(adc), .phase_step(step),
        .rf_hz(rf), .locked(locked), .update(update),
        .valid_window(valid_window), .measured_bins(measured_count)
    );
    initial begin
        clk = 0;
        forever #11.494253 clk = ~clk;
    end
    initial begin
        rst_n = 0;
        adc = 2048;
        accepted = 0;
        for (scenario = 0; scenario < 9; scenario = scenario+1) begin
            rst_n = 0;
            repeat (4) @(negedge clk);
            rst_n = 1;
            phase = 0.17;
            case (scenario)
                0: expected_rf = 88000000;
                1: expected_rf = 108000000;
                2: expected_rf = 100700000;
                3: expected_rf = 93370000;
                7: expected_rf = 87999000;
                8: expected_rf = 108001000;
                default: expected_rf = 98000000;
            endcase
            for (sample_number = 0; sample_number < 200000; sample_number = sample_number+1) begin
                frequency = expected_rf;
                message = $cos(6.283185307179586*5000.0*sample_number/43500000.0);
                if (scenario == 2) begin
                    frequency = frequency+25000.0*message;
                end
                phase = phase+6.283185307179586*frequency/43500000.0;
                raw = $rtoi(800.0*$cos(phase));
                if (scenario == 3) begin
                    raw = $rtoi(800.0*(1.0+0.5*message)*$cos(phase));
                end
                if (scenario == 4) begin
                    raw = 0;
                end
                if (scenario == 5) begin
                    raw = 2047;
                end
                if (scenario == 6) begin
                    raw = $rtoi(8.0*$cos(phase));
                end
                adc = 2048+raw;
                @(negedge clk);
            end
            if (scenario < 4 || scenario >= 7) begin
                delta = rf-expected_rf;
                if (delta < 0) begin
                    delta = -delta;
                end
                if (!locked || delta > 12000) begin
                    $fatal(1, "Frequency scenario=%0d locked=%0d rf=%0d expected=%0d", scenario, locked, rf, expected_rf);
                end
                if (scenario == 7 && (rf != 88000000 || step != 98734880)) begin
                    $fatal(1, "Lower RF/phase clamp mismatch");
                end
                if (scenario == 8 && (rf != 108000000 || step != 2073432488)) begin
                    $fatal(1, "Upper RF/phase clamp mismatch");
                end
                accepted = accepted+1;
            end else if (locked) begin
                $fatal(1, "Rejected input locked scenario=%0d", scenario);
            end
        end
        $display("FREQUENCY_PASS scenarios=9 accepted=%0d", accepted);
        $finish;
    end
endmodule
