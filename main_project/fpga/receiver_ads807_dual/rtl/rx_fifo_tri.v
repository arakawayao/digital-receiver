// Intel dcfifo megafunction. Parameters are the reproducible IP configuration.
module rx_fifo_tri #(
    parameter ADDRESS_BITS = 9
)(
    input wire aclr,
    input wire [287:0] data,
    input wire wrclk,
    input wire wrreq,
    output wire wrfull,
    input wire rdclk,
    input wire rdreq,
    output wire rdempty,
    output wire [287:0] q
);
    dcfifo #(
        .intended_device_family("Cyclone IV E"),
        .lpm_numwords(2**ADDRESS_BITS),
        .lpm_width(288),
        .lpm_widthu(ADDRESS_BITS),
        .lpm_showahead("ON"),
        .lpm_type("dcfifo"),
        .overflow_checking("ON"),
        .underflow_checking("ON"),
        .rdsync_delaypipe(4),
        .wrsync_delaypipe(4),
        .read_aclr_synch("ON"),
        .write_aclr_synch("ON"),
        .use_eab("ON")
    ) storage(
        .aclr(aclr), .data(data), .wrclk(wrclk), .wrreq(wrreq), .wrfull(wrfull),
        .rdclk(rdclk), .rdreq(rdreq), .rdempty(rdempty), .q(q),
        .rdfull(), .rdusedw(), .wrempty(), .wrusedw()
    );
endmodule
