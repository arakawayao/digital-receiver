// 256 phase positions, 12-bit signed amplitude, quarter-wave lookup.
// Self-contained synthesizable constants; no mem file or vendor DDS IP.
module nco_lut12 (
    input wire [7:0] address,
    output wire signed [11:0] value
);
    wire [6:0] index = address[6] ?
        (7'd64 - {1'b0,address[5:0]}) : {1'b0,address[5:0]};
    reg [11:0] magnitude;
    assign value = address[7] ? -$signed(magnitude) : $signed(magnitude);
    always @* begin
        case (index)
            7'd0: magnitude = 12'd0;
            7'd1: magnitude = 12'd50;
            7'd2: magnitude = 12'd100;
            7'd3: magnitude = 12'd151;
            7'd4: magnitude = 12'd201;
            7'd5: magnitude = 12'd251;
            7'd6: magnitude = 12'd300;
            7'd7: magnitude = 12'd350;
            7'd8: magnitude = 12'd399;
            7'd9: magnitude = 12'd449;
            7'd10: magnitude = 12'd497;
            7'd11: magnitude = 12'd546;
            7'd12: magnitude = 12'd594;
            7'd13: magnitude = 12'd642;
            7'd14: magnitude = 12'd690;
            7'd15: magnitude = 12'd737;
            7'd16: magnitude = 12'd783;
            7'd17: magnitude = 12'd830;
            7'd18: magnitude = 12'd875;
            7'd19: magnitude = 12'd920;
            7'd20: magnitude = 12'd965;
            7'd21: magnitude = 12'd1009;
            7'd22: magnitude = 12'd1052;
            7'd23: magnitude = 12'd1095;
            7'd24: magnitude = 12'd1137;
            7'd25: magnitude = 12'd1179;
            7'd26: magnitude = 12'd1219;
            7'd27: magnitude = 12'd1259;
            7'd28: magnitude = 12'd1299;
            7'd29: magnitude = 12'd1337;
            7'd30: magnitude = 12'd1375;
            7'd31: magnitude = 12'd1411;
            7'd32: magnitude = 12'd1447;
            7'd33: magnitude = 12'd1483;
            7'd34: magnitude = 12'd1517;
            7'd35: magnitude = 12'd1550;
            7'd36: magnitude = 12'd1582;
            7'd37: magnitude = 12'd1614;
            7'd38: magnitude = 12'd1644;
            7'd39: magnitude = 12'd1674;
            7'd40: magnitude = 12'd1702;
            7'd41: magnitude = 12'd1729;
            7'd42: magnitude = 12'd1756;
            7'd43: magnitude = 12'd1781;
            7'd44: magnitude = 12'd1805;
            7'd45: magnitude = 12'd1828;
            7'd46: magnitude = 12'd1850;
            7'd47: magnitude = 12'd1871;
            7'd48: magnitude = 12'd1891;
            7'd49: magnitude = 12'd1910;
            7'd50: magnitude = 12'd1927;
            7'd51: magnitude = 12'd1944;
            7'd52: magnitude = 12'd1959;
            7'd53: magnitude = 12'd1973;
            7'd54: magnitude = 12'd1986;
            7'd55: magnitude = 12'd1997;
            7'd56: magnitude = 12'd2008;
            7'd57: magnitude = 12'd2017;
            7'd58: magnitude = 12'd2025;
            7'd59: magnitude = 12'd2032;
            7'd60: magnitude = 12'd2037;
            7'd61: magnitude = 12'd2041;
            7'd62: magnitude = 12'd2045;
            7'd63: magnitude = 12'd2046;
            7'd64: magnitude = 12'd2047;
            default: magnitude = 12'd0;
        endcase
    end
endmodule
