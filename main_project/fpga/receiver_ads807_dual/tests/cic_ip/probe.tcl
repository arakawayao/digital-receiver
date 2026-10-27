package require ::quartus::project
set base [file normalize [file join [file dirname [info script]] ../..]]
set target [file normalize [lindex $quartus(args) 0]]
project_new [file join $target probe] -overwrite
set_global_assignment -name FAMILY "Cyclone IV E"
set_global_assignment -name DEVICE EP4CE6F17C8
set_global_assignment -name TOP_LEVEL_ENTITY cic_ip_probe
set_global_assignment -name OPTIMIZATION_TECHNIQUE AREA
set_global_assignment -name NUM_PARALLEL_PROCESSORS 2
set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output
set_global_assignment -name VERILOG_FILE [file join $base tests/cic_ip/cic_ip_probe.v]
set_global_assignment -name QIP_FILE [file join $target synth/rx_cic_intel_core.qip]
if {[file tail $target] eq "pruned"} {
    set_parameter -name OUT_WIDTH 20
}
foreach port {clk rst_n valid din[*] dout[*] out_valid ready} {
    set_instance_assignment -name VIRTUAL_PIN ON -to $port
}
export_assignments
project_close
