// No ADC needed: EP6 OUT upload -> cyclic ADC replay -> real DDC -> EP2 IN.
module receiver_loop_top(
    input wire clk,rst_n,inout wire [7:0] usb_dq,
    input wire usb_flagb,usb_flagc,usb_pa1,
    output wire usb_pclk,usb_wr,usb_rd,usb_pa7,usb_pa6,usb_pa5,usb_pa4,usb_pa2,usb_pa0,
    output wire led);
    receiver_top #(.USB_REPLAY(1)) core(.clk(clk),.rst_n(rst_n),.adc_data(8'd128),.adc_clk(),
        .usb_dq(usb_dq),.usb_flagb(usb_flagb),.usb_flagc(usb_flagc),.usb_pa1(usb_pa1),
        .usb_pclk(usb_pclk),.usb_wr(usb_wr),.usb_rd(usb_rd),.usb_pa7(usb_pa7),.usb_pa6(usb_pa6),
        .usb_pa5(usb_pa5),.usb_pa4(usb_pa4),.usb_pa2(usb_pa2),.usb_pa0(usb_pa0),.led(led));
endmodule
