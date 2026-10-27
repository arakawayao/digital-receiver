`timescale 1ns/1ps
module tb_fir_ip;
    reg clk;
    reg rst_n;
    reg valid;
    reg signed [17:0] din_i;
    reg signed [17:0] din_q;
    reg input_clip;
    reg sink_valid;
    reg signed [17:0] sink_data;
    reg sink_sop;
    reg sink_eop;
    wire signed [41:0] raw;
    wire raw_valid;
    wire raw_sop;
    wire raw_eop;
    wire raw_channel;
    wire [1:0] raw_error;
    wire signed [15:0] legacy_i;
    wire signed [15:0] legacy_q;
    wire legacy_valid;
    wire legacy_clip;
    wire legacy_error;
    wire signed [15:0] ip_i;
    wire signed [15:0] ip_q;
    wire ip_valid;
    wire ip_clip;
    wire ip_error;
    integer source;
    integer results;
    integer scanned;
    integer cycle;
    integer reset_value;
    integer valid_value;
    integer i_value;
    integer q_value;
    integer clip_value;
    integer stream_valid;
    integer stream_data;
    integer stream_sop;
    integer stream_eop;

    rx_fir_intel_core core (
        .clk(clk),
        .reset_n(rst_n),
        .ast_sink_data(sink_data),
        .ast_sink_valid(sink_valid),
        .ast_sink_sop(sink_sop),
        .ast_sink_eop(sink_eop),
        .ast_sink_error(2'b00),
        .ast_source_data(raw),
        .ast_source_valid(raw_valid),
        .ast_source_sop(raw_sop),
        .ast_source_eop(raw_eop),
        .ast_source_channel(raw_channel),
        .ast_source_error(raw_error)
    );
    rx_fir legacy (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .din_i(din_i),
        .din_q(din_q),
        .input_clip(input_clip),
        .dout_i(legacy_i),
        .dout_q(legacy_q),
        .out_valid(legacy_valid),
        .clipped(legacy_clip),
        .deadline_error(legacy_error)
    );
    rx_fir_intel_eval candidate (
        .clk(clk),
        .rst_n(rst_n),
        .valid(valid),
        .din_i(din_i),
        .din_q(din_q),
        .input_clip(input_clip),
        .dout_i(ip_i),
        .dout_q(ip_q),
        .out_valid(ip_valid),
        .clipped(ip_clip),
        .deadline_error(ip_error)
    );

    initial begin
        clk = 0;
        forever #11.494253 clk = ~clk;
    end
    initial begin
        rst_n = 0;
        valid = 0;
        din_i = 0;
        din_q = 0;
        input_clip = 0;
        sink_valid = 0;
        sink_data = 0;
        sink_sop = 0;
        sink_eop = 0;
        cycle = 0;
        source = $fopen("inputs.txt", "r");
        results = $fopen("probe.txt", "w");
        if (!source || !results) begin
            $fatal(1, "Cannot open FIR vectors/results");
        end
        while (!$feof(source)) begin
            scanned = $fscanf(source, "%d %d %d %d %d %d %d %d %d\n",
                reset_value, valid_value, i_value, q_value, clip_value,
                stream_valid, stream_data, stream_sop, stream_eop);
            if (scanned != 9) begin
                $fatal(1, "Malformed FIR vector");
            end
            @(negedge clk);
            rst_n = reset_value;
            valid = valid_value;
            din_i = i_value;
            din_q = q_value;
            input_clip = clip_value;
            sink_valid = stream_valid;
            sink_data = stream_data;
            sink_sop = stream_sop;
            sink_eop = stream_eop;
            @(posedge clk);
            #1;
            if (raw_valid) begin
                $fwrite(results, "R %0d %0d %0d %0d %0d %0d\n",
                    cycle, raw_channel, raw_sop, raw_eop, raw_error, raw);
            end
            if (legacy_valid) begin
                $fwrite(results, "L %0d %0d %0d %0d\n",
                    cycle, legacy_i, legacy_q, legacy_clip);
            end
            if (ip_valid) begin
                $fwrite(results, "P %0d %0d %0d %0d\n",
                    cycle, ip_i, ip_q, ip_clip);
            end
            if (rst_n && ip_error) begin
                $fatal(1, "FIR II adapter error at cycle %0d", cycle);
            end
            if (rst_n && legacy_error) begin
                $fatal(1, "Legacy deadline error at cycle %0d", cycle);
            end
            cycle = cycle + 1;
        end
        $fclose(source);
        $fclose(results);
        $display("FIR_PROBE_PASS");
        $finish;
    end
endmodule
