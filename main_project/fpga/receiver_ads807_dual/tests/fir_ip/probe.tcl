package require ::quartus::project
set base [file normalize [file join [file dirname [info script]] ../..]]
set target [file normalize [lindex $quartus(args) 0]]
set mode [lindex $quartus(args) 1]
set generated [file normalize [lindex $quartus(args) 2]]
project_new [file join $target probe] -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name ORIGINAL_QUARTUS_VERSION 18.1.0
set_global_assignment -name VERILOG_INPUT_VERSION VERILOG_2001
set_global_assignment -name OPTIMIZATION_TECHNIQUE AREA
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output
set_global_assignment -name SDC_FILE [file join $base tests/fir_ip/probe.sdc]
if {$mode eq "legacy"} {
    set_global_assignment -name TOP_LEVEL_ENTITY rx_fir
    set_global_assignment -name VERILOG_FILE [file join $base rtl/rx_fir.v]
} else {
    set_global_assignment -name TOP_LEVEL_ENTITY rx_fir_intel_eval
    set_global_assignment -name VERILOG_FILE [file join $base tests/fir_ip/rx_fir_intel_eval.v]
    set_global_assignment -name QIP_FILE [file join $generated synth/rx_fir_intel_core.qip]
}
foreach port {rst_n valid din_i[*] din_q[*] input_clip dout_i[*] dout_q[*] out_valid clipped deadline_error} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
export_assignments
project_close
