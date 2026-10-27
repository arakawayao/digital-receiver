// Five-stage CIC decimator; R112. Integrator/comb arithmetic wraps mod 2^59.
// The comb removes integrator wrap; output truncates toward -infinity.
// R112 gain=17623416832; 35 growth bits plus signed24 input => 59 bits.
module rx_cic #(parameter R=112, parameter SHIFT=42)(
    input wire clk, input wire rst_n, input wire valid,
    input wire signed [23:0] din, output reg signed [17:0] dout,
    output reg out_valid, output reg clipped);
    reg signed [58:0] integrator [0:4];
    reg signed [58:0] delay [0:4];
    reg signed [58:0] comb [0:4];
    reg [4:0] comb_valid;
    reg [6:0] count;
    integer k_int;
    integer k_comb;

    wire signed [58:0] extended = {{35{din[23]}}, din};
    wire signed [58:0] scaled = comb[4] >>> SHIFT;

    // Five-stage integrator.  The old integrator[4] is sampled every Rth
    // valid input, exactly as in the previously verified single-process RTL.
    always @(posedge clk) begin
        if (!rst_n) begin
            for (k_int=0; k_int<5; k_int=k_int+1)
                integrator[k_int] <= 0;
            comb[0] <= 0;
            delay[0] <= 0;
        end
        else if (valid) begin
            integrator[0] <= integrator[0] + extended;
            for (k_int=1; k_int<5; k_int=k_int+1)
                integrator[k_int] <= integrator[k_int] + integrator[k_int-1];
            if (count == R-1) begin
                comb[0] <= integrator[4] - delay[0];
                delay[0] <= integrator[4];
            end
        end
    end

    // Four remaining comb stages.  comb_valid is read before the valid
    // pipeline updates on the same edge, preserving the verified latency.
    always @(posedge clk) begin
        if (!rst_n) begin
            for (k_comb=1; k_comb<5; k_comb=k_comb+1) begin
                delay[k_comb] <= 0;
                comb[k_comb] <= 0;
            end
        end
        else begin
            for (k_comb=1; k_comb<5; k_comb=k_comb+1) begin
                if (comb_valid[k_comb-1]) begin
                    comb[k_comb] <= comb[k_comb-1] - delay[k_comb];
                    delay[k_comb] <= comb[k_comb-1];
                end
            end
        end
    end

    // Decimation counter and valid pipeline.  out_valid is aligned with the
    // final comb result at the output register.
    always @(posedge clk) begin
        if (!rst_n) begin
            count <= 0;
            comb_valid <= 0;
            out_valid <= 0;
        end
        else begin
            out_valid <= comb_valid[4];
            comb_valid[0] <= valid && count == R-1;
            comb_valid[4:1] <= comb_valid[3:0];
            if (valid) begin
                if (count == R-1)
                    count <= 0;
                else
                    count <= count + 1'b1;
            end
        end
    end

    // Registered scale, signed saturation and clip indication.
    always @(posedge clk) begin
        if (!rst_n) begin
            clipped <= 0;
            dout <= 0;
        end
        else begin
            if (comb_valid[4]) begin
                if (scaled > 131071) begin
                    dout <= 18'sh1ffff;
                    clipped <= 1;
                end
                else if (scaled < -131072) begin
                    dout <= 18'sh20000;
                    clipped <= 1;
                end
                else begin
                    dout <= scaled[17:0];
                    clipped <= 0;
                end
            end
            else begin
                clipped <= 0;
            end
        end
    end
endmodule
