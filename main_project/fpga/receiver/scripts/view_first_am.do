# 突出显示第一次 98 MHz AM 的混频包络；只读取既有 WLF。
quietly WaveActivateNextPane {} 0
add wave -position 0 -divider {First AM raw mixer products}
add wave -position 1 -label {mi (signed24)} -radix decimal -format analog-step -height 110 -min -2600000 -max 2600000 -color cyan /full_chain_tb/dut/dsp/mi
add wave -position 2 -label {mq (signed24)} -radix decimal -format analog-step -height 110 -min -2600000 -max 2600000 -color yellow /full_chain_tb/dut/dsp/mq
add wave -position 3 -label mix_valid /full_chain_tb/dut/dsp/mix_valid
add wave -position 4 -divider {Filtered AM baseband}
add wave -position 5 -label {I (iq_i)} -radix decimal -format analog-step -height 90 -min -5500 -max 5500 -color cyan /full_chain_tb/dut/iq_i
add wave -position 6 -label {Q (iq_q)} -radix decimal -format analog-step -height 90 -min -5500 -max 5500 -color yellow /full_chain_tb/dut/iq_q
add wave -position 7 -label iq_valid /full_chain_tb/dut/iq_valid
add wave -position 8 -label {stage (0=first AM)} -radix unsigned /full_chain_tb/stage
add wave -position 9 -label {RF truth Hz} -radix unsigned /full_chain_tb/rf
add wave -position 10 -label locked /full_chain_tb/dut/detector/locked
configure wave -namecolwidth 300
configure wave -valuecolwidth 110
configure wave -timelineunits us
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2700 us} 0}
update
wave zoom range 2600us 2800us
