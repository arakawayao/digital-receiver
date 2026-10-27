// Fixed ADS807E receiver. ADC pins are virtual until wiring/timing is confirmed.
module receiver_top #(
    parameter ADC_RATE = 43500000,
    parameter OFFSET_BINARY = 1
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
    wire locked;
    wire sample_clk;
    wire usb_clk;
    wire usb_reset_n;
    wire sample_reset_n;
    wire stream_usb_n;
    wire stream_sample_n;
    wire stream_arst_n;
    wire [11:0] detector_adc;
    wire [31:0] sample_phase;
    wire [31:0] detected_rf;
    wire frequency_locked;
    wire frequency_update;
    wire valid_window;
    wire [15:0] measured_bins;
    wire [7:0] tx_data;
    wire tx_valid;
    wire tx_ready;
    wire signed [15:0] iq_i;
    wire signed [15:0] iq_q;
    wire iq_valid;
    wire iq_clip;
    wire dsp_error;
    wire fifo_full;
    wire fifo_empty;
    wire [96:0] fifo_q;
    wire fifo_read;
    reg [11:0] adc_registered;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] pause_sync;
    (* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
    reg [1:0] frequency_sync;
    reg [31:0] rf_hz;
    reg [31:0] phase_step;
    reg [31:0] epoch;
    reg previous_stream;
    reg [31:0] index;
    reg [31:0] dropped;
    assign sample_clk = clocks[0];
    assign usb_clk = clocks[1];
    assign adc_clk = sample_clk;
    assign detector_adc = OFFSET_BINARY ? adc_registered : adc_registered ^ 12'h800;
    assign stream_arst_n = usb_reset_n && !pause_sync[1] && frequency_locked;
    assign led = locked && frequency_locked && !dsp_error;
    rx_pll_ads807 pll(
        .inclk({1'b0, clk}), .areset(!rst_n), .clk(clocks), .locked(locked)
    );
    rx_reset usb_reset(
        .clk(usb_clk), .arst_n(rst_n && locked), .rst_n(usb_reset_n)
    );
    rx_reset sample_reset(
        .clk(sample_clk), .arst_n(rst_n && locked), .rst_n(sample_reset_n)
    );
    // This register captures every ADC clock, independently of stream lock/pause.
    always @(posedge sample_clk) begin
        adc_registered <= adc_data;
    end
    always @(posedge usb_clk or negedge usb_reset_n) begin
        if (!usb_reset_n) begin
            pause_sync <= 2'b11;
        end else begin
            pause_sync <= {pause_sync[0], usb_pa1};
        end
    end
    rx_frequency detector(
        .clk(sample_clk), .rst_n(sample_reset_n), .adc(detector_adc),
        .phase_step(sample_phase), .rf_hz(detected_rf), .locked(frequency_locked),
        .update(frequency_update), .valid_window(valid_window), .measured_bins(measured_bins)
    );
    rx_reset usb_stream_reset(
        .clk(usb_clk), .arst_n(stream_arst_n), .rst_n(stream_usb_n)
    );
    rx_reset sample_stream_reset(
        .clk(sample_clk), .arst_n(stream_arst_n), .rst_n(stream_sample_n)
    );
    // Detector metadata is held during lock; stream release waits 32 USB clocks.
    always @(posedge usb_clk or negedge usb_reset_n) begin
        if (!usb_reset_n) begin
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
    always @(posedge sample_clk) begin
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
    rx_dsp #(.ADC_RATE(ADC_RATE), .OFFSET_BINARY(OFFSET_BINARY)) dsp(
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
    rx_packet #(.ADC_RATE(ADC_RATE)) packet(
        .clk(usb_clk), .rst_n(stream_usb_n), .fifo_q(fifo_q), .fifo_empty(fifo_empty),
        .fifo_read(fifo_read), .rf_hz(rf_hz), .phase_step(phase_step), .epoch(epoch),
        .conjugate(1'b0), .byte_data(tx_data), .byte_valid(tx_valid), .byte_ready(tx_ready)
    );
    rx_fx2 usb(
        .clk(usb_clk), .rst_n(usb_reset_n), .pause(pause_sync[1]),
        .flagb(usb_flagb), .dq(usb_dq), .ifclk(usb_pclk), .slcs_n(usb_pa7),
        .slrd_n(usb_rd), .slwr_n(usb_wr), .sloe_n(usb_pa2), .a0(usb_pa4),
        .a1(usb_pa5), .pktend_n(usb_pa6), .pa0(usb_pa0),
        .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready)
    );
    // synthesis translate_off
	 
    initial begin
        if (ADC_RATE != 43500000) begin
            $fatal(1, "ADS807 PLL and DSP require ADC_RATE=43500000");
        end
    end
    // synthesis translate_on
endmodule
