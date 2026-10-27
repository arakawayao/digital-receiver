# 已完成的 56 MHz 未知 RF 全链路波形，不重新执行仿真。
onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -divider {场景、未知 RF 真值与 ADC 引脚}
add wave -radix unsigned /full_chain_tb/stage /full_chain_tb/session /full_chain_tb/kind
add wave -radix unsigned /full_chain_tb/rf
add wave /full_chain_tb/clk /full_chain_tb/rst_n /full_chain_tb/adc_clk
add wave -radix unsigned /full_chain_tb/adc
add wave /full_chain_tb/pause /full_chain_tb/host_stall
add wave -radix unsigned /full_chain_tb/received /full_chain_tb/credit

add wave -divider {PLL 与流复位}
add wave /full_chain_tb/dut/locked /full_chain_tb/dut/sample_clk /full_chain_tb/dut/usb_clk
add wave /full_chain_tb/dut/usb_reset_n /full_chain_tb/dut/pause_sync
add wave /full_chain_tb/dut/stream_arst_n /full_chain_tb/dut/stream_sample_n /full_chain_tb/dut/stream_usb_n

add wave -divider {FPGA 自动 RF 捕获，不使用上位机配置}
add wave /full_chain_tb/dut/detector/locked /full_chain_tb/dut/detector/update
add wave /full_chain_tb/dut/detector/valid_window
add wave -radix unsigned /full_chain_tb/dut/detector/measured_bins /full_chain_tb/dut/detector/rf_hz
add wave -radix hexadecimal /full_chain_tb/dut/detector/phase_step /full_chain_tb/dut/sample_phase
add wave /full_chain_tb/dut/sample_conjugate
add wave -radix unsigned /full_chain_tb/dut/rf_hz /full_chain_tb/dut/epoch

add wave -divider {采集、NCO 与混频}
add wave -radix decimal /full_chain_tb/dut/dsp/sample
add wave /full_chain_tb/dut/dsp/capture_valid
add wave -radix hexadecimal /full_chain_tb/dut/dsp/mixer/phase
add wave -radix decimal /full_chain_tb/dut/dsp/mi /full_chain_tb/dut/dsp/mq
add wave /full_chain_tb/dut/dsp/mix_valid

add wave -divider {CIC R112、FIR 与 IQ 输出}
add wave -radix unsigned /full_chain_tb/dut/dsp/cic_i/count
add wave -radix decimal /full_chain_tb/dut/dsp/ci /full_chain_tb/dut/dsp/cq
add wave /full_chain_tb/dut/dsp/ci_valid /full_chain_tb/dut/dsp/cq_valid
add wave /full_chain_tb/dut/dsp/fir/busy
add wave -radix unsigned /full_chain_tb/dut/dsp/fir/tap
add wave -radix decimal /full_chain_tb/dut/iq_i /full_chain_tb/dut/iq_q
add wave /full_chain_tb/dut/iq_valid /full_chain_tb/dut/iq_clip /full_chain_tb/dut/dsp_error

add wave -divider {异步 FIFO、序号与丢样}
add wave /full_chain_tb/dut/fifo_full /full_chain_tb/dut/fifo_empty /full_chain_tb/dut/fifo_read
add wave -radix unsigned /full_chain_tb/dut/index /full_chain_tb/dut/dropped
add wave -radix hexadecimal /full_chain_tb/dut/fifo_q

add wave -divider {FCR1 v2、CRC 与 USB 反压}
add wave -radix unsigned /full_chain_tb/dut/packet/state /full_chain_tb/dut/packet/count /full_chain_tb/dut/packet/pos
add wave -radix unsigned /full_chain_tb/dut/packet/sequence_id /full_chain_tb/dut/packet/first_index /full_chain_tb/dut/packet/dropped
add wave -radix hexadecimal /full_chain_tb/dut/packet/crc /full_chain_tb/dut/tx_data
add wave /full_chain_tb/dut/tx_valid /full_chain_tb/dut/tx_ready

add wave -divider {FX2 EP2 IN 总线}
add wave /full_chain_tb/pclk /full_chain_tb/wr /full_chain_tb/rd
add wave /full_chain_tb/pa7 /full_chain_tb/pa6 /full_chain_tb/pa5 /full_chain_tb/pa4 /full_chain_tb/pa2 /full_chain_tb/pa0
add wave -radix hexadecimal /full_chain_tb/dq
add wave /full_chain_tb/flagb
add wave -radix unsigned /full_chain_tb/dut/usb/state
add wave /full_chain_tb/dut/usb/flagb_q /full_chain_tb/dut/led

configure wave -namecolwidth 330
configure wave -valuecolwidth 110
configure wave -timelineunits us
update
wave zoom full
