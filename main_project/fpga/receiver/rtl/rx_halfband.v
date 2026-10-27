// Seven-tap FIR /2, h=[-1,0,9,16,9,0,-1]/32. No multipliers or CIC.
// Input/output signed18, three arithmetic pipeline registers, valid bubbles supported.
module rx_halfband(
    input wire clk, rst_n, valid,
    input wire signed [17:0] din_i, din_q,
    input wire input_clip,
    output reg signed [17:0] dout_i, dout_q,
    output reg out_valid, clipped);
    reg signed [17:0] hi [0:5], hq [0:5];
    reg [5:0] hc;
    reg phase, pair_valid, sum_valid, pair_clip, sum_clip;
    reg signed [18:0] ai,bi,aq,bq;
    reg signed [17:0] mi,mq;
    reg signed [23:0] sum_i,sum_q;
    wire signed [23:0] ea_i={{5{ai[18]}},ai}, eb_i={{5{bi[18]}},bi};
    wire signed [23:0] ea_q={{5{aq[18]}},aq}, eb_q={{5{bq[18]}},bq};
    wire signed [23:0] em_i={{6{mi[17]}},mi}, em_q={{6{mq[17]}},mq};
    wire signed [23:0] rounded_i=(sum_i+24'sd16) >>> 5;
    wire signed [23:0] rounded_q=(sum_q+24'sd16) >>> 5;
    function [17:0] sat18;
        input signed [23:0] x;
        begin
            if(x>131071) sat18=18'sh1ffff;
            else if(x< -131072) sat18=18'sh20000;
            else sat18=x[17:0];
        end
    endfunction
    integer k;
    always @(posedge clk) begin
        if(!rst_n) begin
            for(k=0;k<6;k=k+1) begin hi[k]<=0; hq[k]<=0; end
            hc<=0; phase<=0; pair_valid<=0; sum_valid<=0;
            pair_clip<=0; sum_clip<=0; ai<=0; bi<=0; aq<=0; bq<=0;
            mi<=0; mq<=0; sum_i<=0; sum_q<=0;
            dout_i<=0; dout_q<=0; out_valid<=0; clipped<=0;
        end else begin
            pair_valid<=valid && phase;
            sum_valid<=pair_valid;
            out_valid<=sum_valid; clipped<=0;
            if(valid) begin
                hi[0]<=din_i; hq[0]<=din_q; hc<={hc[4:0],input_clip};
                for(k=1;k<6;k=k+1) begin hi[k]<=hi[k-1]; hq[k]<=hq[k-1]; end
                phase<=!phase;
                if(phase) begin
                    ai<=$signed({din_i[17],din_i})+$signed({hi[5][17],hi[5]});
                    bi<=$signed({hi[1][17],hi[1]})+$signed({hi[3][17],hi[3]});
                    aq<=$signed({din_q[17],din_q})+$signed({hq[5][17],hq[5]});
                    bq<=$signed({hq[1][17],hq[1]})+$signed({hq[3][17],hq[3]});
                    mi<=hi[2]; mq<=hq[2]; pair_clip<=input_clip || (|hc);
                end
            end
            if(pair_valid) begin
                sum_i<=-ea_i+(eb_i <<< 3)+eb_i+(em_i <<< 4);
                sum_q<=-ea_q+(eb_q <<< 3)+eb_q+(em_q <<< 4);
                sum_clip<=pair_clip;
            end
            if(sum_valid) begin
                dout_i<=sat18(rounded_i); dout_q<=sat18(rounded_q);
                clipped<=sum_clip || rounded_i>131071 || rounded_i< -131072 ||
                                      rounded_q>131071 || rounded_q< -131072;
            end
        end
    end
endmodule
