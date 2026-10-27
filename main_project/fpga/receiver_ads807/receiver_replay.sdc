create_clock -name reference24 -period 41.666667 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty
set fx2_source [get_pins {pll|pll1|clk[1]}]
if {[get_collection_size $fx2_source] != 1} {error "Expected one PLL USB clock source"}
create_generated_clock -name fx2_ifclk -source $fx2_source -divide_by 1 -invert [get_ports usb_pclk]
# CY7C68013A external IFCLK; no measured board skew is available.
set_output_delay -clock fx2_ifclk -max 12.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -min -3.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -max 3.2 [get_ports {usb_dq[*]}]
set_output_delay -clock fx2_ifclk -min -4.5 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports {usb_flagb usb_flagc}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_flagb usb_flagc}]
set_input_delay -clock fx2_ifclk -max 15.0 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_dq[*]}]
set_false_path -from [get_ports rst_n]
# PA1 is deliberately unused; only RPL1 START/STOP controls replay.
# Length is set while stopped, held through RUN synchronization and playback.
set_max_delay 20.0 -from [get_registers {*replay|length[*]}] -to [get_registers {*replay|sample_length[*]}]
set_max_delay 20.0 -from [get_registers {*detector|phase_step[*] *detector|rf_hz[*]}] -to [get_registers {phase_step[*] rf_hz[*]}]
# Only first-stage asynchronous control capture; payload and later stages stay timed.
set_false_path -from [get_registers {*replay|run_usb}] -to [get_registers {*replay|run_sync[0]}]
set_false_path -from [get_registers {*replay|active}] -to [get_registers {*replay|active_sync[0]}]
set_false_path -from [get_registers {*detector|locked}] -to [get_registers {frequency_sync[0]}]
# Intentional asynchronous assertion into stream/FIFO reset synchronizers.
set reset_sources [get_registers {*detector|locked *replay|active *usb_reset|wait_count[5] *usb_reset|sync[1]}]
set reset_receivers [get_registers {*usb_stream_reset|sync[*] *sample_stream_reset|sync[*] *fifo|*rdaclr|* *fifo|*wraclr|*}]
set_false_path -from $reset_sources -to $reset_receivers
