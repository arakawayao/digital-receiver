// ADS807 ADC/DSP from receiver_ads807; automatic and manual tuning share one controller.
module receiver_top #(
    parameter USB_REPLAY = 0
)(
    input wire clk,
    input wire rst_n,
    input wire [11:0] adc_data,
    output wire adc_clk,
    inout wire [7:0] usb_dq,
    input wire usb_flagb,
    input wire usb_flagc,
    input wire usb_pa1,
    output wire usb_pclk,
    output wire usb_wr,
    output wire usb_rd,
    output wire usb_pa7,
    output wire usb_pa6,
    output wire usb_pa5,
    output wire usb_pa4,
    output wire usb_pa2,
    output wire usb_pa0,
    output wire led
);
    wire [4:0] clocks;
    wire pll_locked;
    wire sample_clk;
    wire usb_clk;
    wire sample_rst_n;
    wire usb_rst_n;
    wire dsp_run;
    wire tuned;
    wire running;
    wire [1:0] mode;
    wire [31:0] tuned_rf;
    wire [31:0] phase_step;
    wire [31:0] epoch;
    wire [31:0] config_id;
    wire [31:0] sample_index;
    wire [31:0] flags;
    wire [31:0] estimate;
    wire detector_locked;
    wire detector_update;
    wire [31:0] detector_rf;
    wire [31:0] detector_step;
    wire valid_window;
    wire [15:0] measured_bins;
    wire [159:0] usb_command;
    wire usb_command_valid;
    wire usb_command_ready;
    wire [159:0] sample_command;
    wire sample_command_valid;
    wire sample_command_ready;
    wire [383:0] sample_response;
    wire sample_response_valid;
    wire sample_response_ready;
    wire [383:0] usb_response;
    wire usb_response_valid;
    wire usb_response_ready;
    wire signed [15:0] iq_i;
    wire signed [15:0] iq_q;
    wire iq_valid;
    wire iq_clip;
    wire dsp_error;
    wire [287:0] fifo_q;
    wire fifo_empty;
    wire fifo_full;
    wire fifo_read;
    wire [31:0] sample_flags;
    wire [7:0] tx_data;
    wire tx_valid;
    wire tx_ready;
    wire usb_tx_ready;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_ready;
    reg [11:0] adc_registered;
    wire [11:0] replay_adc;
    wire replay_loaded;
    wire replay_write;
    reg [31:0] dropped;
    reg [31:0] previous_epoch;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] pause_sync;
    // adc_otr is reserved for hardware overrange monitoring; protocol clip flags remain DSP-derived.
    assign sample_clk = clocks[0];
    assign usb_clk = clocks[1];
    assign adc_clk = sample_clk;
    assign replay_write = USB_REPLAY && sample_command_valid && sample_command_ready &&
        sample_command[159:128] == 0 && sample_command[63:32] == 9 &&
        sample_command[95:88] == 0 && sample_command[127:108] == 0 && !tuned && !running;
    generate
        if (USB_REPLAY) begin : replay_source
            rx_sample_replay source(
                .clk(sample_clk), .rst_n(sample_rst_n), .write_enable(replay_write),
                .write_address(sample_command[107:96]), .write_data(sample_command[87:64]),
                .adc_data(replay_adc), .loaded(replay_loaded)
            );
        end else begin : physical_source
            assign replay_adc = adc_data;
            assign replay_loaded = 1'b1;
        end
    endgenerate

    assign tx_ready = usb_tx_ready && !pause_sync[1];
    assign led = pll_locked && tuned && flags[9] && !dsp_error;
    assign sample_flags = flags | (iq_clip ? 32'h800 : 32'd0) |
        (dropped != 0 ? 32'h2000 : 32'd0);
    rx_pll_ads807 pll(
        .inclk({1'b0, clk}), .areset(!rst_n), .clk(clocks), .locked(pll_locked)
    );
    rx_reset sample_reset(
        .clk(sample_clk), .arst_n(rst_n && pll_locked), .rst_n(sample_rst_n)
    );
    rx_reset usb_reset(
        .clk(usb_clk), .arst_n(rst_n && pll_locked), .rst_n(usb_rst_n)
    );
    always @(posedge sample_clk) begin
        adc_registered <= replay_adc;
        if (!sample_rst_n || epoch != previous_epoch) begin
            dropped <= 0;
        end else if (iq_valid && dsp_run && fifo_full && dropped != 32'hffffffff) begin
            dropped <= dropped + 1'b1;
        end
        previous_epoch <= epoch;
    end
    always @(posedge usb_clk or negedge usb_rst_n) begin
        if (!usb_rst_n) begin
            pause_sync <= 2'b11;
        end else begin
            pause_sync <= {pause_sync[0], usb_pa1};
        end
    end
    rx_frequency detector(
        // STOP clears detector history; the next MODE starts a fresh RF window.
        .clk(sample_clk), .rst_n(sample_rst_n && replay_loaded && running), .adc(adc_registered),
        .phase_step(detector_step), .rf_hz(detector_rf), .locked(detector_locked),
        .update(detector_update), .valid_window(valid_window), .measured_bins(measured_bins)
    );
    rx_command parser(
        .clk(usb_clk), .rst_n(usb_rst_n), .rx_data(rx_data), .rx_valid(rx_valid),
        .rx_ready(rx_ready), .command(usb_command), .command_valid(usb_command_valid),
        .command_ready(usb_command_ready)
    );
    rx_mailbox #(.WIDTH(160)) command_mailbox(
        .src_clk(usb_clk), .src_rst_n(usb_rst_n), .src_data(usb_command),
        .src_valid(usb_command_valid), .src_ready(usb_command_ready),
        .dst_clk(sample_clk), .dst_rst_n(sample_rst_n), .dst_data(sample_command),
        .dst_valid(sample_command_valid), .dst_ready(sample_command_ready)
    );
    rx_control #(.USB_REPLAY(USB_REPLAY)) control(
        .clk(sample_clk), .rst_n(sample_rst_n), .command(sample_command),
        .command_valid(sample_command_valid), .command_ready(sample_command_ready),
        .response(sample_response), .response_valid(sample_response_valid),
        .response_ready(sample_response_ready), .detector_locked(detector_locked),
        .detector_update(detector_update), .detector_rf(detector_rf),
        .detector_phase_step(detector_step), .iq_valid(iq_valid),
        .mode(mode), .running(running),
        .dsp_run(dsp_run), .tuned(tuned), .tuned_rf(tuned_rf), .phase_step(phase_step),
        .epoch(epoch), .config_id(config_id), .sample_index(sample_index),
        .flags(flags), .estimated_rf(estimate)
    );
    rx_mailbox #(.WIDTH(384)) response_mailbox(
        .src_clk(sample_clk), .src_rst_n(sample_rst_n), .src_data(sample_response),
        .src_valid(sample_response_valid), .src_ready(sample_response_ready),
        .dst_clk(usb_clk), .dst_rst_n(usb_rst_n), .dst_data(usb_response),
        .dst_valid(usb_response_valid), .dst_ready(usb_response_ready)
    );
    rx_dsp dsp(
        .clk(sample_clk), .rst_n(dsp_run), .enable(1'b1), .adc(adc_registered),
        .phase_step(phase_step), .conjugate(1'b0), .i_out(iq_i), .q_out(iq_q),
        .valid(iq_valid), .clipped(iq_clip), .deadline_error(dsp_error)
    );
    rx_fifo_tri #(.ADDRESS_BITS(USB_REPLAY ? 8 : 9)) fifo(
        .aclr(!rst_n || !pll_locked),
        .data({estimate, config_id, sample_flags, phase_step, tuned_rf, epoch,
            dropped, sample_index, iq_q, iq_i}),
        .wrclk(sample_clk), .wrreq(dsp_run && iq_valid && !fifo_full),
        .wrfull(fifo_full), .rdclk(usb_clk), .rdreq(fifo_read),
        .rdempty(fifo_empty), .q(fifo_q)
    );
    rx_tri_packet packet(
        .clk(usb_clk), .rst_n(usb_rst_n), .fifo_q(fifo_q), .fifo_empty(fifo_empty),
        .fifo_read(fifo_read), .response(usb_response), .response_valid(usb_response_valid),
        .response_ready(usb_response_ready),
        .byte_data(tx_data), .byte_valid(tx_valid), .byte_ready(tx_ready)
    );
    rx_fx2_tri usb(
        .clk(usb_clk), .rst_n(usb_rst_n), .flagb(usb_flagb), .flagc(usb_flagc),
        .dq(usb_dq), .ifclk(usb_pclk), .slcs_n(usb_pa7), .slrd_n(usb_rd),
        .slwr_n(usb_wr), .sloe_n(usb_pa2), .a0(usb_pa4), .a1(usb_pa5),
        .pktend_n(usb_pa6), .pa0(usb_pa0), .tx_data(tx_data),
        .tx_valid(tx_valid && !pause_sync[1]), .tx_ready(usb_tx_ready),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(rx_ready)
    );
endmodule
