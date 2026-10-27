package require ::quartus::project
package require ::quartus::sta
set name [lindex $quartus(args) 0]
project_open $name
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file ${name}_clocks.rpt
report_timing -setup -npaths 20 -detail full_path -file ${name}_setup.rpt
report_timing -hold -npaths 20 -detail full_path -file ${name}_hold.rpt
report_ucp -file ${name}_unconstrained.rpt
check_timing -file ${name}_check_timing.rpt
set corner 0
foreach_in_collection op [get_available_operating_conditions] {
    incr corner
    set_operating_conditions $op
    update_timing_netlist
    foreach check {setup hold recovery removal} {
        report_timing -$check -npaths 20 -detail full_path -file ${name}_corner${corner}_${check}.rpt
    }
}
delete_timing_netlist
project_close
