// Sole owner of tuning. Quality loss never resets an already tuned channel.
module rx_control #(
    parameter USB_REPLAY = 0
)(
    input wire clk,
    input wire rst_n,
    input wire [159:0] command,
    input wire command_valid,
    output wire command_ready,
    output wire [383:0] response,
    output reg response_valid,
    input wire response_ready,
    input wire detector_locked,
    input wire detector_update,
    input wire [31:0] detector_rf,
    input wire [31:0] detector_phase_step,
    input wire iq_valid,
    output reg [1:0] mode,
    output reg running,
    output wire dsp_run,
    output reg tuned,
    output reg [31:0] tuned_rf,
    output reg [31:0] phase_step,
    output reg [31:0] epoch,
    output reg [31:0] config_id,
    output reg [31:0] sample_index,
    output wire [31:0] flags,
    output wire [31:0] estimated_rf
);
    localparam IDLE = 0;
    localparam APPLY = 1;
    localparam REPLY = 2;
    reg [1:0] state;
    reg [5:0] flush_count;
    reg host_quality;
    reg [31:0] host_estimate;
    reg [15:0] hold_ms;
    reg [15:0] bad_ms;
    reg [15:0] millisecond_tick;
    reg [31:0] pending_rf;
    reg [31:0] pending_phase;
    reg pending_track;
    reg pending_host;
    reg [31:0] reply_sequence;
    reg [31:0] reply_opcode;
    reg [31:0] reply_error;
    reg [31:0] response_index;
    reg [31:0] response_flags;
    reg [31:0] response_estimate;
    reg [6:0] warmup_remaining;
    wire confident;
    wire hold_expired;
    wire [31:0] detector_delta;
    wire [31:0] opcode;
    wire [31:0] argument;
    wire [31:0] requested_rf;
    assign opcode = command[63:32];
    assign argument = command[95:64];
    assign requested_rf = command[127:96];
    assign command_ready = state == IDLE && !response_valid;
    // Commands and automatic retunes are blocked until the ACK is consumed.
    // Reuse their stable configuration registers; snapshot only live status.
    assign response = {16'd0, hold_ms, response_estimate, response_flags, response_index,
        config_id, epoch, phase_step, tuned_rf, 30'd0, mode, reply_error,
        reply_opcode, reply_sequence};
    assign dsp_run = running && tuned && flush_count == 0;
    assign confident = tuned && (mode == 1 ? detector_locked : host_quality);
    assign hold_expired = tuned && !confident && bad_ms >= hold_ms;
    assign estimated_rf = mode == 1 ? (detector_locked ? detector_rf : 32'd0) :
        (host_quality ? host_estimate : 32'd0);
    assign flags = {19'd0, (warmup_remaining != 0), 1'b0,
        hold_expired, confident, tuned, 6'd0, mode};
    assign detector_delta = detector_rf >= tuned_rf ? detector_rf-tuned_rf : tuned_rf-detector_rf;
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            mode <= USB_REPLAY ? USB_REPLAY : 2'd1;
            running <= 1;
            tuned <= 0;
            tuned_rf <= 0;
            phase_step <= 0;
            epoch <= 0;
            config_id <= 0;
            sample_index <= 0;
            flush_count <= 32;
            host_quality <= 0;
            host_estimate <= 0;
            hold_ms <= 500;
            bad_ms <= 0;
            millisecond_tick <= 0;
            pending_rf <= 0;
            pending_phase <= 0;
            pending_track <= 0;
            pending_host <= 0;
            reply_sequence <= 0;
            reply_opcode <= 0;
            reply_error <= 0;
            response_index <= 0;
            response_flags <= 0;
            response_estimate <= 0;
            warmup_remaining <= 66;
            response_valid <= 0;
        end else begin
            if (response_valid && response_ready) begin
                response_valid <= 0;
            end
            if (flush_count != 0) begin
                flush_count <= flush_count - 1'b1;
            end
            if (iq_valid && dsp_run) begin
                sample_index <= sample_index + 1'b1;
                if (warmup_remaining != 0) begin
                    warmup_remaining <= warmup_remaining - 1'b1;
                end
            end
            if (!tuned || confident) begin
                bad_ms <= 0;
                millisecond_tick <= 0;
            end else if (bad_ms != 16'hffff) begin
                if (millisecond_tick == 43499) begin
                    millisecond_tick <= 0;
                    bad_ms <= bad_ms + 1'b1;
                end else begin
                    millisecond_tick <= millisecond_tick + 1'b1;
                end
            end
            case (state)
                IDLE: begin
                    if (command_valid && command_ready) begin
                        reply_sequence <= command[31:0];
                        reply_opcode <= opcode;
                        reply_error <= command[159:128];
                        state <= REPLY;
                        if (command[159:128] == 0) begin
                            case (opcode)
                                1: begin
                                    reply_error <= 0;
                                end
                                2: begin
                                    if ((argument != 1 && argument != 2) ||
                                        (USB_REPLAY && argument != USB_REPLAY)) begin
                                        reply_error <= 4;
                                    end else begin
                                        mode <= USB_REPLAY ? USB_REPLAY : argument[1:0];
                                        running <= 1;
                                        tuned <= 0;
                                        host_quality <= 0;
                                        host_estimate <= 0;
                                        epoch <= epoch + 1'b1;
                                        sample_index <= 0;
                                        flush_count <= 32;
                                        warmup_remaining <= 66;
                                    end
                                end
                                3: begin
                                    if (requested_rf < 88000000 || requested_rf > 108000000 ||
                                        argument < 32'd98734880 || argument > 32'd2073432488) begin
                                        reply_error <= 4;
                                    end else if (!running || mode != 2) begin
                                        reply_error <= 5;
                                    end else begin
                                        pending_rf <= requested_rf;
                                        pending_phase <= argument;
                                        pending_track <= 0;
                                        pending_host <= 1;
                                        state <= APPLY;
                                    end
                                end
                                5: begin
                                    if (mode == 1 || !tuned) begin
                                        reply_error <= 5;
                                    end else if (argument > 1 || (argument == 1 &&
                                                 (requested_rf < 87000000 || requested_rf > 108750000))) begin
                                        reply_error <= 4;
                                    end else begin
                                        host_quality <= argument[0];
                                        host_estimate <= argument[0] ? requested_rf : 32'd0;
                                    end
                                end
                                7: begin
                                    running <= 0;
                                    tuned <= 0;
                                    host_quality <= 0;
                                    epoch <= epoch + 1'b1;
                                    sample_index <= 0;
                                    flush_count <= 32;
                                    warmup_remaining <= 66;
                                end
                                8: begin
                                    if (argument == 0 || argument > 60000) begin
                                        reply_error <= 4;
                                    end else begin
                                        hold_ms <= argument[15:0];
                                    end
                                end
                                9: begin
                                    if (!USB_REPLAY) begin
                                        reply_error <= 3;
                                    end else if (argument[31:24] != 0 || requested_rf > 4095) begin
                                        reply_error <= 4;
                                    end else if (tuned || running) begin
                                        reply_error <= 5;
                                    end
                                end
                                default: begin
                                    reply_error <= 3;
                                end
                            endcase
                        end
                    end else if (!response_valid && running && mode == 1 && detector_locked &&
                                 (!tuned || detector_rf != tuned_rf || detector_phase_step != phase_step)) begin
                        pending_rf <= detector_rf;
                        pending_phase <= detector_phase_step;
                        pending_track <= tuned && detector_delta <= 5000;
                        pending_host <= 0;
                        state <= APPLY;
                    end
                end
                APPLY: begin
                    phase_step <= pending_phase;
                    tuned_rf <= pending_rf;
                    tuned <= 1;
                    config_id <= config_id + 1'b1;
                    host_quality <= 0;
                    host_estimate <= 0;
                    bad_ms <= 0;
                    millisecond_tick <= 0;
                    warmup_remaining <= 66;
                    if (!pending_track) begin
                        epoch <= epoch + 1'b1;
                        sample_index <= 0;
                        flush_count <= 32;
                    end
                    state <= pending_host ? REPLY : IDLE;
                end
                REPLY: begin
                    response_index <= sample_index;
                    response_flags <= flags;
                    response_estimate <= estimated_rf;
                    response_valid <= 1;
                    state <= IDLE;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
