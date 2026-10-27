create_clock -name reference24 -period 41.666667 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty
# Use the actual PLL USB clock source, not a disconnected reference-clock path.
set fx2_source [get_pins {pll|pll1|clk[1]}]
if {[get_collection_size $fx2_source] != 1} {
    error "Expected one PLL USB clock source"
}
create_generated_clock -name fx2_ifclk -source $fx2_source -divide_by 1 -invert [get_ports usb_pclk]
# Source-board FX2 write timing; zero PCB skew remains an unverified assumption.
set_output_delay -clock fx2_ifclk -max 12.1 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -min -3.6 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -max 3.2 [get_ports {usb_dq[*]}]
set_output_delay -clock fx2_ifclk -min -4.5 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports usb_flagb]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports usb_flagb]
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports usb_pa1] -to [get_registers {*pause_sync[0]}]
# The detector holds RF/phase throughout lock. Two USB synchronizer stages
# qualify capture, followed by 32 startup clocks before packet consumption.
# Limit only this held bundled-data crossing to 20 ns (< one 41.667 ns USB cycle).
set_max_delay 20.0 -from [get_registers {*detector|phase_step[*] *detector|rf_hz[*]}] -to [get_registers {phase_step[*] rf_hz[*]}]
# Intentional first-stage control synchronization; downstream stages stay timed.
set_false_path -from [get_registers {*detector|locked}] -to [get_registers {frequency_sync[0]}]
# Only asynchronous reset assertions into the named reset synchronizers and
# Intel FIFO reset synchronizers. Release is locally synchronized before use.
set reset_sources [get_registers {*detector|locked pause_sync[1] *usb_reset|wait_count[5] *usb_reset|sync[1]}]
set reset_receivers [get_registers {*usb_stream_reset|sync[*] *sample_stream_reset|sync[*] *fifo|*rdaclr|* *fifo|*wraclr|*}]
set_false_path -from $reset_sources -to $reset_receivers
# ADC ports intentionally remain virtual/unconstrained. Datasheet t1/t2 alone
# cannot replace outbound clock delay, return data delay, PCB skew and capture phase.
# No false path is added for ADC payload, FIFO data or internal DSP logic.
