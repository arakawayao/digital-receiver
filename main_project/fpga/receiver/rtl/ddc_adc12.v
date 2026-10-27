// Real ADC -> cos/-sin mixers -> third-order CIC decimator.
// iq_valid is a clock enable. adc_valid must not discard physical ADC samples.
module ddc_adc12 #(
    parameter integer ADC_OFFSET_BINARY = 1,
    parameter integer DECIM_LOG2 = 9
)(
    input wire clk, rst_n, clear,
    input wire [11:0] adc_data,
    input wire adc_valid,
    input wire [31:0] nco_fcw,
    output reg signed [15:0] iq_i, iq_q,
    output reg iq_valid
);
    localparam integer GAIN_BITS = 3*DECIM_LOG2;
    localparam integer CW = 13 + GAIN_BITS + 1;
    wire signed [11:0] adc_signed = ADC_OFFSET_BINARY ?
        $signed({~adc_data[11],adc_data[10:0]}) : $signed(adc_data);
    reg [31:0] phase;
    wire [7:0] cos_address = phase[31:24] + 8'd64;
    wire signed [11:0] lut_sin, lut_cos;
    nco_lut12 u_sin (.address(phase[31:24]), .value(lut_sin));
    nco_lut12 u_cos (.address(cos_address), .value(lut_cos));
    reg signed [11:0] adc_r, sin_r, cos_r;
    reg lut_valid, mix_valid;
    reg signed [23:0] mix_i, mix_q;
    wire signed [CW-1:0] x_i = $signed(mix_i) >>> 11;
    wire signed [CW-1:0] x_q = $signed(mix_q) >>> 11;
    reg signed [CW-1:0] int_i1,int_i2,int_i3,int_q1,int_q2,int_q3;
    reg [DECIM_LOG2-1:0] decim_count;
    reg signed [CW-1:0] dec_i,dec_q;
    reg dec_valid;
    reg signed [CW-1:0] delay_i1,delay_i2,delay_i3;
    reg signed [CW-1:0] delay_q1,delay_q2,delay_q3;
    reg signed [CW-1:0] comb_i1,comb_i2,comb_q1,comb_q2;
    reg comb_valid1,comb_valid2;
    wire signed [CW-1:0] comb_i3 = comb_i2 - delay_i3;
    wire signed [CW-1:0] comb_q3 = comb_q2 - delay_q3;
    wire signed [CW-1:0] normalized_i = $signed(comb_i3) >>> GAIN_BITS;
    wire signed [CW-1:0] normalized_q = $signed(comb_q3) >>> GAIN_BITS;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase<=0; adc_r<=0; sin_r<=0; cos_r<=0;
            lut_valid<=0; mix_valid<=0; mix_i<=0; mix_q<=0;
            int_i1<=0; int_i2<=0; int_i3<=0; int_q1<=0; int_q2<=0; int_q3<=0;
            decim_count<=0; dec_i<=0; dec_q<=0; dec_valid<=0;
            delay_i1<=0; delay_i2<=0; delay_i3<=0;
            delay_q1<=0; delay_q2<=0; delay_q3<=0;
            comb_i1<=0; comb_i2<=0; comb_q1<=0; comb_q2<=0;
            comb_valid1<=0; comb_valid2<=0; iq_i<=0; iq_q<=0; iq_valid<=0;
        end else if (clear) begin
            // Flush all old-frequency data and valid pipeline stages.
            phase<=0; adc_r<=0; sin_r<=0; cos_r<=0;
            lut_valid<=0; mix_valid<=0; mix_i<=0; mix_q<=0;
            int_i1<=0; int_i2<=0; int_i3<=0; int_q1<=0; int_q2<=0; int_q3<=0;
            decim_count<=0; dec_i<=0; dec_q<=0; dec_valid<=0;
            delay_i1<=0; delay_i2<=0; delay_i3<=0;
            delay_q1<=0; delay_q2<=0; delay_q3<=0;
            comb_i1<=0; comb_i2<=0; comb_q1<=0; comb_q2<=0;
            comb_valid1<=0; comb_valid2<=0; iq_i<=0; iq_q<=0; iq_valid<=0;
        end else begin
            lut_valid <= adc_valid;
            if (adc_valid) begin
                phase <= phase + nco_fcw;
                adc_r<=adc_signed; sin_r<=lut_sin; cos_r<=lut_cos;
            end
            mix_valid <= lut_valid;
            if (lut_valid) begin
                mix_i <= adc_r * cos_r;
                mix_q <= -(adc_r * sin_r);
            end
            dec_valid <= 0;
            if (mix_valid) begin
                // Modular fixed-width integrator wrap is intentional for CIC.
                int_i1<=int_i1+x_i; int_i2<=int_i2+int_i1; int_i3<=int_i3+int_i2;
                int_q1<=int_q1+x_q; int_q2<=int_q2+int_q1; int_q3<=int_q3+int_q2;
                decim_count <= decim_count + 1'b1;
                if (&decim_count) begin
                    dec_i<=int_i3; dec_q<=int_q3; dec_valid<=1;
                end
            end
            comb_valid1 <= dec_valid;
            if (dec_valid) begin
                comb_i1<=dec_i-delay_i1; delay_i1<=dec_i;
                comb_q1<=dec_q-delay_q1; delay_q1<=dec_q;
            end
            comb_valid2 <= comb_valid1;
            if (comb_valid1) begin
                comb_i2<=comb_i1-delay_i2; delay_i2<=comb_i1;
                comb_q2<=comb_q1-delay_q2; delay_q2<=comb_q1;
            end
            iq_valid <= comb_valid2;
            if (comb_valid2) begin
                // Divide by R^3; IQ units remain approximately ADC codes.
                iq_i <= normalized_i[15:0]; delay_i3<=comb_i2;
                iq_q <= normalized_q[15:0]; delay_q3<=comb_q2;
            end
        end
    end
    // synthesis translate_off
    initial begin
        if (DECIM_LOG2 < 1 || DECIM_LOG2 > 16) begin
            $display("ERROR: DECIM_LOG2 must be 1..16."); $finish;
        end
    end
    // synthesis translate_on
endmodule
