# Source: FCore2S hardware schematic E6 sheets 2/4 and 08_USB_FIFO_WR ZIP QSF.
# VCCIO and CY7C68013A supply are 3.3 V in the board schematic.
# PA1 is an INPUT: Bulkloop firmware OEA bit1=1, not the unconnected output in demo RTL.
foreach {port pin} {
    clk M16 rst_n M12 led L12
    usb_dq[0] C16 usb_dq[1] F13 usb_dq[2] J11 usb_dq[3] F14
    usb_dq[4] K11 usb_dq[5] G11 usb_dq[6] J14 usb_dq[7] L11
    usb_flagb D16 usb_flagc F15 usb_pclk B16 usb_rd N12 usb_wr K12
    usb_pa7 K15 usb_pa6 K16 usb_pa5 J15 usb_pa4 J16
    usb_pa2 G16 usb_pa1 G15 usb_pa0 F16
} {
    set_location_assignment PIN_$pin -to $port
    set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to $port
}
