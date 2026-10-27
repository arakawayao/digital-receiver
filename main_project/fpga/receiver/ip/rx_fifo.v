//dcfifo_mixed_widths CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="Cyclone IV E" LPM_NUMWORDS=512 LPM_SHOWAHEAD="ON" LPM_WIDTH=97 LPM_WIDTH_R=97 LPM_WIDTHU=9 LPM_WIDTHU_R=9 OVERFLOW_CHECKING="ON" RDSYNC_DELAYPIPE=4 READ_ACLR_SYNCH="ON" UNDERFLOW_CHECKING="ON" USE_EAB="ON" WRITE_ACLR_SYNCH="ON" WRSYNC_DELAYPIPE=4 aclr data q rdclk rdempty rdreq wrclk wrfull wrreq ALTERA_INTERNAL_OPTIONS=AUTO_SHIFT_REGISTER_RECOGNITION=OFF
//VERSION_BEGIN 18.1 cbx_a_gray2bin 2018:09:12:13:04:24:SJ cbx_a_graycounter 2018:09:12:13:04:24:SJ cbx_altdpram 2018:09:12:13:04:24:SJ cbx_altera_counter 2018:09:12:13:04:24:SJ cbx_altera_gray_counter 2018:09:12:13:04:24:SJ cbx_altera_syncram 2018:09:12:13:04:24:SJ cbx_altera_syncram_nd_impl 2018:09:12:13:04:24:SJ cbx_altsyncram 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_dcfifo 2018:09:12:13:04:24:SJ cbx_fifo_common 2018:09:12:13:04:24:SJ cbx_lpm_add_sub 2018:09:12:13:04:24:SJ cbx_lpm_compare 2018:09:12:13:04:24:SJ cbx_lpm_counter 2018:09:12:13:04:24:SJ cbx_lpm_decode 2018:09:12:13:04:24:SJ cbx_lpm_mux 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_nadder 2018:09:12:13:04:24:SJ cbx_scfifo 2018:09:12:13:04:24:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_stratixiii 2018:09:12:13:04:24:SJ cbx_stratixv 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END
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




