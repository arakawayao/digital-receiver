# The existing command mailbox holds parser.command until destination consumption ACK.
# RAM data/address/write decoding consume that same held payload after the two-stage
# request synchronization, exactly like rx_control. Bound this added endpoint to
# 20 ns (< one 43.5 MHz destination cycle); do not cut unrelated clock-domain paths.
set_max_delay 20.0 -from [get_registers {*parser|command[*]}] -to [get_registers {*replay_source.source|*}]
