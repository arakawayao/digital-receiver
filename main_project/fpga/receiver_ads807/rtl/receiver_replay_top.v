// USB ADC-code replay for the EP4CE6 board; no external ADC pins are driven.
module receiver_replay_top(
    input wire clk,
    input wire rst_n,
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
    wire [11:0] source_adc;
    wire source_active;
    wire [31:0] sample_phase;
    wire [31:0] detected_rf;
    wire frequency_locked;
    wire frequency_update;
    wire valid_window;
    wire [15:0] measured_bins;
    wire stream_arst_n;
    wire stream_usb_n;
    wire stream_sample_n;
    wire signed [15:0] iq_i;
    wire signed [15:0] iq_q;
    wire iq_valid;
    wire iq_clip;
    wire dsp_error;
    wire [96:0] fifo_q;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_read;
    wire [7:0] packet_data;
    wire packet_valid;
    wire packet_ready;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_ready;
    wire [7:0] ack_data;
    wire ack_valid;
    wire ack_ready;
    wire tx_ready;
    wire padding;
    reg [11:0] adc_registered;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] frequency_sync;
    reg [31:0] rf_hz;
    reg [31:0] phase_step;
    reg [31:0] epoch;
    reg previous_stream;
    reg [31:0] index;
    reg [31:0] dropped;
    reg [8:0] tx_position;

    assign sample_clk = clocks[0];
    assign usb_clk = clocks[1];
    assign stream_arst_n = usb_rst_n && source_active && frequency_locked;
    assign led = pll_locked && frequency_locked && source_active && !dsp_error;
    assign packet_ready = tx_ready && !ack_valid;
    assign ack_ready = tx_ready;
    assign padding = tx_position != 0 && !stream_usb_n && !ack_valid;

    rx_pll_ads807 pll(
        .inclk({1'b0, clk}), .areset(!rst_n), .clk(clocks), .locked(pll_locked)
    );
    rx_reset sample_reset(
        .clk(sample_clk), .arst_n(rst_n && pll_locked), .rst_n(sample_rst_n)
    );
    rx_reset usb_reset(
        .clk(usb_clk), .arst_n(rst_n && pll_locked), .rst_n(usb_rst_n)
    );
    rx_usb_replay replay(
        .usb_clk(usb_clk), .sample_clk(sample_clk), .usb_rst_n(usb_rst_n),
        .sample_rst_n(sample_rst_n), .rx_data(rx_data), .rx_valid(rx_valid),
        .rx_ready(rx_ready), .ack_data(ack_data), .ack_valid(ack_valid),
        .ack_ready(ack_ready), .adc_data(source_adc), .active(source_active)
    );
    always @(posedge sample_clk) begin
        adc_registered <= source_adc;
        if (!stream_sample_n) begin
            index <= 0;
            dropped <= 0;
        end else if (iq_valid) begin
            index <= index + 1'b1;
            if (fifo_full && dropped != 32'hffffffff) begin
                dropped <= dropped + 1'b1;
            end
        end
    end
    rx_frequency detector(
        .clk(sample_clk), .rst_n(sample_rst_n && source_active), .adc(adc_registered),
        .phase_step(sample_phase), .rf_hz(detected_rf), .locked(frequency_locked),
        .update(frequency_update), .valid_window(valid_window), .measured_bins(measured_bins)
    );
    rx_reset usb_stream_reset(
        .clk(usb_clk), .arst_n(stream_arst_n), .rst_n(stream_usb_n)
    );
    rx_reset sample_stream_reset(
        .clk(sample_clk), .arst_n(stream_arst_n), .rst_n(stream_sample_n)
    );
    // Detector metadata is held during lock; stream reset adds 32 settling clocks.
    always @(posedge usb_clk or negedge usb_rst_n) begin
        if (!usb_rst_n) begin
            frequency_sync <= 0;
            rf_hz <= 0;
            phase_step <= 0;
            epoch <= 0;
            previous_stream <= 0;
        end else begin
            frequency_sync <= {frequency_sync[0], frequency_locked};
            if (frequency_sync[1]) begin
                rf_hz <= detected_rf;
                phase_step <= sample_phase;
            end
            previous_stream <= stream_usb_n;
            if (stream_usb_n && !previous_stream) begin
                epoch <= epoch + 1'b1;
            end
        end
    end
    rx_dsp dsp(
        .clk(sample_clk), .rst_n(stream_sample_n), .enable(1'b1), .adc(adc_registered),
        .phase_step(sample_phase), .conjugate(1'b0), .i_out(iq_i), .q_out(iq_q),
        .valid(iq_valid), .clipped(iq_clip), .deadline_error(dsp_error)
    );
    rx_fifo fifo(
        .aclr(!stream_arst_n), .data({iq_clip, dropped, index, iq_q, iq_i}),
        .wrclk(sample_clk), .wrreq(stream_sample_n && iq_valid && !fifo_full),
        .wrfull(fifo_full), .rdclk(usb_clk), .rdreq(fifo_read),
        .rdempty(fifo_empty), .q(fifo_q)
    );
    rx_packet packet(
        .clk(usb_clk), .rst_n(stream_usb_n), .fifo_q(fifo_q), .fifo_empty(fifo_empty),
        .fifo_read(fifo_read), .rf_hz(rf_hz), .phase_step(phase_step), .epoch(epoch),
        .conjugate(1'b0), .byte_data(packet_data), .byte_valid(packet_valid),
        .byte_ready(packet_ready)
    );
    // Commands enter only between complete IN frames. STOP pads a partial frame.
    always @(posedge usb_clk) begin
        if (!usb_rst_n) begin
            tx_position <= 0;
        end else if (tx_ready && (ack_valid || packet_valid || padding)) begin
            tx_position <= tx_position + 1'b1;
        end
    end
    rx_fx2_duplex usb(
        .clk(usb_clk), .rst_n(usb_rst_n), .flagb(usb_flagb), .flagc(usb_flagc),
        .dq(usb_dq), .ifclk(usb_pclk), .slcs_n(usb_pa7), .slrd_n(usb_rd),
        .slwr_n(usb_wr), .sloe_n(usb_pa2), .a0(usb_pa4), .a1(usb_pa5),
        .pktend_n(usb_pa6), .pa0(usb_pa0),
        .tx_data(ack_valid ? ack_data : (padding ? 8'd0 : packet_data)),
        .tx_valid(ack_valid || packet_valid || padding), .tx_ready(tx_ready),
        .rx_data(rx_data), .rx_valid(rx_valid), .rx_ready(rx_ready && tx_position == 0)
    );
endmodule
