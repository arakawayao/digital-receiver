create_clock -name reference24 -period 41.666667 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty
create_generated_clock -name fx2_ifclk -source [get_pins {pll|pll1|clk[1]}] -divide_by 1 -invert [get_ports usb_pclk]
# Source-board FX2 synchronous FIFO tSUD/tHD and control requirements. PCB skew pending.
set_output_delay -clock fx2_ifclk -max 12.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -min -3.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -max 3.2 [get_ports {usb_dq[*]}]
set_output_delay -clock fx2_ifclk -min -4.5 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports {usb_flagb usb_flagc}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_flagb usb_flagc}]
# FX2 tXFD max 15 ns. DQ is continuously captured in input registers; RX_READY
# consumes a registered head enabled several cycles earlier.
# The following read strobe consumes that captured head; output-enable is settled first.
set_input_delay -clock fx2_ifclk -max 15.0 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_dq[*]}]
set_false_path -from [get_ports rst_n]
# Two-flop toggle synchronizers: only first stage is asynchronous.
set_false_path -to [get_registers {*request_sync[0] *acknowledge_sync[0]}]
set_false_path -from [get_ports usb_pa1] -to [get_registers {*pause_sync[0]}]
# Held payloads are captured after two synchronized toggle stages; bounded to < one destination cycle.
# No broad clock-group exception; actual dual-clock RAM/FIFO paths remain visible.
# ADC data, OTR and clock have user-specified physical locations.
# ADC I/O delays and capture phase require actual clock/data PCB timing; not signed off.
# Held payloads remain stable until consumption ACK; valid crosses two stages.
set_max_delay 20.0 -from [get_registers {*parser|command[*]}] -to [get_registers {*control|*}]
# Quartus aliases shared RF storage as response and mode storage as flags[1:0].
set_max_delay 35.0 -from [get_registers {
    *control|response[*]
    *control|flags[0]
    *control|flags[1]
    *control|reply_sequence[*]
    *control|reply_opcode[*]
    *control|reply_error[*]
    *control|response_index[*]
    *control|response_flags[*]
    *control|response_estimate[*]
    *control|phase_step[*]
    *control|epoch[*]
    *control|config_id[*]
    *control|hold_ms[*]
}] -to [get_registers {*packet|*}]