//a_graycounter CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="Cyclone IV E" PVALUE=1 WIDTH=10 aclr clock cnt_en q
//VERSION_BEGIN 18.1 cbx_a_gray2bin 2018:09:12:13:04:24:SJ cbx_a_graycounter 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = reg 14 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"{-to counter5a[0]} POWER_UP_LEVEL=HIGH"} *)
module  rx_fifo_a_graycounter_gs9
	( 
	aclr,
	clock,
	cnt_en,
	q) /* synthesis synthesis_clearbox=1 */;
	input   aclr;
	input   clock;
	input   cnt_en;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   aclr;
	tri1   cnt_en;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[9:0]	counter5a;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=HIGH"} *)
	reg	parity6;
	reg	[2:0]	sub_parity7a;
	wire  [9:0]  cntr_cout;
	wire  parity_cout;
	wire sclr;
	wire updown;

	// synopsys translate_off
	initial
		counter5a[0:0] = {1{1'b1}};
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[0:0] <= {1{1'b1}};
		else
			if (sclr == 1'b1) counter5a[0:0] <= 1'b0;
			else  counter5a[0:0] <= ((cnt_en & (counter5a[0:0] ^ (~ parity_cout))) | ((~ cnt_en) & counter5a[0:0]));
	// synopsys translate_off
	initial
		counter5a[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[1:1] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[1:1] <= 1'b0;
			else  counter5a[1:1] <= (counter5a[1:1] ^ (counter5a[0:0] & cntr_cout[0]));
	// synopsys translate_off
	initial
		counter5a[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[2:2] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[2:2] <= 1'b0;
			else  counter5a[2:2] <= (counter5a[2:2] ^ (counter5a[1:1] & cntr_cout[1]));
	// synopsys translate_off
	initial
		counter5a[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[3:3] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[3:3] <= 1'b0;
			else  counter5a[3:3] <= (counter5a[3:3] ^ (counter5a[2:2] & cntr_cout[2]));
	// synopsys translate_off
	initial
		counter5a[4:4] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[4:4] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[4:4] <= 1'b0;
			else  counter5a[4:4] <= (counter5a[4:4] ^ (counter5a[3:3] & cntr_cout[3]));
	// synopsys translate_off
	initial
		counter5a[5:5] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[5:5] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[5:5] <= 1'b0;
			else  counter5a[5:5] <= (counter5a[5:5] ^ (counter5a[4:4] & cntr_cout[4]));
	// synopsys translate_off
	initial
		counter5a[6:6] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[6:6] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[6:6] <= 1'b0;
			else  counter5a[6:6] <= (counter5a[6:6] ^ (counter5a[5:5] & cntr_cout[5]));
	// synopsys translate_off
	initial
		counter5a[7:7] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[7:7] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[7:7] <= 1'b0;
			else  counter5a[7:7] <= (counter5a[7:7] ^ (counter5a[6:6] & cntr_cout[6]));
	// synopsys translate_off
	initial
		counter5a[8:8] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[8:8] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[8:8] <= 1'b0;
			else  counter5a[8:8] <= (counter5a[8:8] ^ (counter5a[7:7] & cntr_cout[7]));
	// synopsys translate_off
	initial
		counter5a[9:9] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter5a[9:9] <= 1'b0;
		else
			if (sclr == 1'b1) counter5a[9:9] <= 1'b0;
			else  counter5a[9:9] <= (counter5a[9:9] ^ cntr_cout[8]);
	// synopsys translate_off
	initial
		parity6 = {1{1'b1}};
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) parity6 <= {1{1'b1}};
		else
			if (sclr == 1'b1) parity6 <= 1'b0;
			else  parity6 <= ((cnt_en & ((sub_parity7a[0] ^ sub_parity7a[1]) ^ sub_parity7a[2])) | ((~ cnt_en) & parity6));
	// synopsys translate_off
	initial
		sub_parity7a[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity7a[0:0] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity7a[0:0] <= 1'b0;
			else  sub_parity7a[0:0] <= ((cnt_en & (((counter5a[0] ^ counter5a[1]) ^ counter5a[2]) ^ counter5a[3])) | ((~ cnt_en) & sub_parity7a[0:0]));
	// synopsys translate_off
	initial
		sub_parity7a[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity7a[1:1] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity7a[1:1] <= 1'b0;
			else  sub_parity7a[1:1] <= ((cnt_en & (((counter5a[4] ^ counter5a[5]) ^ counter5a[6]) ^ counter5a[7])) | ((~ cnt_en) & sub_parity7a[1:1]));
	// synopsys translate_off
	initial
		sub_parity7a[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity7a[2:2] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity7a[2:2] <= 1'b0;
			else  sub_parity7a[2:2] <= ((cnt_en & (counter5a[8] ^ counter5a[9])) | ((~ cnt_en) & sub_parity7a[2:2]));
	assign
		cntr_cout = {1'b0, (cntr_cout[7] & (~ counter5a[7:7])), (cntr_cout[6] & (~ counter5a[6:6])), (cntr_cout[5] & (~ counter5a[5:5])), (cntr_cout[4] & (~ counter5a[4:4])), (cntr_cout[3] & (~ counter5a[3:3])), (cntr_cout[2] & (~ counter5a[2:2])), (cntr_cout[1] & (~ counter5a[1:1])), (cntr_cout[0] & (~ counter5a[0:0])), (cnt_en & parity_cout)},
		parity_cout = (((~ parity6) ^ updown) & cnt_en),
		q = counter5a,
		sclr = 1'b0,
		updown = 1'b1;
endmodule //rx_fifo_a_graycounter_gs9


//a_graycounter CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="Cyclone IV E" PVALUE=1 WIDTH=10 aclr clock cnt_en q ALTERA_INTERNAL_OPTIONS=suppress_da_rule_internal=S102
//VERSION_BEGIN 18.1 cbx_a_gray2bin 2018:09:12:13:04:24:SJ cbx_a_graycounter 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = reg 14 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"suppress_da_rule_internal=S102;{-to counter8a[0]} POWER_UP_LEVEL=HIGH"} *)
module  rx_fifo_a_graycounter_caf
	( 
	aclr,
	clock,
	cnt_en,
	q) /* synthesis synthesis_clearbox=1 */;
	input   aclr;
	input   clock;
	input   cnt_en;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   aclr;
	tri1   cnt_en;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[9:0]	counter8a;
	(* ALTERA_ATTRIBUTE = {"POWER_UP_LEVEL=HIGH"} *)
	reg	parity9;
	reg	[2:0]	sub_parity10a;
	wire  [9:0]  cntr_cout;
	wire  parity_cout;
	wire sclr;
	wire updown;

	// synopsys translate_off
	initial
		counter8a[0:0] = {1{1'b1}};
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[0:0] <= {1{1'b1}};
		else
			if (sclr == 1'b1) counter8a[0:0] <= 1'b0;
			else  counter8a[0:0] <= ((cnt_en & (counter8a[0:0] ^ (~ parity_cout))) | ((~ cnt_en) & counter8a[0:0]));
	// synopsys translate_off
	initial
		counter8a[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[1:1] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[1:1] <= 1'b0;
			else  counter8a[1:1] <= (counter8a[1:1] ^ (counter8a[0:0] & cntr_cout[0]));
	// synopsys translate_off
	initial
		counter8a[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[2:2] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[2:2] <= 1'b0;
			else  counter8a[2:2] <= (counter8a[2:2] ^ (counter8a[1:1] & cntr_cout[1]));
	// synopsys translate_off
	initial
		counter8a[3:3] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[3:3] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[3:3] <= 1'b0;
			else  counter8a[3:3] <= (counter8a[3:3] ^ (counter8a[2:2] & cntr_cout[2]));
	// synopsys translate_off
	initial
		counter8a[4:4] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[4:4] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[4:4] <= 1'b0;
			else  counter8a[4:4] <= (counter8a[4:4] ^ (counter8a[3:3] & cntr_cout[3]));
	// synopsys translate_off
	initial
		counter8a[5:5] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[5:5] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[5:5] <= 1'b0;
			else  counter8a[5:5] <= (counter8a[5:5] ^ (counter8a[4:4] & cntr_cout[4]));
	// synopsys translate_off
	initial
		counter8a[6:6] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[6:6] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[6:6] <= 1'b0;
			else  counter8a[6:6] <= (counter8a[6:6] ^ (counter8a[5:5] & cntr_cout[5]));
	// synopsys translate_off
	initial
		counter8a[7:7] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[7:7] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[7:7] <= 1'b0;
			else  counter8a[7:7] <= (counter8a[7:7] ^ (counter8a[6:6] & cntr_cout[6]));
	// synopsys translate_off
	initial
		counter8a[8:8] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[8:8] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[8:8] <= 1'b0;
			else  counter8a[8:8] <= (counter8a[8:8] ^ (counter8a[7:7] & cntr_cout[7]));
	// synopsys translate_off
	initial
		counter8a[9:9] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) counter8a[9:9] <= 1'b0;
		else
			if (sclr == 1'b1) counter8a[9:9] <= 1'b0;
			else  counter8a[9:9] <= (counter8a[9:9] ^ cntr_cout[8]);
	// synopsys translate_off
	initial
		parity9 = {1{1'b1}};
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) parity9 <= {1{1'b1}};
		else
			if (sclr == 1'b1) parity9 <= 1'b0;
			else  parity9 <= ((cnt_en & ((sub_parity10a[0] ^ sub_parity10a[1]) ^ sub_parity10a[2])) | ((~ cnt_en) & parity9));
	// synopsys translate_off
	initial
		sub_parity10a[0:0] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity10a[0:0] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity10a[0:0] <= 1'b0;
			else  sub_parity10a[0:0] <= ((cnt_en & (((counter8a[0] ^ counter8a[1]) ^ counter8a[2]) ^ counter8a[3])) | ((~ cnt_en) & sub_parity10a[0:0]));
	// synopsys translate_off
	initial
		sub_parity10a[1:1] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity10a[1:1] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity10a[1:1] <= 1'b0;
			else  sub_parity10a[1:1] <= ((cnt_en & (((counter8a[4] ^ counter8a[5]) ^ counter8a[6]) ^ counter8a[7])) | ((~ cnt_en) & sub_parity10a[1:1]));
	// synopsys translate_off
	initial
		sub_parity10a[2:2] = 0;
	// synopsys translate_on
	always @ ( posedge clock or  posedge aclr)
		if (aclr == 1'b1) sub_parity10a[2:2] <= 1'b0;
		else
			if (sclr == 1'b1) sub_parity10a[2:2] <= 1'b0;
			else  sub_parity10a[2:2] <= ((cnt_en & (counter8a[8] ^ counter8a[9])) | ((~ cnt_en) & sub_parity10a[2:2]));
	assign
		cntr_cout = {1'b0, (cntr_cout[7] & (~ counter8a[7:7])), (cntr_cout[6] & (~ counter8a[6:6])), (cntr_cout[5] & (~ counter8a[5:5])), (cntr_cout[4] & (~ counter8a[4:4])), (cntr_cout[3] & (~ counter8a[3:3])), (cntr_cout[2] & (~ counter8a[2:2])), (cntr_cout[1] & (~ counter8a[1:1])), (cntr_cout[0] & (~ counter8a[0:0])), (cnt_en & parity_cout)},
		parity_cout = (((~ parity9) ^ updown) & cnt_en),
		q = counter8a,
		sclr = 1'b0,
		updown = 1'b1;
endmodule //rx_fifo_a_graycounter_caf


//altsyncram ADDRESS_ACLR_B="CLEAR1" ADDRESS_REG_B="CLOCK1" CBX_SINGLE_OUTPUT_FILE="ON" CLOCK_ENABLE_INPUT_B="BYPASS" DEVICE_FAMILY="Cyclone IV E" ENABLE_ECC="FALSE" OPERATION_MODE="DUAL_PORT" OUTDATA_REG_B="UNREGISTERED" WIDTH_A=97 WIDTH_B=97 WIDTH_BYTEENA_A=1 WIDTH_ECCSTATUS=2 WIDTHAD_A=9 WIDTHAD_B=9 aclr1 address_a address_b addressstall_b clock0 clock1 data_a q_b wren_a
//VERSION_BEGIN 18.1 cbx_altera_syncram_nd_impl 2018:09:12:13:04:24:SJ cbx_altsyncram 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_lpm_add_sub 2018:09:12:13:04:24:SJ cbx_lpm_compare 2018:09:12:13:04:24:SJ cbx_lpm_decode 2018:09:12:13:04:24:SJ cbx_lpm_mux 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_nadder 2018:09:12:13:04:24:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_stratixiii 2018:09:12:13:04:24:SJ cbx_stratixv 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = M9K 6 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"OPTIMIZE_POWER_DURING_SYNTHESIS=NORMAL_COMPILATION"} *)
module  rx_fifo_altsyncram_f821
	( 
	aclr1,
	address_a,
	address_b,
	addressstall_b,
	clock0,
	clock1,
	data_a,
	q_b,
	wren_a) /* synthesis synthesis_clearbox=1 */;
	input   aclr1;
	input   [8:0]  address_a;
	input   [8:0]  address_b;
	input   addressstall_b;
	input   clock0;
	input   clock1;
	input   [96:0]  data_a;
	output   [96:0]  q_b;
	input   wren_a;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   aclr1;
	tri1   [8:0]  address_b;
	tri0   addressstall_b;
	tri1   clock0;
	tri1   clock1;
	tri1   [96:0]  data_a;
	tri0   wren_a;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]   wire_ram_block11a_0portbdataout;
	wire  [0:0]   wire_ram_block11a_1portbdataout;
	wire  [0:0]   wire_ram_block11a_2portbdataout;
	wire  [0:0]   wire_ram_block11a_3portbdataout;
	wire  [0:0]   wire_ram_block11a_4portbdataout;
	wire  [0:0]   wire_ram_block11a_5portbdataout;
	wire  [0:0]   wire_ram_block11a_6portbdataout;
	wire  [0:0]   wire_ram_block11a_7portbdataout;
	wire  [0:0]   wire_ram_block11a_8portbdataout;
	wire  [0:0]   wire_ram_block11a_9portbdataout;
	wire  [0:0]   wire_ram_block11a_10portbdataout;
	wire  [0:0]   wire_ram_block11a_11portbdataout;
	wire  [0:0]   wire_ram_block11a_12portbdataout;
	wire  [0:0]   wire_ram_block11a_13portbdataout;
	wire  [0:0]   wire_ram_block11a_14portbdataout;
	wire  [0:0]   wire_ram_block11a_15portbdataout;
	wire  [0:0]   wire_ram_block11a_16portbdataout;
	wire  [0:0]   wire_ram_block11a_17portbdataout;
	wire  [0:0]   wire_ram_block11a_18portbdataout;
	wire  [0:0]   wire_ram_block11a_19portbdataout;
	wire  [0:0]   wire_ram_block11a_20portbdataout;
	wire  [0:0]   wire_ram_block11a_21portbdataout;
	wire  [0:0]   wire_ram_block11a_22portbdataout;
	wire  [0:0]   wire_ram_block11a_23portbdataout;
	wire  [0:0]   wire_ram_block11a_24portbdataout;
	wire  [0:0]   wire_ram_block11a_25portbdataout;
	wire  [0:0]   wire_ram_block11a_26portbdataout;
	wire  [0:0]   wire_ram_block11a_27portbdataout;
	wire  [0:0]   wire_ram_block11a_28portbdataout;
	wire  [0:0]   wire_ram_block11a_29portbdataout;
	wire  [0:0]   wire_ram_block11a_30portbdataout;
	wire  [0:0]   wire_ram_block11a_31portbdataout;
	wire  [0:0]   wire_ram_block11a_32portbdataout;
	wire  [0:0]   wire_ram_block11a_33portbdataout;
	wire  [0:0]   wire_ram_block11a_34portbdataout;
	wire  [0:0]   wire_ram_block11a_35portbdataout;
	wire  [0:0]   wire_ram_block11a_36portbdataout;
	wire  [0:0]   wire_ram_block11a_37portbdataout;
	wire  [0:0]   wire_ram_block11a_38portbdataout;
	wire  [0:0]   wire_ram_block11a_39portbdataout;
	wire  [0:0]   wire_ram_block11a_40portbdataout;
	wire  [0:0]   wire_ram_block11a_41portbdataout;
	wire  [0:0]   wire_ram_block11a_42portbdataout;
	wire  [0:0]   wire_ram_block11a_43portbdataout;
	wire  [0:0]   wire_ram_block11a_44portbdataout;
	wire  [0:0]   wire_ram_block11a_45portbdataout;
	wire  [0:0]   wire_ram_block11a_46portbdataout;
	wire  [0:0]   wire_ram_block11a_47portbdataout;
	wire  [0:0]   wire_ram_block11a_48portbdataout;
	wire  [0:0]   wire_ram_block11a_49portbdataout;
	wire  [0:0]   wire_ram_block11a_50portbdataout;
	wire  [0:0]   wire_ram_block11a_51portbdataout;
	wire  [0:0]   wire_ram_block11a_52portbdataout;
	wire  [0:0]   wire_ram_block11a_53portbdataout;
	wire  [0:0]   wire_ram_block11a_54portbdataout;
	wire  [0:0]   wire_ram_block11a_55portbdataout;
	wire  [0:0]   wire_ram_block11a_56portbdataout;
	wire  [0:0]   wire_ram_block11a_57portbdataout;
	wire  [0:0]   wire_ram_block11a_58portbdataout;
	wire  [0:0]   wire_ram_block11a_59portbdataout;
	wire  [0:0]   wire_ram_block11a_60portbdataout;
	wire  [0:0]   wire_ram_block11a_61portbdataout;
	wire  [0:0]   wire_ram_block11a_62portbdataout;
	wire  [0:0]   wire_ram_block11a_63portbdataout;
	wire  [0:0]   wire_ram_block11a_64portbdataout;
	wire  [0:0]   wire_ram_block11a_65portbdataout;
	wire  [0:0]   wire_ram_block11a_66portbdataout;
	wire  [0:0]   wire_ram_block11a_67portbdataout;
	wire  [0:0]   wire_ram_block11a_68portbdataout;
	wire  [0:0]   wire_ram_block11a_69portbdataout;
	wire  [0:0]   wire_ram_block11a_70portbdataout;
	wire  [0:0]   wire_ram_block11a_71portbdataout;
	wire  [0:0]   wire_ram_block11a_72portbdataout;
	wire  [0:0]   wire_ram_block11a_73portbdataout;
	wire  [0:0]   wire_ram_block11a_74portbdataout;
	wire  [0:0]   wire_ram_block11a_75portbdataout;
	wire  [0:0]   wire_ram_block11a_76portbdataout;
	wire  [0:0]   wire_ram_block11a_77portbdataout;
	wire  [0:0]   wire_ram_block11a_78portbdataout;
	wire  [0:0]   wire_ram_block11a_79portbdataout;
	wire  [0:0]   wire_ram_block11a_80portbdataout;
	wire  [0:0]   wire_ram_block11a_81portbdataout;
	wire  [0:0]   wire_ram_block11a_82portbdataout;
	wire  [0:0]   wire_ram_block11a_83portbdataout;
	wire  [0:0]   wire_ram_block11a_84portbdataout;
	wire  [0:0]   wire_ram_block11a_85portbdataout;
	wire  [0:0]   wire_ram_block11a_86portbdataout;
	wire  [0:0]   wire_ram_block11a_87portbdataout;
	wire  [0:0]   wire_ram_block11a_88portbdataout;
	wire  [0:0]   wire_ram_block11a_89portbdataout;
	wire  [0:0]   wire_ram_block11a_90portbdataout;
	wire  [0:0]   wire_ram_block11a_91portbdataout;
	wire  [0:0]   wire_ram_block11a_92portbdataout;
	wire  [0:0]   wire_ram_block11a_93portbdataout;
	wire  [0:0]   wire_ram_block11a_94portbdataout;
	wire  [0:0]   wire_ram_block11a_95portbdataout;
	wire  [0:0]   wire_ram_block11a_96portbdataout;
	wire  [8:0]  address_a_wire;
	wire  [8:0]  address_b_wire;

	cycloneive_ram_block   ram_block11a_0
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[0]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_0portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_0.clk0_core_clock_enable = "ena0",
		ram_block11a_0.clk0_input_clock_enable = "none",
		ram_block11a_0.clk1_core_clock_enable = "none",
		ram_block11a_0.clk1_input_clock_enable = "none",
		ram_block11a_0.connectivity_checking = "OFF",
		ram_block11a_0.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_0.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_0.operation_mode = "dual_port",
		ram_block11a_0.port_a_address_width = 9,
		ram_block11a_0.port_a_data_width = 1,
		ram_block11a_0.port_a_first_address = 0,
		ram_block11a_0.port_a_first_bit_number = 0,
		ram_block11a_0.port_a_last_address = 511,
		ram_block11a_0.port_a_logical_ram_depth = 512,
		ram_block11a_0.port_a_logical_ram_width = 97,
		ram_block11a_0.port_b_address_clear = "clear1",
		ram_block11a_0.port_b_address_clock = "clock1",
		ram_block11a_0.port_b_address_width = 9,
		ram_block11a_0.port_b_data_out_clear = "none",
		ram_block11a_0.port_b_data_width = 1,
		ram_block11a_0.port_b_first_address = 0,
		ram_block11a_0.port_b_first_bit_number = 0,
		ram_block11a_0.port_b_last_address = 511,
		ram_block11a_0.port_b_logical_ram_depth = 512,
		ram_block11a_0.port_b_logical_ram_width = 97,
		ram_block11a_0.port_b_read_enable_clock = "clock1",
		ram_block11a_0.ram_block_type = "AUTO",
		ram_block11a_0.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_1
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[1]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_1portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_1.clk0_core_clock_enable = "ena0",
		ram_block11a_1.clk0_input_clock_enable = "none",
		ram_block11a_1.clk1_core_clock_enable = "none",
		ram_block11a_1.clk1_input_clock_enable = "none",
		ram_block11a_1.connectivity_checking = "OFF",
		ram_block11a_1.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_1.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_1.operation_mode = "dual_port",
		ram_block11a_1.port_a_address_width = 9,
		ram_block11a_1.port_a_data_width = 1,
		ram_block11a_1.port_a_first_address = 0,
		ram_block11a_1.port_a_first_bit_number = 1,
		ram_block11a_1.port_a_last_address = 511,
		ram_block11a_1.port_a_logical_ram_depth = 512,
		ram_block11a_1.port_a_logical_ram_width = 97,
		ram_block11a_1.port_b_address_clear = "clear1",
		ram_block11a_1.port_b_address_clock = "clock1",
		ram_block11a_1.port_b_address_width = 9,
		ram_block11a_1.port_b_data_out_clear = "none",
		ram_block11a_1.port_b_data_width = 1,
		ram_block11a_1.port_b_first_address = 0,
		ram_block11a_1.port_b_first_bit_number = 1,
		ram_block11a_1.port_b_last_address = 511,
		ram_block11a_1.port_b_logical_ram_depth = 512,
		ram_block11a_1.port_b_logical_ram_width = 97,
		ram_block11a_1.port_b_read_enable_clock = "clock1",
		ram_block11a_1.ram_block_type = "AUTO",
		ram_block11a_1.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_2
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[2]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_2portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_2.clk0_core_clock_enable = "ena0",
		ram_block11a_2.clk0_input_clock_enable = "none",
		ram_block11a_2.clk1_core_clock_enable = "none",
		ram_block11a_2.clk1_input_clock_enable = "none",
		ram_block11a_2.connectivity_checking = "OFF",
		ram_block11a_2.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_2.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_2.operation_mode = "dual_port",
		ram_block11a_2.port_a_address_width = 9,
		ram_block11a_2.port_a_data_width = 1,
		ram_block11a_2.port_a_first_address = 0,
		ram_block11a_2.port_a_first_bit_number = 2,
		ram_block11a_2.port_a_last_address = 511,
		ram_block11a_2.port_a_logical_ram_depth = 512,
		ram_block11a_2.port_a_logical_ram_width = 97,
		ram_block11a_2.port_b_address_clear = "clear1",
		ram_block11a_2.port_b_address_clock = "clock1",
		ram_block11a_2.port_b_address_width = 9,
		ram_block11a_2.port_b_data_out_clear = "none",
		ram_block11a_2.port_b_data_width = 1,
		ram_block11a_2.port_b_first_address = 0,
		ram_block11a_2.port_b_first_bit_number = 2,
		ram_block11a_2.port_b_last_address = 511,
		ram_block11a_2.port_b_logical_ram_depth = 512,
		ram_block11a_2.port_b_logical_ram_width = 97,
		ram_block11a_2.port_b_read_enable_clock = "clock1",
		ram_block11a_2.ram_block_type = "AUTO",
		ram_block11a_2.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_3
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[3]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_3portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_3.clk0_core_clock_enable = "ena0",
		ram_block11a_3.clk0_input_clock_enable = "none",
		ram_block11a_3.clk1_core_clock_enable = "none",
		ram_block11a_3.clk1_input_clock_enable = "none",
		ram_block11a_3.connectivity_checking = "OFF",
		ram_block11a_3.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_3.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_3.operation_mode = "dual_port",
		ram_block11a_3.port_a_address_width = 9,
		ram_block11a_3.port_a_data_width = 1,
		ram_block11a_3.port_a_first_address = 0,
		ram_block11a_3.port_a_first_bit_number = 3,
		ram_block11a_3.port_a_last_address = 511,
		ram_block11a_3.port_a_logical_ram_depth = 512,
		ram_block11a_3.port_a_logical_ram_width = 97,
		ram_block11a_3.port_b_address_clear = "clear1",
		ram_block11a_3.port_b_address_clock = "clock1",
		ram_block11a_3.port_b_address_width = 9,
		ram_block11a_3.port_b_data_out_clear = "none",
		ram_block11a_3.port_b_data_width = 1,
		ram_block11a_3.port_b_first_address = 0,
		ram_block11a_3.port_b_first_bit_number = 3,
		ram_block11a_3.port_b_last_address = 511,
		ram_block11a_3.port_b_logical_ram_depth = 512,
		ram_block11a_3.port_b_logical_ram_width = 97,
		ram_block11a_3.port_b_read_enable_clock = "clock1",
		ram_block11a_3.ram_block_type = "AUTO",
		ram_block11a_3.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_4
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[4]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_4portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_4.clk0_core_clock_enable = "ena0",
		ram_block11a_4.clk0_input_clock_enable = "none",
		ram_block11a_4.clk1_core_clock_enable = "none",
		ram_block11a_4.clk1_input_clock_enable = "none",
		ram_block11a_4.connectivity_checking = "OFF",
		ram_block11a_4.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_4.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_4.operation_mode = "dual_port",
		ram_block11a_4.port_a_address_width = 9,
		ram_block11a_4.port_a_data_width = 1,
		ram_block11a_4.port_a_first_address = 0,
		ram_block11a_4.port_a_first_bit_number = 4,
		ram_block11a_4.port_a_last_address = 511,
		ram_block11a_4.port_a_logical_ram_depth = 512,
		ram_block11a_4.port_a_logical_ram_width = 97,
		ram_block11a_4.port_b_address_clear = "clear1",
		ram_block11a_4.port_b_address_clock = "clock1",
		ram_block11a_4.port_b_address_width = 9,
		ram_block11a_4.port_b_data_out_clear = "none",
		ram_block11a_4.port_b_data_width = 1,
		ram_block11a_4.port_b_first_address = 0,
		ram_block11a_4.port_b_first_bit_number = 4,
		ram_block11a_4.port_b_last_address = 511,
		ram_block11a_4.port_b_logical_ram_depth = 512,
		ram_block11a_4.port_b_logical_ram_width = 97,
		ram_block11a_4.port_b_read_enable_clock = "clock1",
		ram_block11a_4.ram_block_type = "AUTO",
		ram_block11a_4.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_5
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[5]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_5portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_5.clk0_core_clock_enable = "ena0",
		ram_block11a_5.clk0_input_clock_enable = "none",
		ram_block11a_5.clk1_core_clock_enable = "none",
		ram_block11a_5.clk1_input_clock_enable = "none",
		ram_block11a_5.connectivity_checking = "OFF",
		ram_block11a_5.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_5.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_5.operation_mode = "dual_port",
		ram_block11a_5.port_a_address_width = 9,
		ram_block11a_5.port_a_data_width = 1,
		ram_block11a_5.port_a_first_address = 0,
		ram_block11a_5.port_a_first_bit_number = 5,
		ram_block11a_5.port_a_last_address = 511,
		ram_block11a_5.port_a_logical_ram_depth = 512,
		ram_block11a_5.port_a_logical_ram_width = 97,
		ram_block11a_5.port_b_address_clear = "clear1",
		ram_block11a_5.port_b_address_clock = "clock1",
		ram_block11a_5.port_b_address_width = 9,
		ram_block11a_5.port_b_data_out_clear = "none",
		ram_block11a_5.port_b_data_width = 1,
		ram_block11a_5.port_b_first_address = 0,
		ram_block11a_5.port_b_first_bit_number = 5,
		ram_block11a_5.port_b_last_address = 511,
		ram_block11a_5.port_b_logical_ram_depth = 512,
		ram_block11a_5.port_b_logical_ram_width = 97,
		ram_block11a_5.port_b_read_enable_clock = "clock1",
		ram_block11a_5.ram_block_type = "AUTO",
		ram_block11a_5.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_6
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[6]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_6portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_6.clk0_core_clock_enable = "ena0",
		ram_block11a_6.clk0_input_clock_enable = "none",
		ram_block11a_6.clk1_core_clock_enable = "none",
		ram_block11a_6.clk1_input_clock_enable = "none",
		ram_block11a_6.connectivity_checking = "OFF",
		ram_block11a_6.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_6.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_6.operation_mode = "dual_port",
		ram_block11a_6.port_a_address_width = 9,
		ram_block11a_6.port_a_data_width = 1,
		ram_block11a_6.port_a_first_address = 0,
		ram_block11a_6.port_a_first_bit_number = 6,
		ram_block11a_6.port_a_last_address = 511,
		ram_block11a_6.port_a_logical_ram_depth = 512,
		ram_block11a_6.port_a_logical_ram_width = 97,
		ram_block11a_6.port_b_address_clear = "clear1",
		ram_block11a_6.port_b_address_clock = "clock1",
		ram_block11a_6.port_b_address_width = 9,
		ram_block11a_6.port_b_data_out_clear = "none",
		ram_block11a_6.port_b_data_width = 1,
		ram_block11a_6.port_b_first_address = 0,
		ram_block11a_6.port_b_first_bit_number = 6,
		ram_block11a_6.port_b_last_address = 511,
		ram_block11a_6.port_b_logical_ram_depth = 512,
		ram_block11a_6.port_b_logical_ram_width = 97,
		ram_block11a_6.port_b_read_enable_clock = "clock1",
		ram_block11a_6.ram_block_type = "AUTO",
		ram_block11a_6.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_7
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[7]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_7portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_7.clk0_core_clock_enable = "ena0",
		ram_block11a_7.clk0_input_clock_enable = "none",
		ram_block11a_7.clk1_core_clock_enable = "none",
		ram_block11a_7.clk1_input_clock_enable = "none",
		ram_block11a_7.connectivity_checking = "OFF",
		ram_block11a_7.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_7.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_7.operation_mode = "dual_port",
		ram_block11a_7.port_a_address_width = 9,
		ram_block11a_7.port_a_data_width = 1,
		ram_block11a_7.port_a_first_address = 0,
		ram_block11a_7.port_a_first_bit_number = 7,
		ram_block11a_7.port_a_last_address = 511,
		ram_block11a_7.port_a_logical_ram_depth = 512,
		ram_block11a_7.port_a_logical_ram_width = 97,
		ram_block11a_7.port_b_address_clear = "clear1",
		ram_block11a_7.port_b_address_clock = "clock1",
		ram_block11a_7.port_b_address_width = 9,
		ram_block11a_7.port_b_data_out_clear = "none",
		ram_block11a_7.port_b_data_width = 1,
		ram_block11a_7.port_b_first_address = 0,
		ram_block11a_7.port_b_first_bit_number = 7,
		ram_block11a_7.port_b_last_address = 511,
		ram_block11a_7.port_b_logical_ram_depth = 512,
		ram_block11a_7.port_b_logical_ram_width = 97,
		ram_block11a_7.port_b_read_enable_clock = "clock1",
		ram_block11a_7.ram_block_type = "AUTO",
		ram_block11a_7.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_8
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[8]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_8portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_8.clk0_core_clock_enable = "ena0",
		ram_block11a_8.clk0_input_clock_enable = "none",
		ram_block11a_8.clk1_core_clock_enable = "none",
		ram_block11a_8.clk1_input_clock_enable = "none",
		ram_block11a_8.connectivity_checking = "OFF",
		ram_block11a_8.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_8.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_8.operation_mode = "dual_port",
		ram_block11a_8.port_a_address_width = 9,
		ram_block11a_8.port_a_data_width = 1,
		ram_block11a_8.port_a_first_address = 0,
		ram_block11a_8.port_a_first_bit_number = 8,
		ram_block11a_8.port_a_last_address = 511,
		ram_block11a_8.port_a_logical_ram_depth = 512,
		ram_block11a_8.port_a_logical_ram_width = 97,
		ram_block11a_8.port_b_address_clear = "clear1",
		ram_block11a_8.port_b_address_clock = "clock1",
		ram_block11a_8.port_b_address_width = 9,
		ram_block11a_8.port_b_data_out_clear = "none",
		ram_block11a_8.port_b_data_width = 1,
		ram_block11a_8.port_b_first_address = 0,
		ram_block11a_8.port_b_first_bit_number = 8,
		ram_block11a_8.port_b_last_address = 511,
		ram_block11a_8.port_b_logical_ram_depth = 512,
		ram_block11a_8.port_b_logical_ram_width = 97,
		ram_block11a_8.port_b_read_enable_clock = "clock1",
		ram_block11a_8.ram_block_type = "AUTO",
		ram_block11a_8.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_9
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[9]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_9portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_9.clk0_core_clock_enable = "ena0",
		ram_block11a_9.clk0_input_clock_enable = "none",
		ram_block11a_9.clk1_core_clock_enable = "none",
		ram_block11a_9.clk1_input_clock_enable = "none",
		ram_block11a_9.connectivity_checking = "OFF",
		ram_block11a_9.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_9.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_9.operation_mode = "dual_port",
		ram_block11a_9.port_a_address_width = 9,
		ram_block11a_9.port_a_data_width = 1,
		ram_block11a_9.port_a_first_address = 0,
		ram_block11a_9.port_a_first_bit_number = 9,
		ram_block11a_9.port_a_last_address = 511,
		ram_block11a_9.port_a_logical_ram_depth = 512,
		ram_block11a_9.port_a_logical_ram_width = 97,
		ram_block11a_9.port_b_address_clear = "clear1",
		ram_block11a_9.port_b_address_clock = "clock1",
		ram_block11a_9.port_b_address_width = 9,
		ram_block11a_9.port_b_data_out_clear = "none",
		ram_block11a_9.port_b_data_width = 1,
		ram_block11a_9.port_b_first_address = 0,
		ram_block11a_9.port_b_first_bit_number = 9,
		ram_block11a_9.port_b_last_address = 511,
		ram_block11a_9.port_b_logical_ram_depth = 512,
		ram_block11a_9.port_b_logical_ram_width = 97,
		ram_block11a_9.port_b_read_enable_clock = "clock1",
		ram_block11a_9.ram_block_type = "AUTO",
		ram_block11a_9.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_10
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[10]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_10portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_10.clk0_core_clock_enable = "ena0",
		ram_block11a_10.clk0_input_clock_enable = "none",
		ram_block11a_10.clk1_core_clock_enable = "none",
		ram_block11a_10.clk1_input_clock_enable = "none",
		ram_block11a_10.connectivity_checking = "OFF",
		ram_block11a_10.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_10.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_10.operation_mode = "dual_port",
		ram_block11a_10.port_a_address_width = 9,
		ram_block11a_10.port_a_data_width = 1,
		ram_block11a_10.port_a_first_address = 0,
		ram_block11a_10.port_a_first_bit_number = 10,
		ram_block11a_10.port_a_last_address = 511,
		ram_block11a_10.port_a_logical_ram_depth = 512,
		ram_block11a_10.port_a_logical_ram_width = 97,
		ram_block11a_10.port_b_address_clear = "clear1",
		ram_block11a_10.port_b_address_clock = "clock1",
		ram_block11a_10.port_b_address_width = 9,
		ram_block11a_10.port_b_data_out_clear = "none",
		ram_block11a_10.port_b_data_width = 1,
		ram_block11a_10.port_b_first_address = 0,
		ram_block11a_10.port_b_first_bit_number = 10,
		ram_block11a_10.port_b_last_address = 511,
		ram_block11a_10.port_b_logical_ram_depth = 512,
		ram_block11a_10.port_b_logical_ram_width = 97,
		ram_block11a_10.port_b_read_enable_clock = "clock1",
		ram_block11a_10.ram_block_type = "AUTO",
		ram_block11a_10.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_11
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[11]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_11portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_11.clk0_core_clock_enable = "ena0",
		ram_block11a_11.clk0_input_clock_enable = "none",
		ram_block11a_11.clk1_core_clock_enable = "none",
		ram_block11a_11.clk1_input_clock_enable = "none",
		ram_block11a_11.connectivity_checking = "OFF",
		ram_block11a_11.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_11.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_11.operation_mode = "dual_port",
		ram_block11a_11.port_a_address_width = 9,
		ram_block11a_11.port_a_data_width = 1,
		ram_block11a_11.port_a_first_address = 0,
		ram_block11a_11.port_a_first_bit_number = 11,
		ram_block11a_11.port_a_last_address = 511,
		ram_block11a_11.port_a_logical_ram_depth = 512,
		ram_block11a_11.port_a_logical_ram_width = 97,
		ram_block11a_11.port_b_address_clear = "clear1",
		ram_block11a_11.port_b_address_clock = "clock1",
		ram_block11a_11.port_b_address_width = 9,
		ram_block11a_11.port_b_data_out_clear = "none",
		ram_block11a_11.port_b_data_width = 1,
		ram_block11a_11.port_b_first_address = 0,
		ram_block11a_11.port_b_first_bit_number = 11,
		ram_block11a_11.port_b_last_address = 511,
		ram_block11a_11.port_b_logical_ram_depth = 512,
		ram_block11a_11.port_b_logical_ram_width = 97,
		ram_block11a_11.port_b_read_enable_clock = "clock1",
		ram_block11a_11.ram_block_type = "AUTO",
		ram_block11a_11.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_12
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[12]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_12portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_12.clk0_core_clock_enable = "ena0",
		ram_block11a_12.clk0_input_clock_enable = "none",
		ram_block11a_12.clk1_core_clock_enable = "none",
		ram_block11a_12.clk1_input_clock_enable = "none",
		ram_block11a_12.connectivity_checking = "OFF",
		ram_block11a_12.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_12.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_12.operation_mode = "dual_port",
		ram_block11a_12.port_a_address_width = 9,
		ram_block11a_12.port_a_data_width = 1,
		ram_block11a_12.port_a_first_address = 0,
		ram_block11a_12.port_a_first_bit_number = 12,
		ram_block11a_12.port_a_last_address = 511,
		ram_block11a_12.port_a_logical_ram_depth = 512,
		ram_block11a_12.port_a_logical_ram_width = 97,
		ram_block11a_12.port_b_address_clear = "clear1",
		ram_block11a_12.port_b_address_clock = "clock1",
		ram_block11a_12.port_b_address_width = 9,
		ram_block11a_12.port_b_data_out_clear = "none",
		ram_block11a_12.port_b_data_width = 1,
		ram_block11a_12.port_b_first_address = 0,
		ram_block11a_12.port_b_first_bit_number = 12,
		ram_block11a_12.port_b_last_address = 511,
		ram_block11a_12.port_b_logical_ram_depth = 512,
		ram_block11a_12.port_b_logical_ram_width = 97,
		ram_block11a_12.port_b_read_enable_clock = "clock1",
		ram_block11a_12.ram_block_type = "AUTO",
		ram_block11a_12.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_13
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[13]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_13portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_13.clk0_core_clock_enable = "ena0",
		ram_block11a_13.clk0_input_clock_enable = "none",
		ram_block11a_13.clk1_core_clock_enable = "none",
		ram_block11a_13.clk1_input_clock_enable = "none",
		ram_block11a_13.connectivity_checking = "OFF",
		ram_block11a_13.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_13.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_13.operation_mode = "dual_port",
		ram_block11a_13.port_a_address_width = 9,
		ram_block11a_13.port_a_data_width = 1,
		ram_block11a_13.port_a_first_address = 0,
		ram_block11a_13.port_a_first_bit_number = 13,
		ram_block11a_13.port_a_last_address = 511,
		ram_block11a_13.port_a_logical_ram_depth = 512,
		ram_block11a_13.port_a_logical_ram_width = 97,
		ram_block11a_13.port_b_address_clear = "clear1",
		ram_block11a_13.port_b_address_clock = "clock1",
		ram_block11a_13.port_b_address_width = 9,
		ram_block11a_13.port_b_data_out_clear = "none",
		ram_block11a_13.port_b_data_width = 1,
		ram_block11a_13.port_b_first_address = 0,
		ram_block11a_13.port_b_first_bit_number = 13,
		ram_block11a_13.port_b_last_address = 511,
		ram_block11a_13.port_b_logical_ram_depth = 512,
		ram_block11a_13.port_b_logical_ram_width = 97,
		ram_block11a_13.port_b_read_enable_clock = "clock1",
		ram_block11a_13.ram_block_type = "AUTO",
		ram_block11a_13.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_14
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[14]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_14portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_14.clk0_core_clock_enable = "ena0",
		ram_block11a_14.clk0_input_clock_enable = "none",
		ram_block11a_14.clk1_core_clock_enable = "none",
		ram_block11a_14.clk1_input_clock_enable = "none",
		ram_block11a_14.connectivity_checking = "OFF",
		ram_block11a_14.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_14.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_14.operation_mode = "dual_port",
		ram_block11a_14.port_a_address_width = 9,
		ram_block11a_14.port_a_data_width = 1,
		ram_block11a_14.port_a_first_address = 0,
		ram_block11a_14.port_a_first_bit_number = 14,
		ram_block11a_14.port_a_last_address = 511,
		ram_block11a_14.port_a_logical_ram_depth = 512,
		ram_block11a_14.port_a_logical_ram_width = 97,
		ram_block11a_14.port_b_address_clear = "clear1",
		ram_block11a_14.port_b_address_clock = "clock1",
		ram_block11a_14.port_b_address_width = 9,
		ram_block11a_14.port_b_data_out_clear = "none",
		ram_block11a_14.port_b_data_width = 1,
		ram_block11a_14.port_b_first_address = 0,
		ram_block11a_14.port_b_first_bit_number = 14,
		ram_block11a_14.port_b_last_address = 511,
		ram_block11a_14.port_b_logical_ram_depth = 512,
		ram_block11a_14.port_b_logical_ram_width = 97,
		ram_block11a_14.port_b_read_enable_clock = "clock1",
		ram_block11a_14.ram_block_type = "AUTO",
		ram_block11a_14.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_15
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[15]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_15portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_15.clk0_core_clock_enable = "ena0",
		ram_block11a_15.clk0_input_clock_enable = "none",
		ram_block11a_15.clk1_core_clock_enable = "none",
		ram_block11a_15.clk1_input_clock_enable = "none",
		ram_block11a_15.connectivity_checking = "OFF",
		ram_block11a_15.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_15.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_15.operation_mode = "dual_port",
		ram_block11a_15.port_a_address_width = 9,
		ram_block11a_15.port_a_data_width = 1,
		ram_block11a_15.port_a_first_address = 0,
		ram_block11a_15.port_a_first_bit_number = 15,
		ram_block11a_15.port_a_last_address = 511,
		ram_block11a_15.port_a_logical_ram_depth = 512,
		ram_block11a_15.port_a_logical_ram_width = 97,
		ram_block11a_15.port_b_address_clear = "clear1",
		ram_block11a_15.port_b_address_clock = "clock1",
		ram_block11a_15.port_b_address_width = 9,
		ram_block11a_15.port_b_data_out_clear = "none",
		ram_block11a_15.port_b_data_width = 1,
		ram_block11a_15.port_b_first_address = 0,
		ram_block11a_15.port_b_first_bit_number = 15,
		ram_block11a_15.port_b_last_address = 511,
		ram_block11a_15.port_b_logical_ram_depth = 512,
		ram_block11a_15.port_b_logical_ram_width = 97,
		ram_block11a_15.port_b_read_enable_clock = "clock1",
		ram_block11a_15.ram_block_type = "AUTO",
		ram_block11a_15.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_16
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[16]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_16portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_16.clk0_core_clock_enable = "ena0",
		ram_block11a_16.clk0_input_clock_enable = "none",
		ram_block11a_16.clk1_core_clock_enable = "none",
		ram_block11a_16.clk1_input_clock_enable = "none",
		ram_block11a_16.connectivity_checking = "OFF",
		ram_block11a_16.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_16.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_16.operation_mode = "dual_port",
		ram_block11a_16.port_a_address_width = 9,
		ram_block11a_16.port_a_data_width = 1,
		ram_block11a_16.port_a_first_address = 0,
		ram_block11a_16.port_a_first_bit_number = 16,
		ram_block11a_16.port_a_last_address = 511,
		ram_block11a_16.port_a_logical_ram_depth = 512,
		ram_block11a_16.port_a_logical_ram_width = 97,
		ram_block11a_16.port_b_address_clear = "clear1",
		ram_block11a_16.port_b_address_clock = "clock1",
		ram_block11a_16.port_b_address_width = 9,
		ram_block11a_16.port_b_data_out_clear = "none",
		ram_block11a_16.port_b_data_width = 1,
		ram_block11a_16.port_b_first_address = 0,
		ram_block11a_16.port_b_first_bit_number = 16,
		ram_block11a_16.port_b_last_address = 511,
		ram_block11a_16.port_b_logical_ram_depth = 512,
		ram_block11a_16.port_b_logical_ram_width = 97,
		ram_block11a_16.port_b_read_enable_clock = "clock1",
		ram_block11a_16.ram_block_type = "AUTO",
		ram_block11a_16.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_17
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[17]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_17portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_17.clk0_core_clock_enable = "ena0",
		ram_block11a_17.clk0_input_clock_enable = "none",
		ram_block11a_17.clk1_core_clock_enable = "none",
		ram_block11a_17.clk1_input_clock_enable = "none",
		ram_block11a_17.connectivity_checking = "OFF",
		ram_block11a_17.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_17.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_17.operation_mode = "dual_port",
		ram_block11a_17.port_a_address_width = 9,
		ram_block11a_17.port_a_data_width = 1,
		ram_block11a_17.port_a_first_address = 0,
		ram_block11a_17.port_a_first_bit_number = 17,
		ram_block11a_17.port_a_last_address = 511,
		ram_block11a_17.port_a_logical_ram_depth = 512,
		ram_block11a_17.port_a_logical_ram_width = 97,
		ram_block11a_17.port_b_address_clear = "clear1",
		ram_block11a_17.port_b_address_clock = "clock1",
		ram_block11a_17.port_b_address_width = 9,
		ram_block11a_17.port_b_data_out_clear = "none",
		ram_block11a_17.port_b_data_width = 1,
		ram_block11a_17.port_b_first_address = 0,
		ram_block11a_17.port_b_first_bit_number = 17,
		ram_block11a_17.port_b_last_address = 511,
		ram_block11a_17.port_b_logical_ram_depth = 512,
		ram_block11a_17.port_b_logical_ram_width = 97,
		ram_block11a_17.port_b_read_enable_clock = "clock1",
		ram_block11a_17.ram_block_type = "AUTO",
		ram_block11a_17.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_18
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[18]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_18portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_18.clk0_core_clock_enable = "ena0",
		ram_block11a_18.clk0_input_clock_enable = "none",
		ram_block11a_18.clk1_core_clock_enable = "none",
		ram_block11a_18.clk1_input_clock_enable = "none",
		ram_block11a_18.connectivity_checking = "OFF",
		ram_block11a_18.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_18.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_18.operation_mode = "dual_port",
		ram_block11a_18.port_a_address_width = 9,
		ram_block11a_18.port_a_data_width = 1,
		ram_block11a_18.port_a_first_address = 0,
		ram_block11a_18.port_a_first_bit_number = 18,
		ram_block11a_18.port_a_last_address = 511,
		ram_block11a_18.port_a_logical_ram_depth = 512,
		ram_block11a_18.port_a_logical_ram_width = 97,
		ram_block11a_18.port_b_address_clear = "clear1",
		ram_block11a_18.port_b_address_clock = "clock1",
		ram_block11a_18.port_b_address_width = 9,
		ram_block11a_18.port_b_data_out_clear = "none",
		ram_block11a_18.port_b_data_width = 1,
		ram_block11a_18.port_b_first_address = 0,
		ram_block11a_18.port_b_first_bit_number = 18,
		ram_block11a_18.port_b_last_address = 511,
		ram_block11a_18.port_b_logical_ram_depth = 512,
		ram_block11a_18.port_b_logical_ram_width = 97,
		ram_block11a_18.port_b_read_enable_clock = "clock1",
		ram_block11a_18.ram_block_type = "AUTO",
		ram_block11a_18.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_19
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[19]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_19portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_19.clk0_core_clock_enable = "ena0",
		ram_block11a_19.clk0_input_clock_enable = "none",
		ram_block11a_19.clk1_core_clock_enable = "none",
		ram_block11a_19.clk1_input_clock_enable = "none",
		ram_block11a_19.connectivity_checking = "OFF",
		ram_block11a_19.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_19.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_19.operation_mode = "dual_port",
		ram_block11a_19.port_a_address_width = 9,
		ram_block11a_19.port_a_data_width = 1,
		ram_block11a_19.port_a_first_address = 0,
		ram_block11a_19.port_a_first_bit_number = 19,
		ram_block11a_19.port_a_last_address = 511,
		ram_block11a_19.port_a_logical_ram_depth = 512,
		ram_block11a_19.port_a_logical_ram_width = 97,
		ram_block11a_19.port_b_address_clear = "clear1",
		ram_block11a_19.port_b_address_clock = "clock1",
		ram_block11a_19.port_b_address_width = 9,
		ram_block11a_19.port_b_data_out_clear = "none",
		ram_block11a_19.port_b_data_width = 1,
		ram_block11a_19.port_b_first_address = 0,
		ram_block11a_19.port_b_first_bit_number = 19,
		ram_block11a_19.port_b_last_address = 511,
		ram_block11a_19.port_b_logical_ram_depth = 512,
		ram_block11a_19.port_b_logical_ram_width = 97,
		ram_block11a_19.port_b_read_enable_clock = "clock1",
		ram_block11a_19.ram_block_type = "AUTO",
		ram_block11a_19.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_20
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[20]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_20portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_20.clk0_core_clock_enable = "ena0",
		ram_block11a_20.clk0_input_clock_enable = "none",
		ram_block11a_20.clk1_core_clock_enable = "none",
		ram_block11a_20.clk1_input_clock_enable = "none",
		ram_block11a_20.connectivity_checking = "OFF",
		ram_block11a_20.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_20.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_20.operation_mode = "dual_port",
		ram_block11a_20.port_a_address_width = 9,
		ram_block11a_20.port_a_data_width = 1,
		ram_block11a_20.port_a_first_address = 0,
		ram_block11a_20.port_a_first_bit_number = 20,
		ram_block11a_20.port_a_last_address = 511,
		ram_block11a_20.port_a_logical_ram_depth = 512,
		ram_block11a_20.port_a_logical_ram_width = 97,
		ram_block11a_20.port_b_address_clear = "clear1",
		ram_block11a_20.port_b_address_clock = "clock1",
		ram_block11a_20.port_b_address_width = 9,
		ram_block11a_20.port_b_data_out_clear = "none",
		ram_block11a_20.port_b_data_width = 1,
		ram_block11a_20.port_b_first_address = 0,
		ram_block11a_20.port_b_first_bit_number = 20,
		ram_block11a_20.port_b_last_address = 511,
		ram_block11a_20.port_b_logical_ram_depth = 512,
		ram_block11a_20.port_b_logical_ram_width = 97,
		ram_block11a_20.port_b_read_enable_clock = "clock1",
		ram_block11a_20.ram_block_type = "AUTO",
		ram_block11a_20.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_21
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[21]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_21portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_21.clk0_core_clock_enable = "ena0",
		ram_block11a_21.clk0_input_clock_enable = "none",
		ram_block11a_21.clk1_core_clock_enable = "none",
		ram_block11a_21.clk1_input_clock_enable = "none",
		ram_block11a_21.connectivity_checking = "OFF",
		ram_block11a_21.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_21.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_21.operation_mode = "dual_port",
		ram_block11a_21.port_a_address_width = 9,
		ram_block11a_21.port_a_data_width = 1,
		ram_block11a_21.port_a_first_address = 0,
		ram_block11a_21.port_a_first_bit_number = 21,
		ram_block11a_21.port_a_last_address = 511,
		ram_block11a_21.port_a_logical_ram_depth = 512,
		ram_block11a_21.port_a_logical_ram_width = 97,
		ram_block11a_21.port_b_address_clear = "clear1",
		ram_block11a_21.port_b_address_clock = "clock1",
		ram_block11a_21.port_b_address_width = 9,
		ram_block11a_21.port_b_data_out_clear = "none",
		ram_block11a_21.port_b_data_width = 1,
		ram_block11a_21.port_b_first_address = 0,
		ram_block11a_21.port_b_first_bit_number = 21,
		ram_block11a_21.port_b_last_address = 511,
		ram_block11a_21.port_b_logical_ram_depth = 512,
		ram_block11a_21.port_b_logical_ram_width = 97,
		ram_block11a_21.port_b_read_enable_clock = "clock1",
		ram_block11a_21.ram_block_type = "AUTO",
		ram_block11a_21.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_22
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[22]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_22portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_22.clk0_core_clock_enable = "ena0",
		ram_block11a_22.clk0_input_clock_enable = "none",
		ram_block11a_22.clk1_core_clock_enable = "none",
		ram_block11a_22.clk1_input_clock_enable = "none",
		ram_block11a_22.connectivity_checking = "OFF",
		ram_block11a_22.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_22.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_22.operation_mode = "dual_port",
		ram_block11a_22.port_a_address_width = 9,
		ram_block11a_22.port_a_data_width = 1,
		ram_block11a_22.port_a_first_address = 0,
		ram_block11a_22.port_a_first_bit_number = 22,
		ram_block11a_22.port_a_last_address = 511,
		ram_block11a_22.port_a_logical_ram_depth = 512,
		ram_block11a_22.port_a_logical_ram_width = 97,
		ram_block11a_22.port_b_address_clear = "clear1",
		ram_block11a_22.port_b_address_clock = "clock1",
		ram_block11a_22.port_b_address_width = 9,
		ram_block11a_22.port_b_data_out_clear = "none",
		ram_block11a_22.port_b_data_width = 1,
		ram_block11a_22.port_b_first_address = 0,
		ram_block11a_22.port_b_first_bit_number = 22,
		ram_block11a_22.port_b_last_address = 511,
		ram_block11a_22.port_b_logical_ram_depth = 512,
		ram_block11a_22.port_b_logical_ram_width = 97,
		ram_block11a_22.port_b_read_enable_clock = "clock1",
		ram_block11a_22.ram_block_type = "AUTO",
		ram_block11a_22.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_23
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[23]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_23portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_23.clk0_core_clock_enable = "ena0",
		ram_block11a_23.clk0_input_clock_enable = "none",
		ram_block11a_23.clk1_core_clock_enable = "none",
		ram_block11a_23.clk1_input_clock_enable = "none",
		ram_block11a_23.connectivity_checking = "OFF",
		ram_block11a_23.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_23.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_23.operation_mode = "dual_port",
		ram_block11a_23.port_a_address_width = 9,
		ram_block11a_23.port_a_data_width = 1,
		ram_block11a_23.port_a_first_address = 0,
		ram_block11a_23.port_a_first_bit_number = 23,
		ram_block11a_23.port_a_last_address = 511,
		ram_block11a_23.port_a_logical_ram_depth = 512,
		ram_block11a_23.port_a_logical_ram_width = 97,
		ram_block11a_23.port_b_address_clear = "clear1",
		ram_block11a_23.port_b_address_clock = "clock1",
		ram_block11a_23.port_b_address_width = 9,
		ram_block11a_23.port_b_data_out_clear = "none",
		ram_block11a_23.port_b_data_width = 1,
		ram_block11a_23.port_b_first_address = 0,
		ram_block11a_23.port_b_first_bit_number = 23,
		ram_block11a_23.port_b_last_address = 511,
		ram_block11a_23.port_b_logical_ram_depth = 512,
		ram_block11a_23.port_b_logical_ram_width = 97,
		ram_block11a_23.port_b_read_enable_clock = "clock1",
		ram_block11a_23.ram_block_type = "AUTO",
		ram_block11a_23.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_24
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[24]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_24portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_24.clk0_core_clock_enable = "ena0",
		ram_block11a_24.clk0_input_clock_enable = "none",
		ram_block11a_24.clk1_core_clock_enable = "none",
		ram_block11a_24.clk1_input_clock_enable = "none",
		ram_block11a_24.connectivity_checking = "OFF",
		ram_block11a_24.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_24.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_24.operation_mode = "dual_port",
		ram_block11a_24.port_a_address_width = 9,
		ram_block11a_24.port_a_data_width = 1,
		ram_block11a_24.port_a_first_address = 0,
		ram_block11a_24.port_a_first_bit_number = 24,
		ram_block11a_24.port_a_last_address = 511,
		ram_block11a_24.port_a_logical_ram_depth = 512,
		ram_block11a_24.port_a_logical_ram_width = 97,
		ram_block11a_24.port_b_address_clear = "clear1",
		ram_block11a_24.port_b_address_clock = "clock1",
		ram_block11a_24.port_b_address_width = 9,
		ram_block11a_24.port_b_data_out_clear = "none",
		ram_block11a_24.port_b_data_width = 1,
		ram_block11a_24.port_b_first_address = 0,
		ram_block11a_24.port_b_first_bit_number = 24,
		ram_block11a_24.port_b_last_address = 511,
		ram_block11a_24.port_b_logical_ram_depth = 512,
		ram_block11a_24.port_b_logical_ram_width = 97,
		ram_block11a_24.port_b_read_enable_clock = "clock1",
		ram_block11a_24.ram_block_type = "AUTO",
		ram_block11a_24.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_25
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[25]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_25portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_25.clk0_core_clock_enable = "ena0",
		ram_block11a_25.clk0_input_clock_enable = "none",
		ram_block11a_25.clk1_core_clock_enable = "none",
		ram_block11a_25.clk1_input_clock_enable = "none",
		ram_block11a_25.connectivity_checking = "OFF",
		ram_block11a_25.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_25.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_25.operation_mode = "dual_port",
		ram_block11a_25.port_a_address_width = 9,
		ram_block11a_25.port_a_data_width = 1,
		ram_block11a_25.port_a_first_address = 0,
		ram_block11a_25.port_a_first_bit_number = 25,
		ram_block11a_25.port_a_last_address = 511,
		ram_block11a_25.port_a_logical_ram_depth = 512,
		ram_block11a_25.port_a_logical_ram_width = 97,
		ram_block11a_25.port_b_address_clear = "clear1",
		ram_block11a_25.port_b_address_clock = "clock1",
		ram_block11a_25.port_b_address_width = 9,
		ram_block11a_25.port_b_data_out_clear = "none",
		ram_block11a_25.port_b_data_width = 1,
		ram_block11a_25.port_b_first_address = 0,
		ram_block11a_25.port_b_first_bit_number = 25,
		ram_block11a_25.port_b_last_address = 511,
		ram_block11a_25.port_b_logical_ram_depth = 512,
		ram_block11a_25.port_b_logical_ram_width = 97,
		ram_block11a_25.port_b_read_enable_clock = "clock1",
		ram_block11a_25.ram_block_type = "AUTO",
		ram_block11a_25.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_26
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[26]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_26portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_26.clk0_core_clock_enable = "ena0",
		ram_block11a_26.clk0_input_clock_enable = "none",
		ram_block11a_26.clk1_core_clock_enable = "none",
		ram_block11a_26.clk1_input_clock_enable = "none",
		ram_block11a_26.connectivity_checking = "OFF",
		ram_block11a_26.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_26.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_26.operation_mode = "dual_port",
		ram_block11a_26.port_a_address_width = 9,
		ram_block11a_26.port_a_data_width = 1,
		ram_block11a_26.port_a_first_address = 0,
		ram_block11a_26.port_a_first_bit_number = 26,
		ram_block11a_26.port_a_last_address = 511,
		ram_block11a_26.port_a_logical_ram_depth = 512,
		ram_block11a_26.port_a_logical_ram_width = 97,
		ram_block11a_26.port_b_address_clear = "clear1",
		ram_block11a_26.port_b_address_clock = "clock1",
		ram_block11a_26.port_b_address_width = 9,
		ram_block11a_26.port_b_data_out_clear = "none",
		ram_block11a_26.port_b_data_width = 1,
		ram_block11a_26.port_b_first_address = 0,
		ram_block11a_26.port_b_first_bit_number = 26,
		ram_block11a_26.port_b_last_address = 511,
		ram_block11a_26.port_b_logical_ram_depth = 512,
		ram_block11a_26.port_b_logical_ram_width = 97,
		ram_block11a_26.port_b_read_enable_clock = "clock1",
		ram_block11a_26.ram_block_type = "AUTO",
		ram_block11a_26.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_27
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[27]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_27portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_27.clk0_core_clock_enable = "ena0",
		ram_block11a_27.clk0_input_clock_enable = "none",
		ram_block11a_27.clk1_core_clock_enable = "none",
		ram_block11a_27.clk1_input_clock_enable = "none",
		ram_block11a_27.connectivity_checking = "OFF",
		ram_block11a_27.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_27.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_27.operation_mode = "dual_port",
		ram_block11a_27.port_a_address_width = 9,
		ram_block11a_27.port_a_data_width = 1,
		ram_block11a_27.port_a_first_address = 0,
		ram_block11a_27.port_a_first_bit_number = 27,
		ram_block11a_27.port_a_last_address = 511,
		ram_block11a_27.port_a_logical_ram_depth = 512,
		ram_block11a_27.port_a_logical_ram_width = 97,
		ram_block11a_27.port_b_address_clear = "clear1",
		ram_block11a_27.port_b_address_clock = "clock1",
		ram_block11a_27.port_b_address_width = 9,
		ram_block11a_27.port_b_data_out_clear = "none",
		ram_block11a_27.port_b_data_width = 1,
		ram_block11a_27.port_b_first_address = 0,
		ram_block11a_27.port_b_first_bit_number = 27,
		ram_block11a_27.port_b_last_address = 511,
		ram_block11a_27.port_b_logical_ram_depth = 512,
		ram_block11a_27.port_b_logical_ram_width = 97,
		ram_block11a_27.port_b_read_enable_clock = "clock1",
		ram_block11a_27.ram_block_type = "AUTO",
		ram_block11a_27.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_28
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[28]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_28portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_28.clk0_core_clock_enable = "ena0",
		ram_block11a_28.clk0_input_clock_enable = "none",
		ram_block11a_28.clk1_core_clock_enable = "none",
		ram_block11a_28.clk1_input_clock_enable = "none",
		ram_block11a_28.connectivity_checking = "OFF",
		ram_block11a_28.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_28.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_28.operation_mode = "dual_port",
		ram_block11a_28.port_a_address_width = 9,
		ram_block11a_28.port_a_data_width = 1,
		ram_block11a_28.port_a_first_address = 0,
		ram_block11a_28.port_a_first_bit_number = 28,
		ram_block11a_28.port_a_last_address = 511,
		ram_block11a_28.port_a_logical_ram_depth = 512,
		ram_block11a_28.port_a_logical_ram_width = 97,
		ram_block11a_28.port_b_address_clear = "clear1",
		ram_block11a_28.port_b_address_clock = "clock1",
		ram_block11a_28.port_b_address_width = 9,
		ram_block11a_28.port_b_data_out_clear = "none",
		ram_block11a_28.port_b_data_width = 1,
		ram_block11a_28.port_b_first_address = 0,
		ram_block11a_28.port_b_first_bit_number = 28,
		ram_block11a_28.port_b_last_address = 511,
		ram_block11a_28.port_b_logical_ram_depth = 512,
		ram_block11a_28.port_b_logical_ram_width = 97,
		ram_block11a_28.port_b_read_enable_clock = "clock1",
		ram_block11a_28.ram_block_type = "AUTO",
		ram_block11a_28.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_29
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[29]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_29portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_29.clk0_core_clock_enable = "ena0",
		ram_block11a_29.clk0_input_clock_enable = "none",
		ram_block11a_29.clk1_core_clock_enable = "none",
		ram_block11a_29.clk1_input_clock_enable = "none",
		ram_block11a_29.connectivity_checking = "OFF",
		ram_block11a_29.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_29.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_29.operation_mode = "dual_port",
		ram_block11a_29.port_a_address_width = 9,
		ram_block11a_29.port_a_data_width = 1,
		ram_block11a_29.port_a_first_address = 0,
		ram_block11a_29.port_a_first_bit_number = 29,
		ram_block11a_29.port_a_last_address = 511,
		ram_block11a_29.port_a_logical_ram_depth = 512,
		ram_block11a_29.port_a_logical_ram_width = 97,
		ram_block11a_29.port_b_address_clear = "clear1",
		ram_block11a_29.port_b_address_clock = "clock1",
		ram_block11a_29.port_b_address_width = 9,
		ram_block11a_29.port_b_data_out_clear = "none",
		ram_block11a_29.port_b_data_width = 1,
		ram_block11a_29.port_b_first_address = 0,
		ram_block11a_29.port_b_first_bit_number = 29,
		ram_block11a_29.port_b_last_address = 511,
		ram_block11a_29.port_b_logical_ram_depth = 512,
		ram_block11a_29.port_b_logical_ram_width = 97,
		ram_block11a_29.port_b_read_enable_clock = "clock1",
		ram_block11a_29.ram_block_type = "AUTO",
		ram_block11a_29.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_30
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[30]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_30portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_30.clk0_core_clock_enable = "ena0",
		ram_block11a_30.clk0_input_clock_enable = "none",
		ram_block11a_30.clk1_core_clock_enable = "none",
		ram_block11a_30.clk1_input_clock_enable = "none",
		ram_block11a_30.connectivity_checking = "OFF",
		ram_block11a_30.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_30.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_30.operation_mode = "dual_port",
		ram_block11a_30.port_a_address_width = 9,
		ram_block11a_30.port_a_data_width = 1,
		ram_block11a_30.port_a_first_address = 0,
		ram_block11a_30.port_a_first_bit_number = 30,
		ram_block11a_30.port_a_last_address = 511,
		ram_block11a_30.port_a_logical_ram_depth = 512,
		ram_block11a_30.port_a_logical_ram_width = 97,
		ram_block11a_30.port_b_address_clear = "clear1",
		ram_block11a_30.port_b_address_clock = "clock1",
		ram_block11a_30.port_b_address_width = 9,
		ram_block11a_30.port_b_data_out_clear = "none",
		ram_block11a_30.port_b_data_width = 1,
		ram_block11a_30.port_b_first_address = 0,
		ram_block11a_30.port_b_first_bit_number = 30,
		ram_block11a_30.port_b_last_address = 511,
		ram_block11a_30.port_b_logical_ram_depth = 512,
		ram_block11a_30.port_b_logical_ram_width = 97,
		ram_block11a_30.port_b_read_enable_clock = "clock1",
		ram_block11a_30.ram_block_type = "AUTO",
		ram_block11a_30.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_31
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[31]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_31portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_31.clk0_core_clock_enable = "ena0",
		ram_block11a_31.clk0_input_clock_enable = "none",
		ram_block11a_31.clk1_core_clock_enable = "none",
		ram_block11a_31.clk1_input_clock_enable = "none",
		ram_block11a_31.connectivity_checking = "OFF",
		ram_block11a_31.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_31.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_31.operation_mode = "dual_port",
		ram_block11a_31.port_a_address_width = 9,
		ram_block11a_31.port_a_data_width = 1,
		ram_block11a_31.port_a_first_address = 0,
		ram_block11a_31.port_a_first_bit_number = 31,
		ram_block11a_31.port_a_last_address = 511,
		ram_block11a_31.port_a_logical_ram_depth = 512,
		ram_block11a_31.port_a_logical_ram_width = 97,
		ram_block11a_31.port_b_address_clear = "clear1",
		ram_block11a_31.port_b_address_clock = "clock1",
		ram_block11a_31.port_b_address_width = 9,
		ram_block11a_31.port_b_data_out_clear = "none",
		ram_block11a_31.port_b_data_width = 1,
		ram_block11a_31.port_b_first_address = 0,
		ram_block11a_31.port_b_first_bit_number = 31,
		ram_block11a_31.port_b_last_address = 511,
		ram_block11a_31.port_b_logical_ram_depth = 512,
		ram_block11a_31.port_b_logical_ram_width = 97,
		ram_block11a_31.port_b_read_enable_clock = "clock1",
		ram_block11a_31.ram_block_type = "AUTO",
		ram_block11a_31.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_32
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[32]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_32portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_32.clk0_core_clock_enable = "ena0",
		ram_block11a_32.clk0_input_clock_enable = "none",
		ram_block11a_32.clk1_core_clock_enable = "none",
		ram_block11a_32.clk1_input_clock_enable = "none",
		ram_block11a_32.connectivity_checking = "OFF",
		ram_block11a_32.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_32.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_32.operation_mode = "dual_port",
		ram_block11a_32.port_a_address_width = 9,
		ram_block11a_32.port_a_data_width = 1,
		ram_block11a_32.port_a_first_address = 0,
		ram_block11a_32.port_a_first_bit_number = 32,
		ram_block11a_32.port_a_last_address = 511,
		ram_block11a_32.port_a_logical_ram_depth = 512,
		ram_block11a_32.port_a_logical_ram_width = 97,
		ram_block11a_32.port_b_address_clear = "clear1",
		ram_block11a_32.port_b_address_clock = "clock1",
		ram_block11a_32.port_b_address_width = 9,
		ram_block11a_32.port_b_data_out_clear = "none",
		ram_block11a_32.port_b_data_width = 1,
		ram_block11a_32.port_b_first_address = 0,
		ram_block11a_32.port_b_first_bit_number = 32,
		ram_block11a_32.port_b_last_address = 511,
		ram_block11a_32.port_b_logical_ram_depth = 512,
		ram_block11a_32.port_b_logical_ram_width = 97,
		ram_block11a_32.port_b_read_enable_clock = "clock1",
		ram_block11a_32.ram_block_type = "AUTO",
		ram_block11a_32.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_33
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[33]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_33portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_33.clk0_core_clock_enable = "ena0",
		ram_block11a_33.clk0_input_clock_enable = "none",
		ram_block11a_33.clk1_core_clock_enable = "none",
		ram_block11a_33.clk1_input_clock_enable = "none",
		ram_block11a_33.connectivity_checking = "OFF",
		ram_block11a_33.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_33.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_33.operation_mode = "dual_port",
		ram_block11a_33.port_a_address_width = 9,
		ram_block11a_33.port_a_data_width = 1,
		ram_block11a_33.port_a_first_address = 0,
		ram_block11a_33.port_a_first_bit_number = 33,
		ram_block11a_33.port_a_last_address = 511,
		ram_block11a_33.port_a_logical_ram_depth = 512,
		ram_block11a_33.port_a_logical_ram_width = 97,
		ram_block11a_33.port_b_address_clear = "clear1",
		ram_block11a_33.port_b_address_clock = "clock1",
		ram_block11a_33.port_b_address_width = 9,
		ram_block11a_33.port_b_data_out_clear = "none",
		ram_block11a_33.port_b_data_width = 1,
		ram_block11a_33.port_b_first_address = 0,
		ram_block11a_33.port_b_first_bit_number = 33,
		ram_block11a_33.port_b_last_address = 511,
		ram_block11a_33.port_b_logical_ram_depth = 512,
		ram_block11a_33.port_b_logical_ram_width = 97,
		ram_block11a_33.port_b_read_enable_clock = "clock1",
		ram_block11a_33.ram_block_type = "AUTO",
		ram_block11a_33.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_34
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[34]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_34portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_34.clk0_core_clock_enable = "ena0",
		ram_block11a_34.clk0_input_clock_enable = "none",
		ram_block11a_34.clk1_core_clock_enable = "none",
		ram_block11a_34.clk1_input_clock_enable = "none",
		ram_block11a_34.connectivity_checking = "OFF",
		ram_block11a_34.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_34.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_34.operation_mode = "dual_port",
		ram_block11a_34.port_a_address_width = 9,
		ram_block11a_34.port_a_data_width = 1,
		ram_block11a_34.port_a_first_address = 0,
		ram_block11a_34.port_a_first_bit_number = 34,
		ram_block11a_34.port_a_last_address = 511,
		ram_block11a_34.port_a_logical_ram_depth = 512,
		ram_block11a_34.port_a_logical_ram_width = 97,
		ram_block11a_34.port_b_address_clear = "clear1",
		ram_block11a_34.port_b_address_clock = "clock1",
		ram_block11a_34.port_b_address_width = 9,
		ram_block11a_34.port_b_data_out_clear = "none",
		ram_block11a_34.port_b_data_width = 1,
		ram_block11a_34.port_b_first_address = 0,
		ram_block11a_34.port_b_first_bit_number = 34,
		ram_block11a_34.port_b_last_address = 511,
		ram_block11a_34.port_b_logical_ram_depth = 512,
		ram_block11a_34.port_b_logical_ram_width = 97,
		ram_block11a_34.port_b_read_enable_clock = "clock1",
		ram_block11a_34.ram_block_type = "AUTO",
		ram_block11a_34.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_35
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[35]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_35portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_35.clk0_core_clock_enable = "ena0",
		ram_block11a_35.clk0_input_clock_enable = "none",
		ram_block11a_35.clk1_core_clock_enable = "none",
		ram_block11a_35.clk1_input_clock_enable = "none",
		ram_block11a_35.connectivity_checking = "OFF",
		ram_block11a_35.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_35.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_35.operation_mode = "dual_port",
		ram_block11a_35.port_a_address_width = 9,
		ram_block11a_35.port_a_data_width = 1,
		ram_block11a_35.port_a_first_address = 0,
		ram_block11a_35.port_a_first_bit_number = 35,
		ram_block11a_35.port_a_last_address = 511,
		ram_block11a_35.port_a_logical_ram_depth = 512,
		ram_block11a_35.port_a_logical_ram_width = 97,
		ram_block11a_35.port_b_address_clear = "clear1",
		ram_block11a_35.port_b_address_clock = "clock1",
		ram_block11a_35.port_b_address_width = 9,
		ram_block11a_35.port_b_data_out_clear = "none",
		ram_block11a_35.port_b_data_width = 1,
		ram_block11a_35.port_b_first_address = 0,
		ram_block11a_35.port_b_first_bit_number = 35,
		ram_block11a_35.port_b_last_address = 511,
		ram_block11a_35.port_b_logical_ram_depth = 512,
		ram_block11a_35.port_b_logical_ram_width = 97,
		ram_block11a_35.port_b_read_enable_clock = "clock1",
		ram_block11a_35.ram_block_type = "AUTO",
		ram_block11a_35.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_36
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[36]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_36portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_36.clk0_core_clock_enable = "ena0",
		ram_block11a_36.clk0_input_clock_enable = "none",
		ram_block11a_36.clk1_core_clock_enable = "none",
		ram_block11a_36.clk1_input_clock_enable = "none",
		ram_block11a_36.connectivity_checking = "OFF",
		ram_block11a_36.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_36.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_36.operation_mode = "dual_port",
		ram_block11a_36.port_a_address_width = 9,
		ram_block11a_36.port_a_data_width = 1,
		ram_block11a_36.port_a_first_address = 0,
		ram_block11a_36.port_a_first_bit_number = 36,
		ram_block11a_36.port_a_last_address = 511,
		ram_block11a_36.port_a_logical_ram_depth = 512,
		ram_block11a_36.port_a_logical_ram_width = 97,
		ram_block11a_36.port_b_address_clear = "clear1",
		ram_block11a_36.port_b_address_clock = "clock1",
		ram_block11a_36.port_b_address_width = 9,
		ram_block11a_36.port_b_data_out_clear = "none",
		ram_block11a_36.port_b_data_width = 1,
		ram_block11a_36.port_b_first_address = 0,
		ram_block11a_36.port_b_first_bit_number = 36,
		ram_block11a_36.port_b_last_address = 511,
		ram_block11a_36.port_b_logical_ram_depth = 512,
		ram_block11a_36.port_b_logical_ram_width = 97,
		ram_block11a_36.port_b_read_enable_clock = "clock1",
		ram_block11a_36.ram_block_type = "AUTO",
		ram_block11a_36.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_37
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[37]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_37portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_37.clk0_core_clock_enable = "ena0",
		ram_block11a_37.clk0_input_clock_enable = "none",
		ram_block11a_37.clk1_core_clock_enable = "none",
		ram_block11a_37.clk1_input_clock_enable = "none",
		ram_block11a_37.connectivity_checking = "OFF",
		ram_block11a_37.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_37.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_37.operation_mode = "dual_port",
		ram_block11a_37.port_a_address_width = 9,
		ram_block11a_37.port_a_data_width = 1,
		ram_block11a_37.port_a_first_address = 0,
		ram_block11a_37.port_a_first_bit_number = 37,
		ram_block11a_37.port_a_last_address = 511,
		ram_block11a_37.port_a_logical_ram_depth = 512,
		ram_block11a_37.port_a_logical_ram_width = 97,
		ram_block11a_37.port_b_address_clear = "clear1",
		ram_block11a_37.port_b_address_clock = "clock1",
		ram_block11a_37.port_b_address_width = 9,
		ram_block11a_37.port_b_data_out_clear = "none",
		ram_block11a_37.port_b_data_width = 1,
		ram_block11a_37.port_b_first_address = 0,
		ram_block11a_37.port_b_first_bit_number = 37,
		ram_block11a_37.port_b_last_address = 511,
		ram_block11a_37.port_b_logical_ram_depth = 512,
		ram_block11a_37.port_b_logical_ram_width = 97,
		ram_block11a_37.port_b_read_enable_clock = "clock1",
		ram_block11a_37.ram_block_type = "AUTO",
		ram_block11a_37.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_38
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[38]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_38portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_38.clk0_core_clock_enable = "ena0",
		ram_block11a_38.clk0_input_clock_enable = "none",
		ram_block11a_38.clk1_core_clock_enable = "none",
		ram_block11a_38.clk1_input_clock_enable = "none",
		ram_block11a_38.connectivity_checking = "OFF",
		ram_block11a_38.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_38.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_38.operation_mode = "dual_port",
		ram_block11a_38.port_a_address_width = 9,
		ram_block11a_38.port_a_data_width = 1,
		ram_block11a_38.port_a_first_address = 0,
		ram_block11a_38.port_a_first_bit_number = 38,
		ram_block11a_38.port_a_last_address = 511,
		ram_block11a_38.port_a_logical_ram_depth = 512,
		ram_block11a_38.port_a_logical_ram_width = 97,
		ram_block11a_38.port_b_address_clear = "clear1",
		ram_block11a_38.port_b_address_clock = "clock1",
		ram_block11a_38.port_b_address_width = 9,
		ram_block11a_38.port_b_data_out_clear = "none",
		ram_block11a_38.port_b_data_width = 1,
		ram_block11a_38.port_b_first_address = 0,
		ram_block11a_38.port_b_first_bit_number = 38,
		ram_block11a_38.port_b_last_address = 511,
		ram_block11a_38.port_b_logical_ram_depth = 512,
		ram_block11a_38.port_b_logical_ram_width = 97,
		ram_block11a_38.port_b_read_enable_clock = "clock1",
		ram_block11a_38.ram_block_type = "AUTO",
		ram_block11a_38.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_39
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[39]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_39portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_39.clk0_core_clock_enable = "ena0",
		ram_block11a_39.clk0_input_clock_enable = "none",
		ram_block11a_39.clk1_core_clock_enable = "none",
		ram_block11a_39.clk1_input_clock_enable = "none",
		ram_block11a_39.connectivity_checking = "OFF",
		ram_block11a_39.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_39.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_39.operation_mode = "dual_port",
		ram_block11a_39.port_a_address_width = 9,
		ram_block11a_39.port_a_data_width = 1,
		ram_block11a_39.port_a_first_address = 0,
		ram_block11a_39.port_a_first_bit_number = 39,
		ram_block11a_39.port_a_last_address = 511,
		ram_block11a_39.port_a_logical_ram_depth = 512,
		ram_block11a_39.port_a_logical_ram_width = 97,
		ram_block11a_39.port_b_address_clear = "clear1",
		ram_block11a_39.port_b_address_clock = "clock1",
		ram_block11a_39.port_b_address_width = 9,
		ram_block11a_39.port_b_data_out_clear = "none",
		ram_block11a_39.port_b_data_width = 1,
		ram_block11a_39.port_b_first_address = 0,
		ram_block11a_39.port_b_first_bit_number = 39,
		ram_block11a_39.port_b_last_address = 511,
		ram_block11a_39.port_b_logical_ram_depth = 512,
		ram_block11a_39.port_b_logical_ram_width = 97,
		ram_block11a_39.port_b_read_enable_clock = "clock1",
		ram_block11a_39.ram_block_type = "AUTO",
		ram_block11a_39.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_40
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[40]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_40portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_40.clk0_core_clock_enable = "ena0",
		ram_block11a_40.clk0_input_clock_enable = "none",
		ram_block11a_40.clk1_core_clock_enable = "none",
		ram_block11a_40.clk1_input_clock_enable = "none",
		ram_block11a_40.connectivity_checking = "OFF",
		ram_block11a_40.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_40.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_40.operation_mode = "dual_port",
		ram_block11a_40.port_a_address_width = 9,
		ram_block11a_40.port_a_data_width = 1,
		ram_block11a_40.port_a_first_address = 0,
		ram_block11a_40.port_a_first_bit_number = 40,
		ram_block11a_40.port_a_last_address = 511,
		ram_block11a_40.port_a_logical_ram_depth = 512,
		ram_block11a_40.port_a_logical_ram_width = 97,
		ram_block11a_40.port_b_address_clear = "clear1",
		ram_block11a_40.port_b_address_clock = "clock1",
		ram_block11a_40.port_b_address_width = 9,
		ram_block11a_40.port_b_data_out_clear = "none",
		ram_block11a_40.port_b_data_width = 1,
		ram_block11a_40.port_b_first_address = 0,
		ram_block11a_40.port_b_first_bit_number = 40,
		ram_block11a_40.port_b_last_address = 511,
		ram_block11a_40.port_b_logical_ram_depth = 512,
		ram_block11a_40.port_b_logical_ram_width = 97,
		ram_block11a_40.port_b_read_enable_clock = "clock1",
		ram_block11a_40.ram_block_type = "AUTO",
		ram_block11a_40.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_41
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[41]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_41portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_41.clk0_core_clock_enable = "ena0",
		ram_block11a_41.clk0_input_clock_enable = "none",
		ram_block11a_41.clk1_core_clock_enable = "none",
		ram_block11a_41.clk1_input_clock_enable = "none",
		ram_block11a_41.connectivity_checking = "OFF",
		ram_block11a_41.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_41.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_41.operation_mode = "dual_port",
		ram_block11a_41.port_a_address_width = 9,
		ram_block11a_41.port_a_data_width = 1,
		ram_block11a_41.port_a_first_address = 0,
		ram_block11a_41.port_a_first_bit_number = 41,
		ram_block11a_41.port_a_last_address = 511,
		ram_block11a_41.port_a_logical_ram_depth = 512,
		ram_block11a_41.port_a_logical_ram_width = 97,
		ram_block11a_41.port_b_address_clear = "clear1",
		ram_block11a_41.port_b_address_clock = "clock1",
		ram_block11a_41.port_b_address_width = 9,
		ram_block11a_41.port_b_data_out_clear = "none",
		ram_block11a_41.port_b_data_width = 1,
		ram_block11a_41.port_b_first_address = 0,
		ram_block11a_41.port_b_first_bit_number = 41,
		ram_block11a_41.port_b_last_address = 511,
		ram_block11a_41.port_b_logical_ram_depth = 512,
		ram_block11a_41.port_b_logical_ram_width = 97,
		ram_block11a_41.port_b_read_enable_clock = "clock1",
		ram_block11a_41.ram_block_type = "AUTO",
		ram_block11a_41.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_42
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[42]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_42portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_42.clk0_core_clock_enable = "ena0",
		ram_block11a_42.clk0_input_clock_enable = "none",
		ram_block11a_42.clk1_core_clock_enable = "none",
		ram_block11a_42.clk1_input_clock_enable = "none",
		ram_block11a_42.connectivity_checking = "OFF",
		ram_block11a_42.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_42.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_42.operation_mode = "dual_port",
		ram_block11a_42.port_a_address_width = 9,
		ram_block11a_42.port_a_data_width = 1,
		ram_block11a_42.port_a_first_address = 0,
		ram_block11a_42.port_a_first_bit_number = 42,
		ram_block11a_42.port_a_last_address = 511,
		ram_block11a_42.port_a_logical_ram_depth = 512,
		ram_block11a_42.port_a_logical_ram_width = 97,
		ram_block11a_42.port_b_address_clear = "clear1",
		ram_block11a_42.port_b_address_clock = "clock1",
		ram_block11a_42.port_b_address_width = 9,
		ram_block11a_42.port_b_data_out_clear = "none",
		ram_block11a_42.port_b_data_width = 1,
		ram_block11a_42.port_b_first_address = 0,
		ram_block11a_42.port_b_first_bit_number = 42,
		ram_block11a_42.port_b_last_address = 511,
		ram_block11a_42.port_b_logical_ram_depth = 512,
		ram_block11a_42.port_b_logical_ram_width = 97,
		ram_block11a_42.port_b_read_enable_clock = "clock1",
		ram_block11a_42.ram_block_type = "AUTO",
		ram_block11a_42.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_43
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[43]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_43portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_43.clk0_core_clock_enable = "ena0",
		ram_block11a_43.clk0_input_clock_enable = "none",
		ram_block11a_43.clk1_core_clock_enable = "none",
		ram_block11a_43.clk1_input_clock_enable = "none",
		ram_block11a_43.connectivity_checking = "OFF",
		ram_block11a_43.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_43.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_43.operation_mode = "dual_port",
		ram_block11a_43.port_a_address_width = 9,
		ram_block11a_43.port_a_data_width = 1,
		ram_block11a_43.port_a_first_address = 0,
		ram_block11a_43.port_a_first_bit_number = 43,
		ram_block11a_43.port_a_last_address = 511,
		ram_block11a_43.port_a_logical_ram_depth = 512,
		ram_block11a_43.port_a_logical_ram_width = 97,
		ram_block11a_43.port_b_address_clear = "clear1",
		ram_block11a_43.port_b_address_clock = "clock1",
		ram_block11a_43.port_b_address_width = 9,
		ram_block11a_43.port_b_data_out_clear = "none",
		ram_block11a_43.port_b_data_width = 1,
		ram_block11a_43.port_b_first_address = 0,
		ram_block11a_43.port_b_first_bit_number = 43,
		ram_block11a_43.port_b_last_address = 511,
		ram_block11a_43.port_b_logical_ram_depth = 512,
		ram_block11a_43.port_b_logical_ram_width = 97,
		ram_block11a_43.port_b_read_enable_clock = "clock1",
		ram_block11a_43.ram_block_type = "AUTO",
		ram_block11a_43.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_44
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[44]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_44portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_44.clk0_core_clock_enable = "ena0",
		ram_block11a_44.clk0_input_clock_enable = "none",
		ram_block11a_44.clk1_core_clock_enable = "none",
		ram_block11a_44.clk1_input_clock_enable = "none",
		ram_block11a_44.connectivity_checking = "OFF",
		ram_block11a_44.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_44.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_44.operation_mode = "dual_port",
		ram_block11a_44.port_a_address_width = 9,
		ram_block11a_44.port_a_data_width = 1,
		ram_block11a_44.port_a_first_address = 0,
		ram_block11a_44.port_a_first_bit_number = 44,
		ram_block11a_44.port_a_last_address = 511,
		ram_block11a_44.port_a_logical_ram_depth = 512,
		ram_block11a_44.port_a_logical_ram_width = 97,
		ram_block11a_44.port_b_address_clear = "clear1",
		ram_block11a_44.port_b_address_clock = "clock1",
		ram_block11a_44.port_b_address_width = 9,
		ram_block11a_44.port_b_data_out_clear = "none",
		ram_block11a_44.port_b_data_width = 1,
		ram_block11a_44.port_b_first_address = 0,
		ram_block11a_44.port_b_first_bit_number = 44,
		ram_block11a_44.port_b_last_address = 511,
		ram_block11a_44.port_b_logical_ram_depth = 512,
		ram_block11a_44.port_b_logical_ram_width = 97,
		ram_block11a_44.port_b_read_enable_clock = "clock1",
		ram_block11a_44.ram_block_type = "AUTO",
		ram_block11a_44.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_45
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[45]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_45portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_45.clk0_core_clock_enable = "ena0",
		ram_block11a_45.clk0_input_clock_enable = "none",
		ram_block11a_45.clk1_core_clock_enable = "none",
		ram_block11a_45.clk1_input_clock_enable = "none",
		ram_block11a_45.connectivity_checking = "OFF",
		ram_block11a_45.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_45.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_45.operation_mode = "dual_port",
		ram_block11a_45.port_a_address_width = 9,
		ram_block11a_45.port_a_data_width = 1,
		ram_block11a_45.port_a_first_address = 0,
		ram_block11a_45.port_a_first_bit_number = 45,
		ram_block11a_45.port_a_last_address = 511,
		ram_block11a_45.port_a_logical_ram_depth = 512,
		ram_block11a_45.port_a_logical_ram_width = 97,
		ram_block11a_45.port_b_address_clear = "clear1",
		ram_block11a_45.port_b_address_clock = "clock1",
		ram_block11a_45.port_b_address_width = 9,
		ram_block11a_45.port_b_data_out_clear = "none",
		ram_block11a_45.port_b_data_width = 1,
		ram_block11a_45.port_b_first_address = 0,
		ram_block11a_45.port_b_first_bit_number = 45,
		ram_block11a_45.port_b_last_address = 511,
		ram_block11a_45.port_b_logical_ram_depth = 512,
		ram_block11a_45.port_b_logical_ram_width = 97,
		ram_block11a_45.port_b_read_enable_clock = "clock1",
		ram_block11a_45.ram_block_type = "AUTO",
		ram_block11a_45.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_46
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[46]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_46portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_46.clk0_core_clock_enable = "ena0",
		ram_block11a_46.clk0_input_clock_enable = "none",
		ram_block11a_46.clk1_core_clock_enable = "none",
		ram_block11a_46.clk1_input_clock_enable = "none",
		ram_block11a_46.connectivity_checking = "OFF",
		ram_block11a_46.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_46.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_46.operation_mode = "dual_port",
		ram_block11a_46.port_a_address_width = 9,
		ram_block11a_46.port_a_data_width = 1,
		ram_block11a_46.port_a_first_address = 0,
		ram_block11a_46.port_a_first_bit_number = 46,
		ram_block11a_46.port_a_last_address = 511,
		ram_block11a_46.port_a_logical_ram_depth = 512,
		ram_block11a_46.port_a_logical_ram_width = 97,
		ram_block11a_46.port_b_address_clear = "clear1",
		ram_block11a_46.port_b_address_clock = "clock1",
		ram_block11a_46.port_b_address_width = 9,
		ram_block11a_46.port_b_data_out_clear = "none",
		ram_block11a_46.port_b_data_width = 1,
		ram_block11a_46.port_b_first_address = 0,
		ram_block11a_46.port_b_first_bit_number = 46,
		ram_block11a_46.port_b_last_address = 511,
		ram_block11a_46.port_b_logical_ram_depth = 512,
		ram_block11a_46.port_b_logical_ram_width = 97,
		ram_block11a_46.port_b_read_enable_clock = "clock1",
		ram_block11a_46.ram_block_type = "AUTO",
		ram_block11a_46.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_47
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[47]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_47portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_47.clk0_core_clock_enable = "ena0",
		ram_block11a_47.clk0_input_clock_enable = "none",
		ram_block11a_47.clk1_core_clock_enable = "none",
		ram_block11a_47.clk1_input_clock_enable = "none",
		ram_block11a_47.connectivity_checking = "OFF",
		ram_block11a_47.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_47.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_47.operation_mode = "dual_port",
		ram_block11a_47.port_a_address_width = 9,
		ram_block11a_47.port_a_data_width = 1,
		ram_block11a_47.port_a_first_address = 0,
		ram_block11a_47.port_a_first_bit_number = 47,
		ram_block11a_47.port_a_last_address = 511,
		ram_block11a_47.port_a_logical_ram_depth = 512,
		ram_block11a_47.port_a_logical_ram_width = 97,
		ram_block11a_47.port_b_address_clear = "clear1",
		ram_block11a_47.port_b_address_clock = "clock1",
		ram_block11a_47.port_b_address_width = 9,
		ram_block11a_47.port_b_data_out_clear = "none",
		ram_block11a_47.port_b_data_width = 1,
		ram_block11a_47.port_b_first_address = 0,
		ram_block11a_47.port_b_first_bit_number = 47,
		ram_block11a_47.port_b_last_address = 511,
		ram_block11a_47.port_b_logical_ram_depth = 512,
		ram_block11a_47.port_b_logical_ram_width = 97,
		ram_block11a_47.port_b_read_enable_clock = "clock1",
		ram_block11a_47.ram_block_type = "AUTO",
		ram_block11a_47.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_48
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[48]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_48portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_48.clk0_core_clock_enable = "ena0",
		ram_block11a_48.clk0_input_clock_enable = "none",
		ram_block11a_48.clk1_core_clock_enable = "none",
		ram_block11a_48.clk1_input_clock_enable = "none",
		ram_block11a_48.connectivity_checking = "OFF",
		ram_block11a_48.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_48.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_48.operation_mode = "dual_port",
		ram_block11a_48.port_a_address_width = 9,
		ram_block11a_48.port_a_data_width = 1,
		ram_block11a_48.port_a_first_address = 0,
		ram_block11a_48.port_a_first_bit_number = 48,
		ram_block11a_48.port_a_last_address = 511,
		ram_block11a_48.port_a_logical_ram_depth = 512,
		ram_block11a_48.port_a_logical_ram_width = 97,
		ram_block11a_48.port_b_address_clear = "clear1",
		ram_block11a_48.port_b_address_clock = "clock1",
		ram_block11a_48.port_b_address_width = 9,
		ram_block11a_48.port_b_data_out_clear = "none",
		ram_block11a_48.port_b_data_width = 1,
		ram_block11a_48.port_b_first_address = 0,
		ram_block11a_48.port_b_first_bit_number = 48,
		ram_block11a_48.port_b_last_address = 511,
		ram_block11a_48.port_b_logical_ram_depth = 512,
		ram_block11a_48.port_b_logical_ram_width = 97,
		ram_block11a_48.port_b_read_enable_clock = "clock1",
		ram_block11a_48.ram_block_type = "AUTO",
		ram_block11a_48.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_49
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[49]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_49portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_49.clk0_core_clock_enable = "ena0",
		ram_block11a_49.clk0_input_clock_enable = "none",
		ram_block11a_49.clk1_core_clock_enable = "none",
		ram_block11a_49.clk1_input_clock_enable = "none",
		ram_block11a_49.connectivity_checking = "OFF",
		ram_block11a_49.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_49.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_49.operation_mode = "dual_port",
		ram_block11a_49.port_a_address_width = 9,
		ram_block11a_49.port_a_data_width = 1,
		ram_block11a_49.port_a_first_address = 0,
		ram_block11a_49.port_a_first_bit_number = 49,
		ram_block11a_49.port_a_last_address = 511,
		ram_block11a_49.port_a_logical_ram_depth = 512,
		ram_block11a_49.port_a_logical_ram_width = 97,
		ram_block11a_49.port_b_address_clear = "clear1",
		ram_block11a_49.port_b_address_clock = "clock1",
		ram_block11a_49.port_b_address_width = 9,
		ram_block11a_49.port_b_data_out_clear = "none",
		ram_block11a_49.port_b_data_width = 1,
		ram_block11a_49.port_b_first_address = 0,
		ram_block11a_49.port_b_first_bit_number = 49,
		ram_block11a_49.port_b_last_address = 511,
		ram_block11a_49.port_b_logical_ram_depth = 512,
		ram_block11a_49.port_b_logical_ram_width = 97,
		ram_block11a_49.port_b_read_enable_clock = "clock1",
		ram_block11a_49.ram_block_type = "AUTO",
		ram_block11a_49.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_50
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[50]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_50portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_50.clk0_core_clock_enable = "ena0",
		ram_block11a_50.clk0_input_clock_enable = "none",
		ram_block11a_50.clk1_core_clock_enable = "none",
		ram_block11a_50.clk1_input_clock_enable = "none",
		ram_block11a_50.connectivity_checking = "OFF",
		ram_block11a_50.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_50.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_50.operation_mode = "dual_port",
		ram_block11a_50.port_a_address_width = 9,
		ram_block11a_50.port_a_data_width = 1,
		ram_block11a_50.port_a_first_address = 0,
		ram_block11a_50.port_a_first_bit_number = 50,
		ram_block11a_50.port_a_last_address = 511,
		ram_block11a_50.port_a_logical_ram_depth = 512,
		ram_block11a_50.port_a_logical_ram_width = 97,
		ram_block11a_50.port_b_address_clear = "clear1",
		ram_block11a_50.port_b_address_clock = "clock1",
		ram_block11a_50.port_b_address_width = 9,
		ram_block11a_50.port_b_data_out_clear = "none",
		ram_block11a_50.port_b_data_width = 1,
		ram_block11a_50.port_b_first_address = 0,
		ram_block11a_50.port_b_first_bit_number = 50,
		ram_block11a_50.port_b_last_address = 511,
		ram_block11a_50.port_b_logical_ram_depth = 512,
		ram_block11a_50.port_b_logical_ram_width = 97,
		ram_block11a_50.port_b_read_enable_clock = "clock1",
		ram_block11a_50.ram_block_type = "AUTO",
		ram_block11a_50.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_51
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[51]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_51portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_51.clk0_core_clock_enable = "ena0",
		ram_block11a_51.clk0_input_clock_enable = "none",
		ram_block11a_51.clk1_core_clock_enable = "none",
		ram_block11a_51.clk1_input_clock_enable = "none",
		ram_block11a_51.connectivity_checking = "OFF",
		ram_block11a_51.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_51.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_51.operation_mode = "dual_port",
		ram_block11a_51.port_a_address_width = 9,
		ram_block11a_51.port_a_data_width = 1,
		ram_block11a_51.port_a_first_address = 0,
		ram_block11a_51.port_a_first_bit_number = 51,
		ram_block11a_51.port_a_last_address = 511,
		ram_block11a_51.port_a_logical_ram_depth = 512,
		ram_block11a_51.port_a_logical_ram_width = 97,
		ram_block11a_51.port_b_address_clear = "clear1",
		ram_block11a_51.port_b_address_clock = "clock1",
		ram_block11a_51.port_b_address_width = 9,
		ram_block11a_51.port_b_data_out_clear = "none",
		ram_block11a_51.port_b_data_width = 1,
		ram_block11a_51.port_b_first_address = 0,
		ram_block11a_51.port_b_first_bit_number = 51,
		ram_block11a_51.port_b_last_address = 511,
		ram_block11a_51.port_b_logical_ram_depth = 512,
		ram_block11a_51.port_b_logical_ram_width = 97,
		ram_block11a_51.port_b_read_enable_clock = "clock1",
		ram_block11a_51.ram_block_type = "AUTO",
		ram_block11a_51.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_52
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[52]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_52portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_52.clk0_core_clock_enable = "ena0",
		ram_block11a_52.clk0_input_clock_enable = "none",
		ram_block11a_52.clk1_core_clock_enable = "none",
		ram_block11a_52.clk1_input_clock_enable = "none",
		ram_block11a_52.connectivity_checking = "OFF",
		ram_block11a_52.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_52.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_52.operation_mode = "dual_port",
		ram_block11a_52.port_a_address_width = 9,
		ram_block11a_52.port_a_data_width = 1,
		ram_block11a_52.port_a_first_address = 0,
		ram_block11a_52.port_a_first_bit_number = 52,
		ram_block11a_52.port_a_last_address = 511,
		ram_block11a_52.port_a_logical_ram_depth = 512,
		ram_block11a_52.port_a_logical_ram_width = 97,
		ram_block11a_52.port_b_address_clear = "clear1",
		ram_block11a_52.port_b_address_clock = "clock1",
		ram_block11a_52.port_b_address_width = 9,
		ram_block11a_52.port_b_data_out_clear = "none",
		ram_block11a_52.port_b_data_width = 1,
		ram_block11a_52.port_b_first_address = 0,
		ram_block11a_52.port_b_first_bit_number = 52,
		ram_block11a_52.port_b_last_address = 511,
		ram_block11a_52.port_b_logical_ram_depth = 512,
		ram_block11a_52.port_b_logical_ram_width = 97,
		ram_block11a_52.port_b_read_enable_clock = "clock1",
		ram_block11a_52.ram_block_type = "AUTO",
		ram_block11a_52.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_53
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[53]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_53portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_53.clk0_core_clock_enable = "ena0",
		ram_block11a_53.clk0_input_clock_enable = "none",
		ram_block11a_53.clk1_core_clock_enable = "none",
		ram_block11a_53.clk1_input_clock_enable = "none",
		ram_block11a_53.connectivity_checking = "OFF",
		ram_block11a_53.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_53.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_53.operation_mode = "dual_port",
		ram_block11a_53.port_a_address_width = 9,
		ram_block11a_53.port_a_data_width = 1,
		ram_block11a_53.port_a_first_address = 0,
		ram_block11a_53.port_a_first_bit_number = 53,
		ram_block11a_53.port_a_last_address = 511,
		ram_block11a_53.port_a_logical_ram_depth = 512,
		ram_block11a_53.port_a_logical_ram_width = 97,
		ram_block11a_53.port_b_address_clear = "clear1",
		ram_block11a_53.port_b_address_clock = "clock1",
		ram_block11a_53.port_b_address_width = 9,
		ram_block11a_53.port_b_data_out_clear = "none",
		ram_block11a_53.port_b_data_width = 1,
		ram_block11a_53.port_b_first_address = 0,
		ram_block11a_53.port_b_first_bit_number = 53,
		ram_block11a_53.port_b_last_address = 511,
		ram_block11a_53.port_b_logical_ram_depth = 512,
		ram_block11a_53.port_b_logical_ram_width = 97,
		ram_block11a_53.port_b_read_enable_clock = "clock1",
		ram_block11a_53.ram_block_type = "AUTO",
		ram_block11a_53.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_54
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[54]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_54portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_54.clk0_core_clock_enable = "ena0",
		ram_block11a_54.clk0_input_clock_enable = "none",
		ram_block11a_54.clk1_core_clock_enable = "none",
		ram_block11a_54.clk1_input_clock_enable = "none",
		ram_block11a_54.connectivity_checking = "OFF",
		ram_block11a_54.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_54.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_54.operation_mode = "dual_port",
		ram_block11a_54.port_a_address_width = 9,
		ram_block11a_54.port_a_data_width = 1,
		ram_block11a_54.port_a_first_address = 0,
		ram_block11a_54.port_a_first_bit_number = 54,
		ram_block11a_54.port_a_last_address = 511,
		ram_block11a_54.port_a_logical_ram_depth = 512,
		ram_block11a_54.port_a_logical_ram_width = 97,
		ram_block11a_54.port_b_address_clear = "clear1",
		ram_block11a_54.port_b_address_clock = "clock1",
		ram_block11a_54.port_b_address_width = 9,
		ram_block11a_54.port_b_data_out_clear = "none",
		ram_block11a_54.port_b_data_width = 1,
		ram_block11a_54.port_b_first_address = 0,
		ram_block11a_54.port_b_first_bit_number = 54,
		ram_block11a_54.port_b_last_address = 511,
		ram_block11a_54.port_b_logical_ram_depth = 512,
		ram_block11a_54.port_b_logical_ram_width = 97,
		ram_block11a_54.port_b_read_enable_clock = "clock1",
		ram_block11a_54.ram_block_type = "AUTO",
		ram_block11a_54.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_55
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[55]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_55portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_55.clk0_core_clock_enable = "ena0",
		ram_block11a_55.clk0_input_clock_enable = "none",
		ram_block11a_55.clk1_core_clock_enable = "none",
		ram_block11a_55.clk1_input_clock_enable = "none",
		ram_block11a_55.connectivity_checking = "OFF",
		ram_block11a_55.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_55.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_55.operation_mode = "dual_port",
		ram_block11a_55.port_a_address_width = 9,
		ram_block11a_55.port_a_data_width = 1,
		ram_block11a_55.port_a_first_address = 0,
		ram_block11a_55.port_a_first_bit_number = 55,
		ram_block11a_55.port_a_last_address = 511,
		ram_block11a_55.port_a_logical_ram_depth = 512,
		ram_block11a_55.port_a_logical_ram_width = 97,
		ram_block11a_55.port_b_address_clear = "clear1",
		ram_block11a_55.port_b_address_clock = "clock1",
		ram_block11a_55.port_b_address_width = 9,
		ram_block11a_55.port_b_data_out_clear = "none",
		ram_block11a_55.port_b_data_width = 1,
		ram_block11a_55.port_b_first_address = 0,
		ram_block11a_55.port_b_first_bit_number = 55,
		ram_block11a_55.port_b_last_address = 511,
		ram_block11a_55.port_b_logical_ram_depth = 512,
		ram_block11a_55.port_b_logical_ram_width = 97,
		ram_block11a_55.port_b_read_enable_clock = "clock1",
		ram_block11a_55.ram_block_type = "AUTO",
		ram_block11a_55.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_56
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[56]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_56portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_56.clk0_core_clock_enable = "ena0",
		ram_block11a_56.clk0_input_clock_enable = "none",
		ram_block11a_56.clk1_core_clock_enable = "none",
		ram_block11a_56.clk1_input_clock_enable = "none",
		ram_block11a_56.connectivity_checking = "OFF",
		ram_block11a_56.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_56.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_56.operation_mode = "dual_port",
		ram_block11a_56.port_a_address_width = 9,
		ram_block11a_56.port_a_data_width = 1,
		ram_block11a_56.port_a_first_address = 0,
		ram_block11a_56.port_a_first_bit_number = 56,
		ram_block11a_56.port_a_last_address = 511,
		ram_block11a_56.port_a_logical_ram_depth = 512,
		ram_block11a_56.port_a_logical_ram_width = 97,
		ram_block11a_56.port_b_address_clear = "clear1",
		ram_block11a_56.port_b_address_clock = "clock1",
		ram_block11a_56.port_b_address_width = 9,
		ram_block11a_56.port_b_data_out_clear = "none",
		ram_block11a_56.port_b_data_width = 1,
		ram_block11a_56.port_b_first_address = 0,
		ram_block11a_56.port_b_first_bit_number = 56,
		ram_block11a_56.port_b_last_address = 511,
		ram_block11a_56.port_b_logical_ram_depth = 512,
		ram_block11a_56.port_b_logical_ram_width = 97,
		ram_block11a_56.port_b_read_enable_clock = "clock1",
		ram_block11a_56.ram_block_type = "AUTO",
		ram_block11a_56.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_57
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[57]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_57portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_57.clk0_core_clock_enable = "ena0",
		ram_block11a_57.clk0_input_clock_enable = "none",
		ram_block11a_57.clk1_core_clock_enable = "none",
		ram_block11a_57.clk1_input_clock_enable = "none",
		ram_block11a_57.connectivity_checking = "OFF",
		ram_block11a_57.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_57.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_57.operation_mode = "dual_port",
		ram_block11a_57.port_a_address_width = 9,
		ram_block11a_57.port_a_data_width = 1,
		ram_block11a_57.port_a_first_address = 0,
		ram_block11a_57.port_a_first_bit_number = 57,
		ram_block11a_57.port_a_last_address = 511,
		ram_block11a_57.port_a_logical_ram_depth = 512,
		ram_block11a_57.port_a_logical_ram_width = 97,
		ram_block11a_57.port_b_address_clear = "clear1",
		ram_block11a_57.port_b_address_clock = "clock1",
		ram_block11a_57.port_b_address_width = 9,
		ram_block11a_57.port_b_data_out_clear = "none",
		ram_block11a_57.port_b_data_width = 1,
		ram_block11a_57.port_b_first_address = 0,
		ram_block11a_57.port_b_first_bit_number = 57,
		ram_block11a_57.port_b_last_address = 511,
		ram_block11a_57.port_b_logical_ram_depth = 512,
		ram_block11a_57.port_b_logical_ram_width = 97,
		ram_block11a_57.port_b_read_enable_clock = "clock1",
		ram_block11a_57.ram_block_type = "AUTO",
		ram_block11a_57.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_58
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[58]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_58portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_58.clk0_core_clock_enable = "ena0",
		ram_block11a_58.clk0_input_clock_enable = "none",
		ram_block11a_58.clk1_core_clock_enable = "none",
		ram_block11a_58.clk1_input_clock_enable = "none",
		ram_block11a_58.connectivity_checking = "OFF",
		ram_block11a_58.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_58.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_58.operation_mode = "dual_port",
		ram_block11a_58.port_a_address_width = 9,
		ram_block11a_58.port_a_data_width = 1,
		ram_block11a_58.port_a_first_address = 0,
		ram_block11a_58.port_a_first_bit_number = 58,
		ram_block11a_58.port_a_last_address = 511,
		ram_block11a_58.port_a_logical_ram_depth = 512,
		ram_block11a_58.port_a_logical_ram_width = 97,
		ram_block11a_58.port_b_address_clear = "clear1",
		ram_block11a_58.port_b_address_clock = "clock1",
		ram_block11a_58.port_b_address_width = 9,
		ram_block11a_58.port_b_data_out_clear = "none",
		ram_block11a_58.port_b_data_width = 1,
		ram_block11a_58.port_b_first_address = 0,
		ram_block11a_58.port_b_first_bit_number = 58,
		ram_block11a_58.port_b_last_address = 511,
		ram_block11a_58.port_b_logical_ram_depth = 512,
		ram_block11a_58.port_b_logical_ram_width = 97,
		ram_block11a_58.port_b_read_enable_clock = "clock1",
		ram_block11a_58.ram_block_type = "AUTO",
		ram_block11a_58.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_59
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[59]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_59portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_59.clk0_core_clock_enable = "ena0",
		ram_block11a_59.clk0_input_clock_enable = "none",
		ram_block11a_59.clk1_core_clock_enable = "none",
		ram_block11a_59.clk1_input_clock_enable = "none",
		ram_block11a_59.connectivity_checking = "OFF",
		ram_block11a_59.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_59.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_59.operation_mode = "dual_port",
		ram_block11a_59.port_a_address_width = 9,
		ram_block11a_59.port_a_data_width = 1,
		ram_block11a_59.port_a_first_address = 0,
		ram_block11a_59.port_a_first_bit_number = 59,
		ram_block11a_59.port_a_last_address = 511,
		ram_block11a_59.port_a_logical_ram_depth = 512,
		ram_block11a_59.port_a_logical_ram_width = 97,
		ram_block11a_59.port_b_address_clear = "clear1",
		ram_block11a_59.port_b_address_clock = "clock1",
		ram_block11a_59.port_b_address_width = 9,
		ram_block11a_59.port_b_data_out_clear = "none",
		ram_block11a_59.port_b_data_width = 1,
		ram_block11a_59.port_b_first_address = 0,
		ram_block11a_59.port_b_first_bit_number = 59,
		ram_block11a_59.port_b_last_address = 511,
		ram_block11a_59.port_b_logical_ram_depth = 512,
		ram_block11a_59.port_b_logical_ram_width = 97,
		ram_block11a_59.port_b_read_enable_clock = "clock1",
		ram_block11a_59.ram_block_type = "AUTO",
		ram_block11a_59.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_60
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[60]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_60portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_60.clk0_core_clock_enable = "ena0",
		ram_block11a_60.clk0_input_clock_enable = "none",
		ram_block11a_60.clk1_core_clock_enable = "none",
		ram_block11a_60.clk1_input_clock_enable = "none",
		ram_block11a_60.connectivity_checking = "OFF",
		ram_block11a_60.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_60.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_60.operation_mode = "dual_port",
		ram_block11a_60.port_a_address_width = 9,
		ram_block11a_60.port_a_data_width = 1,
		ram_block11a_60.port_a_first_address = 0,
		ram_block11a_60.port_a_first_bit_number = 60,
		ram_block11a_60.port_a_last_address = 511,
		ram_block11a_60.port_a_logical_ram_depth = 512,
		ram_block11a_60.port_a_logical_ram_width = 97,
		ram_block11a_60.port_b_address_clear = "clear1",
		ram_block11a_60.port_b_address_clock = "clock1",
		ram_block11a_60.port_b_address_width = 9,
		ram_block11a_60.port_b_data_out_clear = "none",
		ram_block11a_60.port_b_data_width = 1,
		ram_block11a_60.port_b_first_address = 0,
		ram_block11a_60.port_b_first_bit_number = 60,
		ram_block11a_60.port_b_last_address = 511,
		ram_block11a_60.port_b_logical_ram_depth = 512,
		ram_block11a_60.port_b_logical_ram_width = 97,
		ram_block11a_60.port_b_read_enable_clock = "clock1",
		ram_block11a_60.ram_block_type = "AUTO",
		ram_block11a_60.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_61
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[61]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_61portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_61.clk0_core_clock_enable = "ena0",
		ram_block11a_61.clk0_input_clock_enable = "none",
		ram_block11a_61.clk1_core_clock_enable = "none",
		ram_block11a_61.clk1_input_clock_enable = "none",
		ram_block11a_61.connectivity_checking = "OFF",
		ram_block11a_61.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_61.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_61.operation_mode = "dual_port",
		ram_block11a_61.port_a_address_width = 9,
		ram_block11a_61.port_a_data_width = 1,
		ram_block11a_61.port_a_first_address = 0,
		ram_block11a_61.port_a_first_bit_number = 61,
		ram_block11a_61.port_a_last_address = 511,
		ram_block11a_61.port_a_logical_ram_depth = 512,
		ram_block11a_61.port_a_logical_ram_width = 97,
		ram_block11a_61.port_b_address_clear = "clear1",
		ram_block11a_61.port_b_address_clock = "clock1",
		ram_block11a_61.port_b_address_width = 9,
		ram_block11a_61.port_b_data_out_clear = "none",
		ram_block11a_61.port_b_data_width = 1,
		ram_block11a_61.port_b_first_address = 0,
		ram_block11a_61.port_b_first_bit_number = 61,
		ram_block11a_61.port_b_last_address = 511,
		ram_block11a_61.port_b_logical_ram_depth = 512,
		ram_block11a_61.port_b_logical_ram_width = 97,
		ram_block11a_61.port_b_read_enable_clock = "clock1",
		ram_block11a_61.ram_block_type = "AUTO",
		ram_block11a_61.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_62
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[62]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_62portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_62.clk0_core_clock_enable = "ena0",
		ram_block11a_62.clk0_input_clock_enable = "none",
		ram_block11a_62.clk1_core_clock_enable = "none",
		ram_block11a_62.clk1_input_clock_enable = "none",
		ram_block11a_62.connectivity_checking = "OFF",
		ram_block11a_62.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_62.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_62.operation_mode = "dual_port",
		ram_block11a_62.port_a_address_width = 9,
		ram_block11a_62.port_a_data_width = 1,
		ram_block11a_62.port_a_first_address = 0,
		ram_block11a_62.port_a_first_bit_number = 62,
		ram_block11a_62.port_a_last_address = 511,
		ram_block11a_62.port_a_logical_ram_depth = 512,
		ram_block11a_62.port_a_logical_ram_width = 97,
		ram_block11a_62.port_b_address_clear = "clear1",
		ram_block11a_62.port_b_address_clock = "clock1",
		ram_block11a_62.port_b_address_width = 9,
		ram_block11a_62.port_b_data_out_clear = "none",
		ram_block11a_62.port_b_data_width = 1,
		ram_block11a_62.port_b_first_address = 0,
		ram_block11a_62.port_b_first_bit_number = 62,
		ram_block11a_62.port_b_last_address = 511,
		ram_block11a_62.port_b_logical_ram_depth = 512,
		ram_block11a_62.port_b_logical_ram_width = 97,
		ram_block11a_62.port_b_read_enable_clock = "clock1",
		ram_block11a_62.ram_block_type = "AUTO",
		ram_block11a_62.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_63
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[63]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_63portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_63.clk0_core_clock_enable = "ena0",
		ram_block11a_63.clk0_input_clock_enable = "none",
		ram_block11a_63.clk1_core_clock_enable = "none",
		ram_block11a_63.clk1_input_clock_enable = "none",
		ram_block11a_63.connectivity_checking = "OFF",
		ram_block11a_63.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_63.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_63.operation_mode = "dual_port",
		ram_block11a_63.port_a_address_width = 9,
		ram_block11a_63.port_a_data_width = 1,
		ram_block11a_63.port_a_first_address = 0,
		ram_block11a_63.port_a_first_bit_number = 63,
		ram_block11a_63.port_a_last_address = 511,
		ram_block11a_63.port_a_logical_ram_depth = 512,
		ram_block11a_63.port_a_logical_ram_width = 97,
		ram_block11a_63.port_b_address_clear = "clear1",
		ram_block11a_63.port_b_address_clock = "clock1",
		ram_block11a_63.port_b_address_width = 9,
		ram_block11a_63.port_b_data_out_clear = "none",
		ram_block11a_63.port_b_data_width = 1,
		ram_block11a_63.port_b_first_address = 0,
		ram_block11a_63.port_b_first_bit_number = 63,
		ram_block11a_63.port_b_last_address = 511,
		ram_block11a_63.port_b_logical_ram_depth = 512,
		ram_block11a_63.port_b_logical_ram_width = 97,
		ram_block11a_63.port_b_read_enable_clock = "clock1",
		ram_block11a_63.ram_block_type = "AUTO",
		ram_block11a_63.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_64
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[64]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_64portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_64.clk0_core_clock_enable = "ena0",
		ram_block11a_64.clk0_input_clock_enable = "none",
		ram_block11a_64.clk1_core_clock_enable = "none",
		ram_block11a_64.clk1_input_clock_enable = "none",
		ram_block11a_64.connectivity_checking = "OFF",
		ram_block11a_64.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_64.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_64.operation_mode = "dual_port",
		ram_block11a_64.port_a_address_width = 9,
		ram_block11a_64.port_a_data_width = 1,
		ram_block11a_64.port_a_first_address = 0,
		ram_block11a_64.port_a_first_bit_number = 64,
		ram_block11a_64.port_a_last_address = 511,
		ram_block11a_64.port_a_logical_ram_depth = 512,
		ram_block11a_64.port_a_logical_ram_width = 97,
		ram_block11a_64.port_b_address_clear = "clear1",
		ram_block11a_64.port_b_address_clock = "clock1",
		ram_block11a_64.port_b_address_width = 9,
		ram_block11a_64.port_b_data_out_clear = "none",
		ram_block11a_64.port_b_data_width = 1,
		ram_block11a_64.port_b_first_address = 0,
		ram_block11a_64.port_b_first_bit_number = 64,
		ram_block11a_64.port_b_last_address = 511,
		ram_block11a_64.port_b_logical_ram_depth = 512,
		ram_block11a_64.port_b_logical_ram_width = 97,
		ram_block11a_64.port_b_read_enable_clock = "clock1",
		ram_block11a_64.ram_block_type = "AUTO",
		ram_block11a_64.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_65
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[65]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_65portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_65.clk0_core_clock_enable = "ena0",
		ram_block11a_65.clk0_input_clock_enable = "none",
		ram_block11a_65.clk1_core_clock_enable = "none",
		ram_block11a_65.clk1_input_clock_enable = "none",
		ram_block11a_65.connectivity_checking = "OFF",
		ram_block11a_65.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_65.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_65.operation_mode = "dual_port",
		ram_block11a_65.port_a_address_width = 9,
		ram_block11a_65.port_a_data_width = 1,
		ram_block11a_65.port_a_first_address = 0,
		ram_block11a_65.port_a_first_bit_number = 65,
		ram_block11a_65.port_a_last_address = 511,
		ram_block11a_65.port_a_logical_ram_depth = 512,
		ram_block11a_65.port_a_logical_ram_width = 97,
		ram_block11a_65.port_b_address_clear = "clear1",
		ram_block11a_65.port_b_address_clock = "clock1",
		ram_block11a_65.port_b_address_width = 9,
		ram_block11a_65.port_b_data_out_clear = "none",
		ram_block11a_65.port_b_data_width = 1,
		ram_block11a_65.port_b_first_address = 0,
		ram_block11a_65.port_b_first_bit_number = 65,
		ram_block11a_65.port_b_last_address = 511,
		ram_block11a_65.port_b_logical_ram_depth = 512,
		ram_block11a_65.port_b_logical_ram_width = 97,
		ram_block11a_65.port_b_read_enable_clock = "clock1",
		ram_block11a_65.ram_block_type = "AUTO",
		ram_block11a_65.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_66
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[66]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_66portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_66.clk0_core_clock_enable = "ena0",
		ram_block11a_66.clk0_input_clock_enable = "none",
		ram_block11a_66.clk1_core_clock_enable = "none",
		ram_block11a_66.clk1_input_clock_enable = "none",
		ram_block11a_66.connectivity_checking = "OFF",
		ram_block11a_66.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_66.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_66.operation_mode = "dual_port",
		ram_block11a_66.port_a_address_width = 9,
		ram_block11a_66.port_a_data_width = 1,
		ram_block11a_66.port_a_first_address = 0,
		ram_block11a_66.port_a_first_bit_number = 66,
		ram_block11a_66.port_a_last_address = 511,
		ram_block11a_66.port_a_logical_ram_depth = 512,
		ram_block11a_66.port_a_logical_ram_width = 97,
		ram_block11a_66.port_b_address_clear = "clear1",
		ram_block11a_66.port_b_address_clock = "clock1",
		ram_block11a_66.port_b_address_width = 9,
		ram_block11a_66.port_b_data_out_clear = "none",
		ram_block11a_66.port_b_data_width = 1,
		ram_block11a_66.port_b_first_address = 0,
		ram_block11a_66.port_b_first_bit_number = 66,
		ram_block11a_66.port_b_last_address = 511,
		ram_block11a_66.port_b_logical_ram_depth = 512,
		ram_block11a_66.port_b_logical_ram_width = 97,
		ram_block11a_66.port_b_read_enable_clock = "clock1",
		ram_block11a_66.ram_block_type = "AUTO",
		ram_block11a_66.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_67
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[67]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_67portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_67.clk0_core_clock_enable = "ena0",
		ram_block11a_67.clk0_input_clock_enable = "none",
		ram_block11a_67.clk1_core_clock_enable = "none",
		ram_block11a_67.clk1_input_clock_enable = "none",
		ram_block11a_67.connectivity_checking = "OFF",
		ram_block11a_67.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_67.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_67.operation_mode = "dual_port",
		ram_block11a_67.port_a_address_width = 9,
		ram_block11a_67.port_a_data_width = 1,
		ram_block11a_67.port_a_first_address = 0,
		ram_block11a_67.port_a_first_bit_number = 67,
		ram_block11a_67.port_a_last_address = 511,
		ram_block11a_67.port_a_logical_ram_depth = 512,
		ram_block11a_67.port_a_logical_ram_width = 97,
		ram_block11a_67.port_b_address_clear = "clear1",
		ram_block11a_67.port_b_address_clock = "clock1",
		ram_block11a_67.port_b_address_width = 9,
		ram_block11a_67.port_b_data_out_clear = "none",
		ram_block11a_67.port_b_data_width = 1,
		ram_block11a_67.port_b_first_address = 0,
		ram_block11a_67.port_b_first_bit_number = 67,
		ram_block11a_67.port_b_last_address = 511,
		ram_block11a_67.port_b_logical_ram_depth = 512,
		ram_block11a_67.port_b_logical_ram_width = 97,
		ram_block11a_67.port_b_read_enable_clock = "clock1",
		ram_block11a_67.ram_block_type = "AUTO",
		ram_block11a_67.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_68
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[68]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_68portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_68.clk0_core_clock_enable = "ena0",
		ram_block11a_68.clk0_input_clock_enable = "none",
		ram_block11a_68.clk1_core_clock_enable = "none",
		ram_block11a_68.clk1_input_clock_enable = "none",
		ram_block11a_68.connectivity_checking = "OFF",
		ram_block11a_68.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_68.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_68.operation_mode = "dual_port",
		ram_block11a_68.port_a_address_width = 9,
		ram_block11a_68.port_a_data_width = 1,
		ram_block11a_68.port_a_first_address = 0,
		ram_block11a_68.port_a_first_bit_number = 68,
		ram_block11a_68.port_a_last_address = 511,
		ram_block11a_68.port_a_logical_ram_depth = 512,
		ram_block11a_68.port_a_logical_ram_width = 97,
		ram_block11a_68.port_b_address_clear = "clear1",
		ram_block11a_68.port_b_address_clock = "clock1",
		ram_block11a_68.port_b_address_width = 9,
		ram_block11a_68.port_b_data_out_clear = "none",
		ram_block11a_68.port_b_data_width = 1,
		ram_block11a_68.port_b_first_address = 0,
		ram_block11a_68.port_b_first_bit_number = 68,
		ram_block11a_68.port_b_last_address = 511,
		ram_block11a_68.port_b_logical_ram_depth = 512,
		ram_block11a_68.port_b_logical_ram_width = 97,
		ram_block11a_68.port_b_read_enable_clock = "clock1",
		ram_block11a_68.ram_block_type = "AUTO",
		ram_block11a_68.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_69
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[69]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_69portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_69.clk0_core_clock_enable = "ena0",
		ram_block11a_69.clk0_input_clock_enable = "none",
		ram_block11a_69.clk1_core_clock_enable = "none",
		ram_block11a_69.clk1_input_clock_enable = "none",
		ram_block11a_69.connectivity_checking = "OFF",
		ram_block11a_69.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_69.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_69.operation_mode = "dual_port",
		ram_block11a_69.port_a_address_width = 9,
		ram_block11a_69.port_a_data_width = 1,
		ram_block11a_69.port_a_first_address = 0,
		ram_block11a_69.port_a_first_bit_number = 69,
		ram_block11a_69.port_a_last_address = 511,
		ram_block11a_69.port_a_logical_ram_depth = 512,
		ram_block11a_69.port_a_logical_ram_width = 97,
		ram_block11a_69.port_b_address_clear = "clear1",
		ram_block11a_69.port_b_address_clock = "clock1",
		ram_block11a_69.port_b_address_width = 9,
		ram_block11a_69.port_b_data_out_clear = "none",
		ram_block11a_69.port_b_data_width = 1,
		ram_block11a_69.port_b_first_address = 0,
		ram_block11a_69.port_b_first_bit_number = 69,
		ram_block11a_69.port_b_last_address = 511,
		ram_block11a_69.port_b_logical_ram_depth = 512,
		ram_block11a_69.port_b_logical_ram_width = 97,
		ram_block11a_69.port_b_read_enable_clock = "clock1",
		ram_block11a_69.ram_block_type = "AUTO",
		ram_block11a_69.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_70
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[70]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_70portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_70.clk0_core_clock_enable = "ena0",
		ram_block11a_70.clk0_input_clock_enable = "none",
		ram_block11a_70.clk1_core_clock_enable = "none",
		ram_block11a_70.clk1_input_clock_enable = "none",
		ram_block11a_70.connectivity_checking = "OFF",
		ram_block11a_70.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_70.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_70.operation_mode = "dual_port",
		ram_block11a_70.port_a_address_width = 9,
		ram_block11a_70.port_a_data_width = 1,
		ram_block11a_70.port_a_first_address = 0,
		ram_block11a_70.port_a_first_bit_number = 70,
		ram_block11a_70.port_a_last_address = 511,
		ram_block11a_70.port_a_logical_ram_depth = 512,
		ram_block11a_70.port_a_logical_ram_width = 97,
		ram_block11a_70.port_b_address_clear = "clear1",
		ram_block11a_70.port_b_address_clock = "clock1",
		ram_block11a_70.port_b_address_width = 9,
		ram_block11a_70.port_b_data_out_clear = "none",
		ram_block11a_70.port_b_data_width = 1,
		ram_block11a_70.port_b_first_address = 0,
		ram_block11a_70.port_b_first_bit_number = 70,
		ram_block11a_70.port_b_last_address = 511,
		ram_block11a_70.port_b_logical_ram_depth = 512,
		ram_block11a_70.port_b_logical_ram_width = 97,
		ram_block11a_70.port_b_read_enable_clock = "clock1",
		ram_block11a_70.ram_block_type = "AUTO",
		ram_block11a_70.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_71
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[71]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_71portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_71.clk0_core_clock_enable = "ena0",
		ram_block11a_71.clk0_input_clock_enable = "none",
		ram_block11a_71.clk1_core_clock_enable = "none",
		ram_block11a_71.clk1_input_clock_enable = "none",
		ram_block11a_71.connectivity_checking = "OFF",
		ram_block11a_71.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_71.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_71.operation_mode = "dual_port",
		ram_block11a_71.port_a_address_width = 9,
		ram_block11a_71.port_a_data_width = 1,
		ram_block11a_71.port_a_first_address = 0,
		ram_block11a_71.port_a_first_bit_number = 71,
		ram_block11a_71.port_a_last_address = 511,
		ram_block11a_71.port_a_logical_ram_depth = 512,
		ram_block11a_71.port_a_logical_ram_width = 97,
		ram_block11a_71.port_b_address_clear = "clear1",
		ram_block11a_71.port_b_address_clock = "clock1",
		ram_block11a_71.port_b_address_width = 9,
		ram_block11a_71.port_b_data_out_clear = "none",
		ram_block11a_71.port_b_data_width = 1,
		ram_block11a_71.port_b_first_address = 0,
		ram_block11a_71.port_b_first_bit_number = 71,
		ram_block11a_71.port_b_last_address = 511,
		ram_block11a_71.port_b_logical_ram_depth = 512,
		ram_block11a_71.port_b_logical_ram_width = 97,
		ram_block11a_71.port_b_read_enable_clock = "clock1",
		ram_block11a_71.ram_block_type = "AUTO",
		ram_block11a_71.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_72
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[72]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_72portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_72.clk0_core_clock_enable = "ena0",
		ram_block11a_72.clk0_input_clock_enable = "none",
		ram_block11a_72.clk1_core_clock_enable = "none",
		ram_block11a_72.clk1_input_clock_enable = "none",
		ram_block11a_72.connectivity_checking = "OFF",
		ram_block11a_72.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_72.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_72.operation_mode = "dual_port",
		ram_block11a_72.port_a_address_width = 9,
		ram_block11a_72.port_a_data_width = 1,
		ram_block11a_72.port_a_first_address = 0,
		ram_block11a_72.port_a_first_bit_number = 72,
		ram_block11a_72.port_a_last_address = 511,
		ram_block11a_72.port_a_logical_ram_depth = 512,
		ram_block11a_72.port_a_logical_ram_width = 97,
		ram_block11a_72.port_b_address_clear = "clear1",
		ram_block11a_72.port_b_address_clock = "clock1",
		ram_block11a_72.port_b_address_width = 9,
		ram_block11a_72.port_b_data_out_clear = "none",
		ram_block11a_72.port_b_data_width = 1,
		ram_block11a_72.port_b_first_address = 0,
		ram_block11a_72.port_b_first_bit_number = 72,
		ram_block11a_72.port_b_last_address = 511,
		ram_block11a_72.port_b_logical_ram_depth = 512,
		ram_block11a_72.port_b_logical_ram_width = 97,
		ram_block11a_72.port_b_read_enable_clock = "clock1",
		ram_block11a_72.ram_block_type = "AUTO",
		ram_block11a_72.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_73
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[73]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_73portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_73.clk0_core_clock_enable = "ena0",
		ram_block11a_73.clk0_input_clock_enable = "none",
		ram_block11a_73.clk1_core_clock_enable = "none",
		ram_block11a_73.clk1_input_clock_enable = "none",
		ram_block11a_73.connectivity_checking = "OFF",
		ram_block11a_73.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_73.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_73.operation_mode = "dual_port",
		ram_block11a_73.port_a_address_width = 9,
		ram_block11a_73.port_a_data_width = 1,
		ram_block11a_73.port_a_first_address = 0,
		ram_block11a_73.port_a_first_bit_number = 73,
		ram_block11a_73.port_a_last_address = 511,
		ram_block11a_73.port_a_logical_ram_depth = 512,
		ram_block11a_73.port_a_logical_ram_width = 97,
		ram_block11a_73.port_b_address_clear = "clear1",
		ram_block11a_73.port_b_address_clock = "clock1",
		ram_block11a_73.port_b_address_width = 9,
		ram_block11a_73.port_b_data_out_clear = "none",
		ram_block11a_73.port_b_data_width = 1,
		ram_block11a_73.port_b_first_address = 0,
		ram_block11a_73.port_b_first_bit_number = 73,
		ram_block11a_73.port_b_last_address = 511,
		ram_block11a_73.port_b_logical_ram_depth = 512,
		ram_block11a_73.port_b_logical_ram_width = 97,
		ram_block11a_73.port_b_read_enable_clock = "clock1",
		ram_block11a_73.ram_block_type = "AUTO",
		ram_block11a_73.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_74
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[74]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_74portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_74.clk0_core_clock_enable = "ena0",
		ram_block11a_74.clk0_input_clock_enable = "none",
		ram_block11a_74.clk1_core_clock_enable = "none",
		ram_block11a_74.clk1_input_clock_enable = "none",
		ram_block11a_74.connectivity_checking = "OFF",
		ram_block11a_74.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_74.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_74.operation_mode = "dual_port",
		ram_block11a_74.port_a_address_width = 9,
		ram_block11a_74.port_a_data_width = 1,
		ram_block11a_74.port_a_first_address = 0,
		ram_block11a_74.port_a_first_bit_number = 74,
		ram_block11a_74.port_a_last_address = 511,
		ram_block11a_74.port_a_logical_ram_depth = 512,
		ram_block11a_74.port_a_logical_ram_width = 97,
		ram_block11a_74.port_b_address_clear = "clear1",
		ram_block11a_74.port_b_address_clock = "clock1",
		ram_block11a_74.port_b_address_width = 9,
		ram_block11a_74.port_b_data_out_clear = "none",
		ram_block11a_74.port_b_data_width = 1,
		ram_block11a_74.port_b_first_address = 0,
		ram_block11a_74.port_b_first_bit_number = 74,
		ram_block11a_74.port_b_last_address = 511,
		ram_block11a_74.port_b_logical_ram_depth = 512,
		ram_block11a_74.port_b_logical_ram_width = 97,
		ram_block11a_74.port_b_read_enable_clock = "clock1",
		ram_block11a_74.ram_block_type = "AUTO",
		ram_block11a_74.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_75
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[75]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_75portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_75.clk0_core_clock_enable = "ena0",
		ram_block11a_75.clk0_input_clock_enable = "none",
		ram_block11a_75.clk1_core_clock_enable = "none",
		ram_block11a_75.clk1_input_clock_enable = "none",
		ram_block11a_75.connectivity_checking = "OFF",
		ram_block11a_75.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_75.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_75.operation_mode = "dual_port",
		ram_block11a_75.port_a_address_width = 9,
		ram_block11a_75.port_a_data_width = 1,
		ram_block11a_75.port_a_first_address = 0,
		ram_block11a_75.port_a_first_bit_number = 75,
		ram_block11a_75.port_a_last_address = 511,
		ram_block11a_75.port_a_logical_ram_depth = 512,
		ram_block11a_75.port_a_logical_ram_width = 97,
		ram_block11a_75.port_b_address_clear = "clear1",
		ram_block11a_75.port_b_address_clock = "clock1",
		ram_block11a_75.port_b_address_width = 9,
		ram_block11a_75.port_b_data_out_clear = "none",
		ram_block11a_75.port_b_data_width = 1,
		ram_block11a_75.port_b_first_address = 0,
		ram_block11a_75.port_b_first_bit_number = 75,
		ram_block11a_75.port_b_last_address = 511,
		ram_block11a_75.port_b_logical_ram_depth = 512,
		ram_block11a_75.port_b_logical_ram_width = 97,
		ram_block11a_75.port_b_read_enable_clock = "clock1",
		ram_block11a_75.ram_block_type = "AUTO",
		ram_block11a_75.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_76
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[76]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_76portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_76.clk0_core_clock_enable = "ena0",
		ram_block11a_76.clk0_input_clock_enable = "none",
		ram_block11a_76.clk1_core_clock_enable = "none",
		ram_block11a_76.clk1_input_clock_enable = "none",
		ram_block11a_76.connectivity_checking = "OFF",
		ram_block11a_76.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_76.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_76.operation_mode = "dual_port",
		ram_block11a_76.port_a_address_width = 9,
		ram_block11a_76.port_a_data_width = 1,
		ram_block11a_76.port_a_first_address = 0,
		ram_block11a_76.port_a_first_bit_number = 76,
		ram_block11a_76.port_a_last_address = 511,
		ram_block11a_76.port_a_logical_ram_depth = 512,
		ram_block11a_76.port_a_logical_ram_width = 97,
		ram_block11a_76.port_b_address_clear = "clear1",
		ram_block11a_76.port_b_address_clock = "clock1",
		ram_block11a_76.port_b_address_width = 9,
		ram_block11a_76.port_b_data_out_clear = "none",
		ram_block11a_76.port_b_data_width = 1,
		ram_block11a_76.port_b_first_address = 0,
		ram_block11a_76.port_b_first_bit_number = 76,
		ram_block11a_76.port_b_last_address = 511,
		ram_block11a_76.port_b_logical_ram_depth = 512,
		ram_block11a_76.port_b_logical_ram_width = 97,
		ram_block11a_76.port_b_read_enable_clock = "clock1",
		ram_block11a_76.ram_block_type = "AUTO",
		ram_block11a_76.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_77
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[77]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_77portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_77.clk0_core_clock_enable = "ena0",
		ram_block11a_77.clk0_input_clock_enable = "none",
		ram_block11a_77.clk1_core_clock_enable = "none",
		ram_block11a_77.clk1_input_clock_enable = "none",
		ram_block11a_77.connectivity_checking = "OFF",
		ram_block11a_77.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_77.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_77.operation_mode = "dual_port",
		ram_block11a_77.port_a_address_width = 9,
		ram_block11a_77.port_a_data_width = 1,
		ram_block11a_77.port_a_first_address = 0,
		ram_block11a_77.port_a_first_bit_number = 77,
		ram_block11a_77.port_a_last_address = 511,
		ram_block11a_77.port_a_logical_ram_depth = 512,
		ram_block11a_77.port_a_logical_ram_width = 97,
		ram_block11a_77.port_b_address_clear = "clear1",
		ram_block11a_77.port_b_address_clock = "clock1",
		ram_block11a_77.port_b_address_width = 9,
		ram_block11a_77.port_b_data_out_clear = "none",
		ram_block11a_77.port_b_data_width = 1,
		ram_block11a_77.port_b_first_address = 0,
		ram_block11a_77.port_b_first_bit_number = 77,
		ram_block11a_77.port_b_last_address = 511,
		ram_block11a_77.port_b_logical_ram_depth = 512,
		ram_block11a_77.port_b_logical_ram_width = 97,
		ram_block11a_77.port_b_read_enable_clock = "clock1",
		ram_block11a_77.ram_block_type = "AUTO",
		ram_block11a_77.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_78
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[78]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_78portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_78.clk0_core_clock_enable = "ena0",
		ram_block11a_78.clk0_input_clock_enable = "none",
		ram_block11a_78.clk1_core_clock_enable = "none",
		ram_block11a_78.clk1_input_clock_enable = "none",
		ram_block11a_78.connectivity_checking = "OFF",
		ram_block11a_78.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_78.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_78.operation_mode = "dual_port",
		ram_block11a_78.port_a_address_width = 9,
		ram_block11a_78.port_a_data_width = 1,
		ram_block11a_78.port_a_first_address = 0,
		ram_block11a_78.port_a_first_bit_number = 78,
		ram_block11a_78.port_a_last_address = 511,
		ram_block11a_78.port_a_logical_ram_depth = 512,
		ram_block11a_78.port_a_logical_ram_width = 97,
		ram_block11a_78.port_b_address_clear = "clear1",
		ram_block11a_78.port_b_address_clock = "clock1",
		ram_block11a_78.port_b_address_width = 9,
		ram_block11a_78.port_b_data_out_clear = "none",
		ram_block11a_78.port_b_data_width = 1,
		ram_block11a_78.port_b_first_address = 0,
		ram_block11a_78.port_b_first_bit_number = 78,
		ram_block11a_78.port_b_last_address = 511,
		ram_block11a_78.port_b_logical_ram_depth = 512,
		ram_block11a_78.port_b_logical_ram_width = 97,
		ram_block11a_78.port_b_read_enable_clock = "clock1",
		ram_block11a_78.ram_block_type = "AUTO",
		ram_block11a_78.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_79
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[79]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_79portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_79.clk0_core_clock_enable = "ena0",
		ram_block11a_79.clk0_input_clock_enable = "none",
		ram_block11a_79.clk1_core_clock_enable = "none",
		ram_block11a_79.clk1_input_clock_enable = "none",
		ram_block11a_79.connectivity_checking = "OFF",
		ram_block11a_79.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_79.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_79.operation_mode = "dual_port",
		ram_block11a_79.port_a_address_width = 9,
		ram_block11a_79.port_a_data_width = 1,
		ram_block11a_79.port_a_first_address = 0,
		ram_block11a_79.port_a_first_bit_number = 79,
		ram_block11a_79.port_a_last_address = 511,
		ram_block11a_79.port_a_logical_ram_depth = 512,
		ram_block11a_79.port_a_logical_ram_width = 97,
		ram_block11a_79.port_b_address_clear = "clear1",
		ram_block11a_79.port_b_address_clock = "clock1",
		ram_block11a_79.port_b_address_width = 9,
		ram_block11a_79.port_b_data_out_clear = "none",
		ram_block11a_79.port_b_data_width = 1,
		ram_block11a_79.port_b_first_address = 0,
		ram_block11a_79.port_b_first_bit_number = 79,
		ram_block11a_79.port_b_last_address = 511,
		ram_block11a_79.port_b_logical_ram_depth = 512,
		ram_block11a_79.port_b_logical_ram_width = 97,
		ram_block11a_79.port_b_read_enable_clock = "clock1",
		ram_block11a_79.ram_block_type = "AUTO",
		ram_block11a_79.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_80
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[80]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_80portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_80.clk0_core_clock_enable = "ena0",
		ram_block11a_80.clk0_input_clock_enable = "none",
		ram_block11a_80.clk1_core_clock_enable = "none",
		ram_block11a_80.clk1_input_clock_enable = "none",
		ram_block11a_80.connectivity_checking = "OFF",
		ram_block11a_80.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_80.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_80.operation_mode = "dual_port",
		ram_block11a_80.port_a_address_width = 9,
		ram_block11a_80.port_a_data_width = 1,
		ram_block11a_80.port_a_first_address = 0,
		ram_block11a_80.port_a_first_bit_number = 80,
		ram_block11a_80.port_a_last_address = 511,
		ram_block11a_80.port_a_logical_ram_depth = 512,
		ram_block11a_80.port_a_logical_ram_width = 97,
		ram_block11a_80.port_b_address_clear = "clear1",
		ram_block11a_80.port_b_address_clock = "clock1",
		ram_block11a_80.port_b_address_width = 9,
		ram_block11a_80.port_b_data_out_clear = "none",
		ram_block11a_80.port_b_data_width = 1,
		ram_block11a_80.port_b_first_address = 0,
		ram_block11a_80.port_b_first_bit_number = 80,
		ram_block11a_80.port_b_last_address = 511,
		ram_block11a_80.port_b_logical_ram_depth = 512,
		ram_block11a_80.port_b_logical_ram_width = 97,
		ram_block11a_80.port_b_read_enable_clock = "clock1",
		ram_block11a_80.ram_block_type = "AUTO",
		ram_block11a_80.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_81
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[81]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_81portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_81.clk0_core_clock_enable = "ena0",
		ram_block11a_81.clk0_input_clock_enable = "none",
		ram_block11a_81.clk1_core_clock_enable = "none",
		ram_block11a_81.clk1_input_clock_enable = "none",
		ram_block11a_81.connectivity_checking = "OFF",
		ram_block11a_81.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_81.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_81.operation_mode = "dual_port",
		ram_block11a_81.port_a_address_width = 9,
		ram_block11a_81.port_a_data_width = 1,
		ram_block11a_81.port_a_first_address = 0,
		ram_block11a_81.port_a_first_bit_number = 81,
		ram_block11a_81.port_a_last_address = 511,
		ram_block11a_81.port_a_logical_ram_depth = 512,
		ram_block11a_81.port_a_logical_ram_width = 97,
		ram_block11a_81.port_b_address_clear = "clear1",
		ram_block11a_81.port_b_address_clock = "clock1",
		ram_block11a_81.port_b_address_width = 9,
		ram_block11a_81.port_b_data_out_clear = "none",
		ram_block11a_81.port_b_data_width = 1,
		ram_block11a_81.port_b_first_address = 0,
		ram_block11a_81.port_b_first_bit_number = 81,
		ram_block11a_81.port_b_last_address = 511,
		ram_block11a_81.port_b_logical_ram_depth = 512,
		ram_block11a_81.port_b_logical_ram_width = 97,
		ram_block11a_81.port_b_read_enable_clock = "clock1",
		ram_block11a_81.ram_block_type = "AUTO",
		ram_block11a_81.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_82
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[82]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_82portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_82.clk0_core_clock_enable = "ena0",
		ram_block11a_82.clk0_input_clock_enable = "none",
		ram_block11a_82.clk1_core_clock_enable = "none",
		ram_block11a_82.clk1_input_clock_enable = "none",
		ram_block11a_82.connectivity_checking = "OFF",
		ram_block11a_82.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_82.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_82.operation_mode = "dual_port",
		ram_block11a_82.port_a_address_width = 9,
		ram_block11a_82.port_a_data_width = 1,
		ram_block11a_82.port_a_first_address = 0,
		ram_block11a_82.port_a_first_bit_number = 82,
		ram_block11a_82.port_a_last_address = 511,
		ram_block11a_82.port_a_logical_ram_depth = 512,
		ram_block11a_82.port_a_logical_ram_width = 97,
		ram_block11a_82.port_b_address_clear = "clear1",
		ram_block11a_82.port_b_address_clock = "clock1",
		ram_block11a_82.port_b_address_width = 9,
		ram_block11a_82.port_b_data_out_clear = "none",
		ram_block11a_82.port_b_data_width = 1,
		ram_block11a_82.port_b_first_address = 0,
		ram_block11a_82.port_b_first_bit_number = 82,
		ram_block11a_82.port_b_last_address = 511,
		ram_block11a_82.port_b_logical_ram_depth = 512,
		ram_block11a_82.port_b_logical_ram_width = 97,
		ram_block11a_82.port_b_read_enable_clock = "clock1",
		ram_block11a_82.ram_block_type = "AUTO",
		ram_block11a_82.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_83
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[83]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_83portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_83.clk0_core_clock_enable = "ena0",
		ram_block11a_83.clk0_input_clock_enable = "none",
		ram_block11a_83.clk1_core_clock_enable = "none",
		ram_block11a_83.clk1_input_clock_enable = "none",
		ram_block11a_83.connectivity_checking = "OFF",
		ram_block11a_83.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_83.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_83.operation_mode = "dual_port",
		ram_block11a_83.port_a_address_width = 9,
		ram_block11a_83.port_a_data_width = 1,
		ram_block11a_83.port_a_first_address = 0,
		ram_block11a_83.port_a_first_bit_number = 83,
		ram_block11a_83.port_a_last_address = 511,
		ram_block11a_83.port_a_logical_ram_depth = 512,
		ram_block11a_83.port_a_logical_ram_width = 97,
		ram_block11a_83.port_b_address_clear = "clear1",
		ram_block11a_83.port_b_address_clock = "clock1",
		ram_block11a_83.port_b_address_width = 9,
		ram_block11a_83.port_b_data_out_clear = "none",
		ram_block11a_83.port_b_data_width = 1,
		ram_block11a_83.port_b_first_address = 0,
		ram_block11a_83.port_b_first_bit_number = 83,
		ram_block11a_83.port_b_last_address = 511,
		ram_block11a_83.port_b_logical_ram_depth = 512,
		ram_block11a_83.port_b_logical_ram_width = 97,
		ram_block11a_83.port_b_read_enable_clock = "clock1",
		ram_block11a_83.ram_block_type = "AUTO",
		ram_block11a_83.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_84
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[84]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_84portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_84.clk0_core_clock_enable = "ena0",
		ram_block11a_84.clk0_input_clock_enable = "none",
		ram_block11a_84.clk1_core_clock_enable = "none",
		ram_block11a_84.clk1_input_clock_enable = "none",
		ram_block11a_84.connectivity_checking = "OFF",
		ram_block11a_84.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_84.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_84.operation_mode = "dual_port",
		ram_block11a_84.port_a_address_width = 9,
		ram_block11a_84.port_a_data_width = 1,
		ram_block11a_84.port_a_first_address = 0,
		ram_block11a_84.port_a_first_bit_number = 84,
		ram_block11a_84.port_a_last_address = 511,
		ram_block11a_84.port_a_logical_ram_depth = 512,
		ram_block11a_84.port_a_logical_ram_width = 97,
		ram_block11a_84.port_b_address_clear = "clear1",
		ram_block11a_84.port_b_address_clock = "clock1",
		ram_block11a_84.port_b_address_width = 9,
		ram_block11a_84.port_b_data_out_clear = "none",
		ram_block11a_84.port_b_data_width = 1,
		ram_block11a_84.port_b_first_address = 0,
		ram_block11a_84.port_b_first_bit_number = 84,
		ram_block11a_84.port_b_last_address = 511,
		ram_block11a_84.port_b_logical_ram_depth = 512,
		ram_block11a_84.port_b_logical_ram_width = 97,
		ram_block11a_84.port_b_read_enable_clock = "clock1",
		ram_block11a_84.ram_block_type = "AUTO",
		ram_block11a_84.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_85
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[85]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_85portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_85.clk0_core_clock_enable = "ena0",
		ram_block11a_85.clk0_input_clock_enable = "none",
		ram_block11a_85.clk1_core_clock_enable = "none",
		ram_block11a_85.clk1_input_clock_enable = "none",
		ram_block11a_85.connectivity_checking = "OFF",
		ram_block11a_85.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_85.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_85.operation_mode = "dual_port",
		ram_block11a_85.port_a_address_width = 9,
		ram_block11a_85.port_a_data_width = 1,
		ram_block11a_85.port_a_first_address = 0,
		ram_block11a_85.port_a_first_bit_number = 85,
		ram_block11a_85.port_a_last_address = 511,
		ram_block11a_85.port_a_logical_ram_depth = 512,
		ram_block11a_85.port_a_logical_ram_width = 97,
		ram_block11a_85.port_b_address_clear = "clear1",
		ram_block11a_85.port_b_address_clock = "clock1",
		ram_block11a_85.port_b_address_width = 9,
		ram_block11a_85.port_b_data_out_clear = "none",
		ram_block11a_85.port_b_data_width = 1,
		ram_block11a_85.port_b_first_address = 0,
		ram_block11a_85.port_b_first_bit_number = 85,
		ram_block11a_85.port_b_last_address = 511,
		ram_block11a_85.port_b_logical_ram_depth = 512,
		ram_block11a_85.port_b_logical_ram_width = 97,
		ram_block11a_85.port_b_read_enable_clock = "clock1",
		ram_block11a_85.ram_block_type = "AUTO",
		ram_block11a_85.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_86
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[86]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_86portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_86.clk0_core_clock_enable = "ena0",
		ram_block11a_86.clk0_input_clock_enable = "none",
		ram_block11a_86.clk1_core_clock_enable = "none",
		ram_block11a_86.clk1_input_clock_enable = "none",
		ram_block11a_86.connectivity_checking = "OFF",
		ram_block11a_86.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_86.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_86.operation_mode = "dual_port",
		ram_block11a_86.port_a_address_width = 9,
		ram_block11a_86.port_a_data_width = 1,
		ram_block11a_86.port_a_first_address = 0,
		ram_block11a_86.port_a_first_bit_number = 86,
		ram_block11a_86.port_a_last_address = 511,
		ram_block11a_86.port_a_logical_ram_depth = 512,
		ram_block11a_86.port_a_logical_ram_width = 97,
		ram_block11a_86.port_b_address_clear = "clear1",
		ram_block11a_86.port_b_address_clock = "clock1",
		ram_block11a_86.port_b_address_width = 9,
		ram_block11a_86.port_b_data_out_clear = "none",
		ram_block11a_86.port_b_data_width = 1,
		ram_block11a_86.port_b_first_address = 0,
		ram_block11a_86.port_b_first_bit_number = 86,
		ram_block11a_86.port_b_last_address = 511,
		ram_block11a_86.port_b_logical_ram_depth = 512,
		ram_block11a_86.port_b_logical_ram_width = 97,
		ram_block11a_86.port_b_read_enable_clock = "clock1",
		ram_block11a_86.ram_block_type = "AUTO",
		ram_block11a_86.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_87
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[87]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_87portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_87.clk0_core_clock_enable = "ena0",
		ram_block11a_87.clk0_input_clock_enable = "none",
		ram_block11a_87.clk1_core_clock_enable = "none",
		ram_block11a_87.clk1_input_clock_enable = "none",
		ram_block11a_87.connectivity_checking = "OFF",
		ram_block11a_87.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_87.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_87.operation_mode = "dual_port",
		ram_block11a_87.port_a_address_width = 9,
		ram_block11a_87.port_a_data_width = 1,
		ram_block11a_87.port_a_first_address = 0,
		ram_block11a_87.port_a_first_bit_number = 87,
		ram_block11a_87.port_a_last_address = 511,
		ram_block11a_87.port_a_logical_ram_depth = 512,
		ram_block11a_87.port_a_logical_ram_width = 97,
		ram_block11a_87.port_b_address_clear = "clear1",
		ram_block11a_87.port_b_address_clock = "clock1",
		ram_block11a_87.port_b_address_width = 9,
		ram_block11a_87.port_b_data_out_clear = "none",
		ram_block11a_87.port_b_data_width = 1,
		ram_block11a_87.port_b_first_address = 0,
		ram_block11a_87.port_b_first_bit_number = 87,
		ram_block11a_87.port_b_last_address = 511,
		ram_block11a_87.port_b_logical_ram_depth = 512,
		ram_block11a_87.port_b_logical_ram_width = 97,
		ram_block11a_87.port_b_read_enable_clock = "clock1",
		ram_block11a_87.ram_block_type = "AUTO",
		ram_block11a_87.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_88
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[88]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_88portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_88.clk0_core_clock_enable = "ena0",
		ram_block11a_88.clk0_input_clock_enable = "none",
		ram_block11a_88.clk1_core_clock_enable = "none",
		ram_block11a_88.clk1_input_clock_enable = "none",
		ram_block11a_88.connectivity_checking = "OFF",
		ram_block11a_88.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_88.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_88.operation_mode = "dual_port",
		ram_block11a_88.port_a_address_width = 9,
		ram_block11a_88.port_a_data_width = 1,
		ram_block11a_88.port_a_first_address = 0,
		ram_block11a_88.port_a_first_bit_number = 88,
		ram_block11a_88.port_a_last_address = 511,
		ram_block11a_88.port_a_logical_ram_depth = 512,
		ram_block11a_88.port_a_logical_ram_width = 97,
		ram_block11a_88.port_b_address_clear = "clear1",
		ram_block11a_88.port_b_address_clock = "clock1",
		ram_block11a_88.port_b_address_width = 9,
		ram_block11a_88.port_b_data_out_clear = "none",
		ram_block11a_88.port_b_data_width = 1,
		ram_block11a_88.port_b_first_address = 0,
		ram_block11a_88.port_b_first_bit_number = 88,
		ram_block11a_88.port_b_last_address = 511,
		ram_block11a_88.port_b_logical_ram_depth = 512,
		ram_block11a_88.port_b_logical_ram_width = 97,
		ram_block11a_88.port_b_read_enable_clock = "clock1",
		ram_block11a_88.ram_block_type = "AUTO",
		ram_block11a_88.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_89
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[89]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_89portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_89.clk0_core_clock_enable = "ena0",
		ram_block11a_89.clk0_input_clock_enable = "none",
		ram_block11a_89.clk1_core_clock_enable = "none",
		ram_block11a_89.clk1_input_clock_enable = "none",
		ram_block11a_89.connectivity_checking = "OFF",
		ram_block11a_89.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_89.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_89.operation_mode = "dual_port",
		ram_block11a_89.port_a_address_width = 9,
		ram_block11a_89.port_a_data_width = 1,
		ram_block11a_89.port_a_first_address = 0,
		ram_block11a_89.port_a_first_bit_number = 89,
		ram_block11a_89.port_a_last_address = 511,
		ram_block11a_89.port_a_logical_ram_depth = 512,
		ram_block11a_89.port_a_logical_ram_width = 97,
		ram_block11a_89.port_b_address_clear = "clear1",
		ram_block11a_89.port_b_address_clock = "clock1",
		ram_block11a_89.port_b_address_width = 9,
		ram_block11a_89.port_b_data_out_clear = "none",
		ram_block11a_89.port_b_data_width = 1,
		ram_block11a_89.port_b_first_address = 0,
		ram_block11a_89.port_b_first_bit_number = 89,
		ram_block11a_89.port_b_last_address = 511,
		ram_block11a_89.port_b_logical_ram_depth = 512,
		ram_block11a_89.port_b_logical_ram_width = 97,
		ram_block11a_89.port_b_read_enable_clock = "clock1",
		ram_block11a_89.ram_block_type = "AUTO",
		ram_block11a_89.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_90
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[90]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_90portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_90.clk0_core_clock_enable = "ena0",
		ram_block11a_90.clk0_input_clock_enable = "none",
		ram_block11a_90.clk1_core_clock_enable = "none",
		ram_block11a_90.clk1_input_clock_enable = "none",
		ram_block11a_90.connectivity_checking = "OFF",
		ram_block11a_90.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_90.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_90.operation_mode = "dual_port",
		ram_block11a_90.port_a_address_width = 9,
		ram_block11a_90.port_a_data_width = 1,
		ram_block11a_90.port_a_first_address = 0,
		ram_block11a_90.port_a_first_bit_number = 90,
		ram_block11a_90.port_a_last_address = 511,
		ram_block11a_90.port_a_logical_ram_depth = 512,
		ram_block11a_90.port_a_logical_ram_width = 97,
		ram_block11a_90.port_b_address_clear = "clear1",
		ram_block11a_90.port_b_address_clock = "clock1",
		ram_block11a_90.port_b_address_width = 9,
		ram_block11a_90.port_b_data_out_clear = "none",
		ram_block11a_90.port_b_data_width = 1,
		ram_block11a_90.port_b_first_address = 0,
		ram_block11a_90.port_b_first_bit_number = 90,
		ram_block11a_90.port_b_last_address = 511,
		ram_block11a_90.port_b_logical_ram_depth = 512,
		ram_block11a_90.port_b_logical_ram_width = 97,
		ram_block11a_90.port_b_read_enable_clock = "clock1",
		ram_block11a_90.ram_block_type = "AUTO",
		ram_block11a_90.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_91
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[91]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_91portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_91.clk0_core_clock_enable = "ena0",
		ram_block11a_91.clk0_input_clock_enable = "none",
		ram_block11a_91.clk1_core_clock_enable = "none",
		ram_block11a_91.clk1_input_clock_enable = "none",
		ram_block11a_91.connectivity_checking = "OFF",
		ram_block11a_91.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_91.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_91.operation_mode = "dual_port",
		ram_block11a_91.port_a_address_width = 9,
		ram_block11a_91.port_a_data_width = 1,
		ram_block11a_91.port_a_first_address = 0,
		ram_block11a_91.port_a_first_bit_number = 91,
		ram_block11a_91.port_a_last_address = 511,
		ram_block11a_91.port_a_logical_ram_depth = 512,
		ram_block11a_91.port_a_logical_ram_width = 97,
		ram_block11a_91.port_b_address_clear = "clear1",
		ram_block11a_91.port_b_address_clock = "clock1",
		ram_block11a_91.port_b_address_width = 9,
		ram_block11a_91.port_b_data_out_clear = "none",
		ram_block11a_91.port_b_data_width = 1,
		ram_block11a_91.port_b_first_address = 0,
		ram_block11a_91.port_b_first_bit_number = 91,
		ram_block11a_91.port_b_last_address = 511,
		ram_block11a_91.port_b_logical_ram_depth = 512,
		ram_block11a_91.port_b_logical_ram_width = 97,
		ram_block11a_91.port_b_read_enable_clock = "clock1",
		ram_block11a_91.ram_block_type = "AUTO",
		ram_block11a_91.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_92
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[92]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_92portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_92.clk0_core_clock_enable = "ena0",
		ram_block11a_92.clk0_input_clock_enable = "none",
		ram_block11a_92.clk1_core_clock_enable = "none",
		ram_block11a_92.clk1_input_clock_enable = "none",
		ram_block11a_92.connectivity_checking = "OFF",
		ram_block11a_92.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_92.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_92.operation_mode = "dual_port",
		ram_block11a_92.port_a_address_width = 9,
		ram_block11a_92.port_a_data_width = 1,
		ram_block11a_92.port_a_first_address = 0,
		ram_block11a_92.port_a_first_bit_number = 92,
		ram_block11a_92.port_a_last_address = 511,
		ram_block11a_92.port_a_logical_ram_depth = 512,
		ram_block11a_92.port_a_logical_ram_width = 97,
		ram_block11a_92.port_b_address_clear = "clear1",
		ram_block11a_92.port_b_address_clock = "clock1",
		ram_block11a_92.port_b_address_width = 9,
		ram_block11a_92.port_b_data_out_clear = "none",
		ram_block11a_92.port_b_data_width = 1,
		ram_block11a_92.port_b_first_address = 0,
		ram_block11a_92.port_b_first_bit_number = 92,
		ram_block11a_92.port_b_last_address = 511,
		ram_block11a_92.port_b_logical_ram_depth = 512,
		ram_block11a_92.port_b_logical_ram_width = 97,
		ram_block11a_92.port_b_read_enable_clock = "clock1",
		ram_block11a_92.ram_block_type = "AUTO",
		ram_block11a_92.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_93
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[93]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_93portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_93.clk0_core_clock_enable = "ena0",
		ram_block11a_93.clk0_input_clock_enable = "none",
		ram_block11a_93.clk1_core_clock_enable = "none",
		ram_block11a_93.clk1_input_clock_enable = "none",
		ram_block11a_93.connectivity_checking = "OFF",
		ram_block11a_93.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_93.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_93.operation_mode = "dual_port",
		ram_block11a_93.port_a_address_width = 9,
		ram_block11a_93.port_a_data_width = 1,
		ram_block11a_93.port_a_first_address = 0,
		ram_block11a_93.port_a_first_bit_number = 93,
		ram_block11a_93.port_a_last_address = 511,
		ram_block11a_93.port_a_logical_ram_depth = 512,
		ram_block11a_93.port_a_logical_ram_width = 97,
		ram_block11a_93.port_b_address_clear = "clear1",
		ram_block11a_93.port_b_address_clock = "clock1",
		ram_block11a_93.port_b_address_width = 9,
		ram_block11a_93.port_b_data_out_clear = "none",
		ram_block11a_93.port_b_data_width = 1,
		ram_block11a_93.port_b_first_address = 0,
		ram_block11a_93.port_b_first_bit_number = 93,
		ram_block11a_93.port_b_last_address = 511,
		ram_block11a_93.port_b_logical_ram_depth = 512,
		ram_block11a_93.port_b_logical_ram_width = 97,
		ram_block11a_93.port_b_read_enable_clock = "clock1",
		ram_block11a_93.ram_block_type = "AUTO",
		ram_block11a_93.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_94
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[94]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_94portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_94.clk0_core_clock_enable = "ena0",
		ram_block11a_94.clk0_input_clock_enable = "none",
		ram_block11a_94.clk1_core_clock_enable = "none",
		ram_block11a_94.clk1_input_clock_enable = "none",
		ram_block11a_94.connectivity_checking = "OFF",
		ram_block11a_94.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_94.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_94.operation_mode = "dual_port",
		ram_block11a_94.port_a_address_width = 9,
		ram_block11a_94.port_a_data_width = 1,
		ram_block11a_94.port_a_first_address = 0,
		ram_block11a_94.port_a_first_bit_number = 94,
		ram_block11a_94.port_a_last_address = 511,
		ram_block11a_94.port_a_logical_ram_depth = 512,
		ram_block11a_94.port_a_logical_ram_width = 97,
		ram_block11a_94.port_b_address_clear = "clear1",
		ram_block11a_94.port_b_address_clock = "clock1",
		ram_block11a_94.port_b_address_width = 9,
		ram_block11a_94.port_b_data_out_clear = "none",
		ram_block11a_94.port_b_data_width = 1,
		ram_block11a_94.port_b_first_address = 0,
		ram_block11a_94.port_b_first_bit_number = 94,
		ram_block11a_94.port_b_last_address = 511,
		ram_block11a_94.port_b_logical_ram_depth = 512,
		ram_block11a_94.port_b_logical_ram_width = 97,
		ram_block11a_94.port_b_read_enable_clock = "clock1",
		ram_block11a_94.ram_block_type = "AUTO",
		ram_block11a_94.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_95
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[95]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_95portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_95.clk0_core_clock_enable = "ena0",
		ram_block11a_95.clk0_input_clock_enable = "none",
		ram_block11a_95.clk1_core_clock_enable = "none",
		ram_block11a_95.clk1_input_clock_enable = "none",
		ram_block11a_95.connectivity_checking = "OFF",
		ram_block11a_95.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_95.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_95.operation_mode = "dual_port",
		ram_block11a_95.port_a_address_width = 9,
		ram_block11a_95.port_a_data_width = 1,
		ram_block11a_95.port_a_first_address = 0,
		ram_block11a_95.port_a_first_bit_number = 95,
		ram_block11a_95.port_a_last_address = 511,
		ram_block11a_95.port_a_logical_ram_depth = 512,
		ram_block11a_95.port_a_logical_ram_width = 97,
		ram_block11a_95.port_b_address_clear = "clear1",
		ram_block11a_95.port_b_address_clock = "clock1",
		ram_block11a_95.port_b_address_width = 9,
		ram_block11a_95.port_b_data_out_clear = "none",
		ram_block11a_95.port_b_data_width = 1,
		ram_block11a_95.port_b_first_address = 0,
		ram_block11a_95.port_b_first_bit_number = 95,
		ram_block11a_95.port_b_last_address = 511,
		ram_block11a_95.port_b_logical_ram_depth = 512,
		ram_block11a_95.port_b_logical_ram_width = 97,
		ram_block11a_95.port_b_read_enable_clock = "clock1",
		ram_block11a_95.ram_block_type = "AUTO",
		ram_block11a_95.lpm_type = "cycloneive_ram_block";
	cycloneive_ram_block   ram_block11a_96
	( 
	.clk0(clock0),
	.clk1(clock1),
	.clr1(aclr1),
	.ena0(wren_a),
	.portaaddr({address_a_wire[8:0]}),
	.portadatain({data_a[96]}),
	.portadataout(),
	.portawe(wren_a),
	.portbaddr({address_b_wire[8:0]}),
	.portbaddrstall(addressstall_b),
	.portbdataout(wire_ram_block11a_96portbdataout[0:0]),
	.portbre(1'b1)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_off
	`endif
	,
	.clr0(1'b0),
	.ena1(1'b1),
	.ena2(1'b1),
	.ena3(1'b1),
	.portaaddrstall(1'b0),
	.portabyteenamasks({1{1'b1}}),
	.portare(1'b1),
	.portbbyteenamasks({1{1'b1}}),
	.portbdatain({1{1'b0}}),
	.portbwe(1'b0)
	`ifndef FORMAL_VERIFICATION
	// synopsys translate_on
	`endif
	// synopsys translate_off
	,
	.devclrn(1'b1),
	.devpor(1'b1)
	// synopsys translate_on
	);
	defparam
		ram_block11a_96.clk0_core_clock_enable = "ena0",
		ram_block11a_96.clk0_input_clock_enable = "none",
		ram_block11a_96.clk1_core_clock_enable = "none",
		ram_block11a_96.clk1_input_clock_enable = "none",
		ram_block11a_96.connectivity_checking = "OFF",
		ram_block11a_96.logical_ram_name = "ALTSYNCRAM",
		ram_block11a_96.mixed_port_feed_through_mode = "dont_care",
		ram_block11a_96.operation_mode = "dual_port",
		ram_block11a_96.port_a_address_width = 9,
		ram_block11a_96.port_a_data_width = 1,
		ram_block11a_96.port_a_first_address = 0,
		ram_block11a_96.port_a_first_bit_number = 96,
		ram_block11a_96.port_a_last_address = 511,
		ram_block11a_96.port_a_logical_ram_depth = 512,
		ram_block11a_96.port_a_logical_ram_width = 97,
		ram_block11a_96.port_b_address_clear = "clear1",
		ram_block11a_96.port_b_address_clock = "clock1",
		ram_block11a_96.port_b_address_width = 9,
		ram_block11a_96.port_b_data_out_clear = "none",
		ram_block11a_96.port_b_data_width = 1,
		ram_block11a_96.port_b_first_address = 0,
		ram_block11a_96.port_b_first_bit_number = 96,
		ram_block11a_96.port_b_last_address = 511,
		ram_block11a_96.port_b_logical_ram_depth = 512,
		ram_block11a_96.port_b_logical_ram_width = 97,
		ram_block11a_96.port_b_read_enable_clock = "clock1",
		ram_block11a_96.ram_block_type = "AUTO",
		ram_block11a_96.lpm_type = "cycloneive_ram_block";
	assign
		address_a_wire = address_a,
		address_b_wire = address_b,
		q_b = {wire_ram_block11a_96portbdataout[0], wire_ram_block11a_95portbdataout[0], wire_ram_block11a_94portbdataout[0], wire_ram_block11a_93portbdataout[0], wire_ram_block11a_92portbdataout[0], wire_ram_block11a_91portbdataout[0], wire_ram_block11a_90portbdataout[0], wire_ram_block11a_89portbdataout[0], wire_ram_block11a_88portbdataout[0], wire_ram_block11a_87portbdataout[0], wire_ram_block11a_86portbdataout[0], wire_ram_block11a_85portbdataout[0], wire_ram_block11a_84portbdataout[0], wire_ram_block11a_83portbdataout[0], wire_ram_block11a_82portbdataout[0], wire_ram_block11a_81portbdataout[0], wire_ram_block11a_80portbdataout[0], wire_ram_block11a_79portbdataout[0], wire_ram_block11a_78portbdataout[0], wire_ram_block11a_77portbdataout[0], wire_ram_block11a_76portbdataout[0], wire_ram_block11a_75portbdataout[0], wire_ram_block11a_74portbdataout[0], wire_ram_block11a_73portbdataout[0], wire_ram_block11a_72portbdataout[0], wire_ram_block11a_71portbdataout[0], wire_ram_block11a_70portbdataout[0], wire_ram_block11a_69portbdataout[0], wire_ram_block11a_68portbdataout[0], wire_ram_block11a_67portbdataout[0], wire_ram_block11a_66portbdataout[0], wire_ram_block11a_65portbdataout[0], wire_ram_block11a_64portbdataout[0], wire_ram_block11a_63portbdataout[0], wire_ram_block11a_62portbdataout[0], wire_ram_block11a_61portbdataout[0], wire_ram_block11a_60portbdataout[0], wire_ram_block11a_59portbdataout[0], wire_ram_block11a_58portbdataout[0], wire_ram_block11a_57portbdataout[0], wire_ram_block11a_56portbdataout[0], wire_ram_block11a_55portbdataout[0], wire_ram_block11a_54portbdataout[0], wire_ram_block11a_53portbdataout[0], wire_ram_block11a_52portbdataout[0], wire_ram_block11a_51portbdataout[0], wire_ram_block11a_50portbdataout[0], wire_ram_block11a_49portbdataout[0], wire_ram_block11a_48portbdataout[0], wire_ram_block11a_47portbdataout[0], wire_ram_block11a_46portbdataout[0], wire_ram_block11a_45portbdataout[0], wire_ram_block11a_44portbdataout[0], wire_ram_block11a_43portbdataout[0], wire_ram_block11a_42portbdataout[0], wire_ram_block11a_41portbdataout[0]
, wire_ram_block11a_40portbdataout[0], wire_ram_block11a_39portbdataout[0], wire_ram_block11a_38portbdataout[0], wire_ram_block11a_37portbdataout[0], wire_ram_block11a_36portbdataout[0], wire_ram_block11a_35portbdataout[0], wire_ram_block11a_34portbdataout[0], wire_ram_block11a_33portbdataout[0], wire_ram_block11a_32portbdataout[0], wire_ram_block11a_31portbdataout[0], wire_ram_block11a_30portbdataout[0], wire_ram_block11a_29portbdataout[0], wire_ram_block11a_28portbdataout[0], wire_ram_block11a_27portbdataout[0], wire_ram_block11a_26portbdataout[0], wire_ram_block11a_25portbdataout[0], wire_ram_block11a_24portbdataout[0], wire_ram_block11a_23portbdataout[0], wire_ram_block11a_22portbdataout[0], wire_ram_block11a_21portbdataout[0], wire_ram_block11a_20portbdataout[0], wire_ram_block11a_19portbdataout[0], wire_ram_block11a_18portbdataout[0], wire_ram_block11a_17portbdataout[0], wire_ram_block11a_16portbdataout[0], wire_ram_block11a_15portbdataout[0], wire_ram_block11a_14portbdataout[0], wire_ram_block11a_13portbdataout[0], wire_ram_block11a_12portbdataout[0], wire_ram_block11a_11portbdataout[0], wire_ram_block11a_10portbdataout[0], wire_ram_block11a_9portbdataout[0], wire_ram_block11a_8portbdataout[0], wire_ram_block11a_7portbdataout[0], wire_ram_block11a_6portbdataout[0], wire_ram_block11a_5portbdataout[0], wire_ram_block11a_4portbdataout[0], wire_ram_block11a_3portbdataout[0], wire_ram_block11a_2portbdataout[0], wire_ram_block11a_1portbdataout[0], wire_ram_block11a_0portbdataout[0]};
endmodule //rx_fifo_altsyncram_f821


//dffpipe CBX_SINGLE_OUTPUT_FILE="ON" DELAY=2 WIDTH=1 clock clrn d q ALTERA_INTERNAL_OPTIONS=AUTO_SHIFT_REGISTER_RECOGNITION=OFF;suppress_da_rule_internal=S102
//VERSION_BEGIN 18.1 cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = reg 2 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"AUTO_SHIFT_REGISTER_RECOGNITION=OFF;suppress_da_rule_internal=S102"} *)
module  rx_fifo_dffpipe_e2f
	( 
	clock,
	clrn,
	d,
	q) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   clrn;
	input   [0:0]  d;
	output   [0:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   clock;
	tri1   clrn;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[0:0]	dffe12a;
	reg	[0:0]	dffe13a;
	wire ena;
	wire prn;
	wire sclr;

	// synopsys translate_off
	initial
		dffe12a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe12a <= {1{1'b1}};
		else if (clrn == 1'b0) dffe12a <= 1'b0;
		else if  (ena == 1'b1)   dffe12a <= (d & (~ sclr));
	// synopsys translate_off
	initial
		dffe13a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe13a <= {1{1'b1}};
		else if (clrn == 1'b0) dffe13a <= 1'b0;
		else if  (ena == 1'b1)   dffe13a <= (dffe12a & (~ sclr));
	assign
		ena = 1'b1,
		prn = 1'b1,
		q = dffe13a,
		sclr = 1'b0;
endmodule //rx_fifo_dffpipe_e2f


//dffpipe CBX_SINGLE_OUTPUT_FILE="ON" DELAY=2 WIDTH=10 clock clrn d q ALTERA_INTERNAL_OPTIONS=X_ON_VIOLATION_OPTION=OFF;SYNCHRONIZER_IDENTIFICATION=FORCED_IF_ASYNCHRONOUS;PRESERVE_REGISTER=ON;DONT_MERGE_REGISTER=ON;ADV_NETLIST_OPT_ALLOWED=NEVER_ALLOW
//VERSION_BEGIN 18.1 cbx_a_gray2bin 2018:09:12:13:04:24:SJ cbx_a_graycounter 2018:09:12:13:04:24:SJ cbx_altdpram 2018:09:12:13:04:24:SJ cbx_altera_counter 2018:09:12:13:04:24:SJ cbx_altera_gray_counter 2018:09:12:13:04:24:SJ cbx_altera_syncram 2018:09:12:13:04:24:SJ cbx_altera_syncram_nd_impl 2018:09:12:13:04:24:SJ cbx_altsyncram 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_dcfifo 2018:09:12:13:04:24:SJ cbx_fifo_common 2018:09:12:13:04:24:SJ cbx_lpm_add_sub 2018:09:12:13:04:24:SJ cbx_lpm_compare 2018:09:12:13:04:24:SJ cbx_lpm_counter 2018:09:12:13:04:24:SJ cbx_lpm_decode 2018:09:12:13:04:24:SJ cbx_lpm_mux 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_nadder 2018:09:12:13:04:24:SJ cbx_scfifo 2018:09:12:13:04:24:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_stratixiii 2018:09:12:13:04:24:SJ cbx_stratixv 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END


//dffpipe CBX_SINGLE_OUTPUT_FILE="ON" DELAY=2 WIDTH=10 clock clrn d q ALTERA_INTERNAL_OPTIONS=AUTO_SHIFT_REGISTER_RECOGNITION=OFF
//VERSION_BEGIN 18.1 cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = reg 20 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"AUTO_SHIFT_REGISTER_RECOGNITION=OFF"} *)
module  rx_fifo_dffpipe_44c
	( 
	clock,
	clrn,
	d,
	q) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   clrn;
	input   [9:0]  d;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   clock;
	tri1   clrn;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[9:0]	dffe15a;
	reg	[9:0]	dffe16a;
	wire ena;
	wire prn;
	wire sclr;

	// synopsys translate_off
	initial
		dffe15a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe15a <= {10{1'b1}};
		else if (clrn == 1'b0) dffe15a <= 10'b0;
		else if  (ena == 1'b1)   dffe15a <= (d & {10{(~ sclr)}});
	// synopsys translate_off
	initial
		dffe16a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe16a <= {10{1'b1}};
		else if (clrn == 1'b0) dffe16a <= 10'b0;
		else if  (ena == 1'b1)   dffe16a <= (dffe15a & {10{(~ sclr)}});
	assign
		ena = 1'b1,
		prn = 1'b1,
		q = dffe16a,
		sclr = 1'b0;
endmodule //rx_fifo_dffpipe_44c

//synthesis_resources = reg 20 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"X_ON_VIOLATION_OPTION=OFF;SYNCHRONIZER_IDENTIFICATION=FORCED_IF_ASYNCHRONOUS;PRESERVE_REGISTER=ON;DONT_MERGE_REGISTER=ON;ADV_NETLIST_OPT_ALLOWED=NEVER_ALLOW"} *)
module  rx_fifo_alt_synch_pipe_jeo
	( 
	clock,
	clrn,
	d,
	q) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   clrn;
	input   [9:0]  d;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1   clrn;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [9:0]   wire_dffpipe14_q;

	rx_fifo_dffpipe_44c   dffpipe14
	( 
	.clock(clock),
	.clrn(clrn),
	.d(d),
	.q(wire_dffpipe14_q));
	assign
		q = wire_dffpipe14_q;
endmodule //rx_fifo_alt_synch_pipe_jeo


//dffpipe CBX_SINGLE_OUTPUT_FILE="ON" DELAY=2 WIDTH=10 clock clrn d q ALTERA_INTERNAL_OPTIONS=X_ON_VIOLATION_OPTION=OFF;SYNCHRONIZER_IDENTIFICATION=FORCED_IF_ASYNCHRONOUS;PRESERVE_REGISTER=ON;DONT_MERGE_REGISTER=ON;ADV_NETLIST_OPT_ALLOWED=NEVER_ALLOW
//VERSION_BEGIN 18.1 cbx_a_gray2bin 2018:09:12:13:04:24:SJ cbx_a_graycounter 2018:09:12:13:04:24:SJ cbx_altdpram 2018:09:12:13:04:24:SJ cbx_altera_counter 2018:09:12:13:04:24:SJ cbx_altera_gray_counter 2018:09:12:13:04:24:SJ cbx_altera_syncram 2018:09:12:13:04:24:SJ cbx_altera_syncram_nd_impl 2018:09:12:13:04:24:SJ cbx_altsyncram 2018:09:12:13:04:24:SJ cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_dcfifo 2018:09:12:13:04:24:SJ cbx_fifo_common 2018:09:12:13:04:24:SJ cbx_lpm_add_sub 2018:09:12:13:04:24:SJ cbx_lpm_compare 2018:09:12:13:04:24:SJ cbx_lpm_counter 2018:09:12:13:04:24:SJ cbx_lpm_decode 2018:09:12:13:04:24:SJ cbx_lpm_mux 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_nadder 2018:09:12:13:04:24:SJ cbx_scfifo 2018:09:12:13:04:24:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_stratixiii 2018:09:12:13:04:24:SJ cbx_stratixv 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END


//dffpipe CBX_SINGLE_OUTPUT_FILE="ON" DELAY=2 WIDTH=10 clock clrn d q ALTERA_INTERNAL_OPTIONS=AUTO_SHIFT_REGISTER_RECOGNITION=OFF
//VERSION_BEGIN 18.1 cbx_mgl 2018:09:12:13:10:36:SJ cbx_stratixii 2018:09:12:13:04:24:SJ cbx_util_mgl 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = reg 20 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"AUTO_SHIFT_REGISTER_RECOGNITION=OFF"} *)
module  rx_fifo_dffpipe_54c
	( 
	clock,
	clrn,
	d,
	q) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   clrn;
	input   [9:0]  d;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   clock;
	tri1   clrn;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	reg	[9:0]	dffe18a;
	reg	[9:0]	dffe19a;
	wire ena;
	wire prn;
	wire sclr;

	// synopsys translate_off
	initial
		dffe18a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe18a <= {10{1'b1}};
		else if (clrn == 1'b0) dffe18a <= 10'b0;
		else if  (ena == 1'b1)   dffe18a <= (d & {10{(~ sclr)}});
	// synopsys translate_off
	initial
		dffe19a = 0;
	// synopsys translate_on
	always @ ( posedge clock or  negedge prn or  negedge clrn)
		if (prn == 1'b0) dffe19a <= {10{1'b1}};
		else if (clrn == 1'b0) dffe19a <= 10'b0;
		else if  (ena == 1'b1)   dffe19a <= (dffe18a & {10{(~ sclr)}});
	assign
		ena = 1'b1,
		prn = 1'b1,
		q = dffe19a,
		sclr = 1'b0;
endmodule //rx_fifo_dffpipe_54c

//synthesis_resources = reg 20 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"X_ON_VIOLATION_OPTION=OFF;SYNCHRONIZER_IDENTIFICATION=FORCED_IF_ASYNCHRONOUS;PRESERVE_REGISTER=ON;DONT_MERGE_REGISTER=ON;ADV_NETLIST_OPT_ALLOWED=NEVER_ALLOW"} *)
module  rx_fifo_alt_synch_pipe_keo
	( 
	clock,
	clrn,
	d,
	q) /* synthesis synthesis_clearbox=1 */;
	input   clock;
	input   clrn;
	input   [9:0]  d;
	output   [9:0]  q;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri1   clrn;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [9:0]   wire_dffpipe17_q;

	rx_fifo_dffpipe_54c   dffpipe17
	( 
	.clock(clock),
	.clrn(clrn),
	.d(d),
	.q(wire_dffpipe17_q));
	assign
		q = wire_dffpipe17_q;
endmodule //rx_fifo_alt_synch_pipe_keo


//lpm_compare CBX_SINGLE_OUTPUT_FILE="ON" DEVICE_FAMILY="Cyclone IV E" LPM_WIDTH=10 aeb dataa datab
//VERSION_BEGIN 18.1 cbx_cycloneii 2018:09:12:13:04:24:SJ cbx_lpm_add_sub 2018:09:12:13:04:24:SJ cbx_lpm_compare 2018:09:12:13:04:24:SJ cbx_mgl 2018:09:12:13:10:36:SJ cbx_nadder 2018:09:12:13:04:24:SJ cbx_stratix 2018:09:12:13:04:24:SJ cbx_stratixii 2018:09:12:13:04:24:SJ  VERSION_END

//synthesis_resources = 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
module  rx_fifo_cmpr_2t8
	( 
	aeb,
	dataa,
	datab) /* synthesis synthesis_clearbox=1 */;
	output   aeb;
	input   [9:0]  dataa;
	input   [9:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   [9:0]  dataa;
	tri0   [9:0]  datab;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [0:0]  aeb_result_wire;
	wire  [0:0]  aneb_result_wire;
	wire  [26:0]  data_wire;
	wire  eq_wire;

	assign
		aeb = eq_wire,
		aeb_result_wire = (~ aneb_result_wire),
		aneb_result_wire = (data_wire[0] | data_wire[1]),
		data_wire = {datab[9], dataa[9], datab[8], dataa[8], datab[7], dataa[7], datab[6], dataa[6], datab[5], dataa[5], datab[4], dataa[4], datab[3], dataa[3], datab[2], dataa[2], datab[1], dataa[1], datab[0], dataa[0], ((data_wire[23] ^ data_wire[24]) | (data_wire[25] ^ data_wire[26])), ((data_wire[19] ^ data_wire[20]) | (data_wire[21] ^ data_wire[22])), ((data_wire[15] ^ data_wire[16]) | (data_wire[17] ^ data_wire[18])), ((data_wire[11] ^ data_wire[12]) | (data_wire[13] ^ data_wire[14])), ((data_wire[7] ^ data_wire[8]) | (data_wire[9] ^ data_wire[10])), data_wire[6], (((data_wire[2] | data_wire[3]) | data_wire[4]) | data_wire[5])},
		eq_wire = aeb_result_wire;
endmodule //rx_fifo_cmpr_2t8

//synthesis_resources = M9K 6 reg 102 
//synopsys translate_off
`timescale 1 ps / 1 ps
//synopsys translate_on
(* ALTERA_ATTRIBUTE = {"AUTO_SHIFT_REGISTER_RECOGNITION=OFF;REMOVE_DUPLICATE_REGISTERS=OFF;SYNCHRONIZER_IDENTIFICATION=OFF;SYNCHRONIZATION_REGISTER_CHAIN_LENGTH = 2;suppress_da_rule_internal=d101;suppress_da_rule_internal=d102;suppress_da_rule_internal=d103;suppress_da_rule_internal=R105;-name CUT ON -from rdptr_g -to ws_dgrp|rx_fifo_dffpipe_54c:dffpipe17|dffe18a;-name SDC_STATEMENT \"set_false_path -from *rdptr_g* -to *ws_dgrp|rx_fifo_dffpipe_54c:dffpipe17|dffe18a* \";-name CUT ON -from delayed_wrptr_g -to rs_dgwp|rx_fifo_dffpipe_44c:dffpipe14|dffe15a;-name SDC_STATEMENT \"set_false_path -from *delayed_wrptr_g* -to *rs_dgwp|rx_fifo_dffpipe_44c:dffpipe14|dffe15a* \""} *)
module  rx_fifo
	( 
	aclr,
	data,
	q,
	rdclk,
	rdempty,
	rdreq,
	wrclk,
	wrfull,
	wrreq) /* synthesis synthesis_clearbox=1 */;
	input   aclr;
	input   [96:0]  data;
	output   [96:0]  q;
	input   rdclk;
	output   rdempty;
	input   rdreq;
	input   wrclk;
	output   wrfull;
	input   wrreq;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_off
`endif
	tri0   aclr;
`ifndef ALTERA_RESERVED_QIS
// synopsys translate_on
`endif

	wire  [9:0]   wire_rdptr_g1p_q;
	wire  [9:0]   wire_wrptr_g1p_q;
	wire  [96:0]   wire_fifo_ram_q_b;
	reg	[9:0]	delayed_wrptr_g;
	reg	[9:0]	rdptr_g;
	(* ALTERA_ATTRIBUTE = {"suppress_da_rule_internal=S102;POWER_UP_LEVEL=LOW"} *)
	reg	[9:0]	wrptr_g;
	wire  [0:0]   wire_rdaclr_q;
	wire  [9:0]   wire_rs_dgwp_q;
	wire  [0:0]   wire_wraclr_q;
	wire  [9:0]   wire_ws_dgrp_q;
	wire  wire_rdempty_eq_comp_aeb;
	wire  wire_wrfull_eq_comp_aeb;
	wire  int_rdempty;
	wire  int_wrfull;
	wire  [8:0]  ram_address_a;
	wire  [8:0]  ram_address_b;
	wire  valid_rdreq;
	wire  valid_wrreq;
	wire  [9:0]  wrptr_gs;

	rx_fifo_a_graycounter_gs9   rdptr_g1p
	( 
	.aclr((~ wire_rdaclr_q)),
	.clock(rdclk),
	.cnt_en(valid_rdreq),
	.q(wire_rdptr_g1p_q));
	rx_fifo_a_graycounter_caf   wrptr_g1p
	( 
	.aclr((~ wire_wraclr_q)),
	.clock(wrclk),
	.cnt_en(valid_wrreq),
	.q(wire_wrptr_g1p_q));
	rx_fifo_altsyncram_f821   fifo_ram
	( 
	.aclr1((~ wire_rdaclr_q)),
	.address_a(ram_address_a),
	.address_b(ram_address_b),
	.addressstall_b((~ valid_rdreq)),
	.clock0(wrclk),
	.clock1(rdclk),
	.data_a(data),
	.q_b(wire_fifo_ram_q_b),
	.wren_a(valid_wrreq));
	// synopsys translate_off
	initial
		delayed_wrptr_g = 0;
	// synopsys translate_on
	always @ ( posedge wrclk or  negedge wire_wraclr_q)
		if (wire_wraclr_q == 1'b0) delayed_wrptr_g <= 10'b0;
		else  delayed_wrptr_g <= wrptr_g;
	// synopsys translate_off
	initial
		rdptr_g = 0;
	// synopsys translate_on
	always @ ( posedge rdclk or  negedge wire_rdaclr_q)
		if (wire_rdaclr_q == 1'b0) rdptr_g <= 10'b0;
		else if  (valid_rdreq == 1'b1)   rdptr_g <= wire_rdptr_g1p_q;
	// synopsys translate_off
	initial
		wrptr_g = 0;
	// synopsys translate_on
	always @ ( posedge wrclk or  negedge wire_wraclr_q)
		if (wire_wraclr_q == 1'b0) wrptr_g <= 10'b0;
		else if  (valid_wrreq == 1'b1)   wrptr_g <= wire_wrptr_g1p_q;
	rx_fifo_dffpipe_e2f   rdaclr
	( 
	.clock(rdclk),
	.clrn((~ aclr)),
	.d(1'b1),
	.q(wire_rdaclr_q));
	rx_fifo_alt_synch_pipe_jeo   rs_dgwp
	( 
	.clock(rdclk),
	.clrn(wire_rdaclr_q),
	.d(delayed_wrptr_g),
	.q(wire_rs_dgwp_q));
	rx_fifo_dffpipe_e2f   wraclr
	( 
	.clock(wrclk),
	.clrn((~ aclr)),
	.d(1'b1),
	.q(wire_wraclr_q));
	rx_fifo_alt_synch_pipe_keo   ws_dgrp
	( 
	.clock(wrclk),
	.clrn(wire_wraclr_q),
	.d(rdptr_g),
	.q(wire_ws_dgrp_q));
	rx_fifo_cmpr_2t8   rdempty_eq_comp
	( 
	.aeb(wire_rdempty_eq_comp_aeb),
	.dataa(wire_rs_dgwp_q),
	.datab(rdptr_g));
	rx_fifo_cmpr_2t8   wrfull_eq_comp
	( 
	.aeb(wire_wrfull_eq_comp_aeb),
	.dataa(wire_ws_dgrp_q),
	.datab(wrptr_gs));
	assign
		int_rdempty = wire_rdempty_eq_comp_aeb,
		int_wrfull = wire_wrfull_eq_comp_aeb,
		q = wire_fifo_ram_q_b,
		ram_address_a = {(wrptr_g[9] ^ wrptr_g[8]), wrptr_g[7:0]},
		ram_address_b = {(wire_rdptr_g1p_q[9] ^ wire_rdptr_g1p_q[8]), wire_rdptr_g1p_q[7:0]},
		rdempty = int_rdempty,
		valid_rdreq = (rdreq & (~ (int_rdempty | (~ wire_rdaclr_q)))),
		valid_wrreq = (wrreq & (~ (int_wrfull | (~ wire_wraclr_q)))),
		wrfull = (int_wrfull | (~ wire_wraclr_q)),
		wrptr_gs = {(~ wrptr_g[9]), (~ wrptr_g[8]), wrptr_g[7:0]};
endmodule //rx_fifo
//VALID FILE
