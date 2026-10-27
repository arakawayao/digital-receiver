# Isolated synchronous benchmark, not board I/O timing constraints.
create_clock -name clk -period 22.988506 [get_ports clk]
derive_clock_uncertainty
set_input_delay -clock clk -max 0 [get_ports {rst_n valid din_i[*] din_q[*] input_clip}]
set_input_delay -clock clk -min 0 [get_ports {rst_n valid din_i[*] din_q[*] input_clip}]
set_output_delay -clock clk -max 0 [get_ports {dout_i[*] dout_q[*] out_valid clipped deadline_error}]
set_output_delay -clock clk -min 0 [get_ports {dout_i[*] dout_q[*] out_valid clipped deadline_error}]
