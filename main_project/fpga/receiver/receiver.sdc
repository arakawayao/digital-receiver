# Board oscillator: FCore2S schematic U3, 24 MHz. PLL frequencies derive from IP.
create_clock -name reference24 -period 41.666667 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty
# FX2 IFCLK forwarded as inverted 24 MHz, same PLL reference and 1:1 output.
set fx2_source [get_pins -hierarchical {pll1|clk[1]}]
if {[get_collection_size $fx2_source]!=1} {error "Expected one PLL USB clock source"}
create_generated_clock -name fx2_ifclk -source $fx2_source -divide_by 1 -invert [get_ports usb_pclk]
# CY7C68013A local datasheet page46 external IFCLK: SLWR setup12.1/hold3.6,
# DATA setup3.2/hold4.5, FLAGS max13.5. Zero board-skew model: NOT board sign-off.
set_output_delay -clock fx2_ifclk -max 12.1 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -min -3.6 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -max 3.2 [get_ports {usb_dq[*]}]
set_output_delay -clock fx2_ifclk -min -4.5 [get_ports {usb_dq[*]}]
# EP2 write-only transport: FLAGB reports writable capacity. FLAGC and the
# FX2-to-FPGA data direction are unused; no EP6 capture or multicycle path exists.
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports {usb_flagb}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_flagb}]
# Reset switch and firmware PA1 are asynchronous inputs. Cut only their first
# synchronization/assertion paths, not payload or unrelated clock domains.
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports usb_pa1] -to [get_registers {*pause_sync[0]}]
# External ADC pins are VIRTUAL and intentionally lack board capture delays.
# No ADC false path or invented setup/hold numbers are used to hide this gap.
