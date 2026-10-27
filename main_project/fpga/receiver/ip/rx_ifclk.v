//altddio_out CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="Cyclone IV E" WIDTH=1 datain_h datain_l dataout outclock outclocken
//VERSION_BEGIN 18.1 cbx_altddio_out 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_maxii 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_stratixiii 2018:09:12:13:04:24:SJ cbx_stratixv 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END
// synthesis VERILOG_INPUT_VERSION VERILOG_2001
// altera message_off 10463



// Copyright (C) 2018  Intel Corporation. All rights reserved.
//  Your use of Intel Corporation's design tools, logic functions 
//  and other software and tools, and its AMPP partner logic 
//  functions, and any output files from any of the foregoing 
//  (including device programming or simulation files), and any 
//  associated documentation or information are expressly subject 
//  to the terms and conditions of the Intel Program License 
//  Subscription Agreement, the Intel Quartus Prime License Agreement,
//  the Intel FPGA IP License Agreement, or other applicable license
//  agreement, including, without limitation, that your use is for
//  the sole purpose of programming logic devices manufactured by
//  Intel and sold by Intel or its authorized distributors.  Please
//  refer to the applicable agreement for further details.



//synthesis_resources = IO 1 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"ANALYZE_METASTABILITY=OFF;ADV_NETLIST_OPT_ALLOWED=DEFAULT"} *)
module  rx_ifclk
	( 
	datain_h,
	datain_l,
	dataout,
	outclock,
	outclocken) /* synthesis synthesis_clearbox=1 */;
	input   [0:0]  datain_h;
	input   [0:0]  datain_l;
	output   [0:0]  dataout;
	input   outclock;
	input   outclocken;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1   outclocken;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]   wire_ddio_outa_dataout;

	cycloneive_ddio_out   ddio_outa_0
	( 
	.clkhi(outclock),
	.clklo(outclock),
	.datainhi(datain_h),
	.datainlo(datain_l),
	.dataout(wire_ddio_outa_dataout[0:0]),
	.ena(outclocken),
	.muxsel(outclock)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.areset(1'b0),
	.clk(1'b0),
	.sreset(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1),
	.dffhi(),
	.dfflo()
	// synopsys translate_on
	);
	defparam
		ddio_outa_0.async_mode = "none",
		ddio_outa_0.power_up = "low",
		ddio_outa_0.sync_mode = "none",
		ddio_outa_0.use_new_clocking_model = "true",
		ddio_outa_0.lpm_type = "cycloneive_ddio_out";
	assign
		dataout = wire_ddio_outa_dataout;
endmodule //rx_ifclk
//VALID FILE
