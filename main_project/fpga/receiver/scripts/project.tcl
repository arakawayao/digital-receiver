# quartus_sh -t scripts/project.tcl 56 (fixed 56 MHz ADC)
package require ::quartus::project
set rate [lindex $quartus(args) 0]
if {$rate eq ""} {set rate 56}
if {$rate ne "56"} {error "ADC sampling rate is fixed at 56 MHz"}
set name receiver$rate
project_new $name -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name TOP_LEVEL_ENTITY receiver_top
set_parameter -name ADC_RATE ${rate}000000
set_parameter -name OFFSET_BINARY 1
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_$rate
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
set_global_assignment -name RESERVE_ALL_UNUSED_PINS "AS INPUT TRI-STATED"
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
# Explicit active 56 MHz receive-only sources. Historical projects/configuration
# examples under legacy_32_40 are never picked up by a directory glob.
foreach file {
    rtl/receiver_top.v rtl/rx_reset.v rtl/rx_capture.v rtl/rx_frequency.v
    rtl/rx_nco.v rtl/rx_cic.v rtl/rx_fir.v rtl/rx_dsp.v
    rtl/rx_packet.v rtl/rx_fx2.v
} {
    if {![file exists $file]} {error "Missing active RTL source: $file"}
    set_global_assignment -name VERILOG_FILE $file
}
set_global_assignment -name VERILOG_FILE ip/rx_pll${rate}.v
set_global_assignment -name VERILOG_FILE ip/rx_fifo.v
set_global_assignment -name VERILOG_FILE ip/rx_ifclk.v
set_global_assignment -name SDC_FILE receiver.sdc
source board_pins.tcl
# ADC pin mapping is absent from core-board documents: prevent guessed pin placement.
foreach port {adc_data[0] adc_data[1] adc_data[2] adc_data[3] adc_data[4] adc_data[5] adc_data[6] adc_data[7] adc_data[8] adc_data[9] adc_data[10] adc_data[11] adc_clk} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
export_assignments
project_close
