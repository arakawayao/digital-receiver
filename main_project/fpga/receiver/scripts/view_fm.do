# 读取已有全链路 WLF，突出显示 FM 的最终基带 I/Q。
# 默认 88 MHz FM 稳定区；108 MHz 可执行 wave zoom range 11900us 12700us。
# 不清除原有 Wave 信号，不重新运行仿真。
quietly WaveActivateNextPane {} 0
add wave -position 0 -divider {FM final I/Q - signed16, 500 ksample/s}
add wave -position 1 -label {FM I (iq_i)} -radix decimal -format analog-step -height 110 -min -3500 -max 3500 -color cyan /full_chain_tb/dut/iq_i
add wave -position 2 -label {FM Q (iq_q)} -radix decimal -format analog-step -height 110 -min -3500 -max 3500 -color yellow /full_chain_tb/dut/iq_q
add wave -position 3 -label iq_valid /full_chain_tb/dut/iq_valid
add wave -position 4 -label {input stage (1=FM88, 2=FM108)} -radix unsigned /full_chain_tb/stage
add wave -position 5 -label {RF truth Hz} -radix unsigned /full_chain_tb/rf
add wave -position 6 -label {FPGA frequency locked} /full_chain_tb/dut/detector/locked
add wave -position 7 -label {DSP released} /full_chain_tb/dut/stream_sample_n
add wave -position 8 -label epoch -radix unsigned /full_chain_tb/dut/epoch
configure wave -namecolwidth 330
configure wave -valuecolwidth 110
configure wave -timelineunits us
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {7500 us} 0}
update
wave zoom range 7200us 8000us
