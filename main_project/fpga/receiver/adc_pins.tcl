# ACM2108: eight ADC data wires connected to FPGA (two unused); FPGA-provided 32 MHz encode clock.
# 管脚填 PIN_加管脚号，例："PIN_A1"（仅格式示例，不是推荐接线）。
# adc_io_standard 填 ADC 数字接口及 FPGA Bank 支持的电平标准。
# 管脚或电平未填时，保持虚拟引脚；两者填好后自动启用物理引脚。
set adc_io_standard "3.3-V LVTTL"

array set adc_pin_map {
    adc_data[0]    "PIN_E10"
    adc_data[1]    "PIN_D11"
    adc_data[2]    "PIN_B6"
    adc_data[3]    "PIN_B7"
    adc_data[4]    "PIN_D8"
    adc_data[5]    "PIN_A9"
    adc_data[6]    "PIN_A10"
    adc_data[7]    "PIN_A11"
    adc_clk        "PIN_D9"
}

# 以下代码无需修改。
foreach adc_port [array names adc_pin_map] {
    set adc_pin [string trim $adc_pin_map($adc_port)]
    if {$adc_pin eq "" || [string trim $adc_io_standard] eq ""} {
        set_instance_assignment -name VIRTUAL_PIN ON -to $adc_port
    } else {
        if {![regexp {^PIN_[A-Za-z]+[0-9]+$} $adc_pin]} {
            error "Invalid ADC pin for $adc_port: use PIN_A1 format"
        }
        set_instance_assignment -name VIRTUAL_PIN OFF -to $adc_port
        set_location_assignment $adc_pin -to $adc_port
        set_instance_assignment -name IO_STANDARD $adc_io_standard -to $adc_port
    }
}
