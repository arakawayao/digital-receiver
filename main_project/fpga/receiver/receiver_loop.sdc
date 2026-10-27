# Board oscillator: FCore2S schematic U3, 24 MHz. PLL frequencies derive from IP.
create_clock -name reference24 -period 41.666667 [get_ports clk]
derive_pll_clocks
derive_clock_uncertainty
# FX2 IFCLK forwarded as inverted 24 MHz, same PLL reference and 1:1 output.
set fx2_source [get_pins -hierarchical {*|pll1|clk[1]}]
if {[get_collection_size $fx2_source]!=1} {error "Expected one PLL USB clock source"}
create_generated_clock -name fx2_ifclk -source $fx2_source -divide_by 1 -invert [get_ports usb_pclk]
# CY7C68013A local datasheet external IFCLK: conservative SLRD/SLWR setup12.7/hold3.7,
# DATA setup3.2/hold4.5, FLAGS max13.5. Zero board-skew model: NOT board sign-off.
set_output_delay -clock fx2_ifclk -max 12.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -min -3.7 [get_ports {usb_wr usb_rd usb_pa2 usb_pa4 usb_pa5 usb_pa6 usb_pa7}]
set_output_delay -clock fx2_ifclk -max 3.2 [get_ports {usb_dq[*]}]
set_output_delay -clock fx2_ifclk -min -4.5 [get_ports {usb_dq[*]}]
# Fixed FLAGB reports EP2 IN writable capacity.
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports {usb_flagb}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_flagb}]
# Fixed FLAGC reports EP6 OUT nonempty. Read data tXFD max15 ns.
set_input_delay -clock fx2_ifclk -max 13.5 [get_ports {usb_flagc}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_flagc}]
set_input_delay -clock fx2_ifclk -max 15.0 [get_ports {usb_dq[*]}]
set_input_delay -clock fx2_ifclk -min 0.0 [get_ports {usb_dq[*]}]
# Reset switch and firmware PA1 are asynchronous inputs. Cut only their first
# synchronization/assertion paths, not payload or unrelated clock domains.
set_false_path -from [get_ports rst_n]
# No external ADC ports exist in the replay build; PA1 is unused.
