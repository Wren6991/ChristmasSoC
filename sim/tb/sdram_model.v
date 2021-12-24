/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Bare-minimum SDRAM model. Supports BankActivate, Read, Write. If the SDRAM
// controller is operating correctly, this model will return the correct data.
// No other guarantees.
//
// This is "synthesisable" (i.e. uses synthesisable constructs only) but is
// not something you would want to synthesise.

`default_nettype none

module sdram_model #(
	parameter W_BANKSEL   = 2,
	parameter W_ADDR      = 13,
	parameter W_DATA      = 16,
	parameter W_ROW       = 13,
	parameter W_COL       = 10,

	// Fixed-size bursts only. Wrapping is not implemented.
	parameter CAS_LATENCY = 2,
	parameter BURST_LEN   = 8
) (
	input  wire                 clk_sys, // Would use sdram_clk but CXXRTL is being weird

	input  wire [W_BANKSEL-1:0] sdram_ba,
	input  wire [W_ADDR-1:0]    sdram_a,
	input  wire [W_DATA/8-1:0]  sdram_dqm,

	input  wire [W_DATA-1:0]    sdram_dq_o,
	output wire [W_DATA-1:0]    sdram_dq_i,

	input  wire                 sdram_clke,
	input  wire                 sdram_cs_n,
	input  wire                 sdram_ras_n,
	input  wire                 sdram_cas_n,
	input  wire                 sdram_we_n
);

localparam W_FULL_ADDR = W_ROW + W_BANKSEL + W_COL;
localparam N_BANKS = 1 << W_BANKSEL;

// Shrink memory so we can trace it. 128 kiB is more than we need.
// localparam DEPTH = 1 << W_FULL_ADDR;
localparam DEPTH = 1 << 16;

reg [W_ROW-1:0] bank_addr [0:N_BANKS-1];

reg [W_DATA-1:0] mem [0:DEPTH-1];
reg [W_FULL_ADDR-1:0] burst_addr;
reg [W_DATA-1:0] rdata;

wire [3:0] sdram_cmd = {sdram_cs_n, sdram_ras_n, sdram_cas_n, sdram_we_n};
localparam CMD_ACTIVATE = 4'b0011;
localparam CMD_READ     = 4'b0101;
localparam CMD_WRITE    = 4'b0100;

reg [7:0] burst_count;
reg       burst_is_write;

wire [W_FULL_ADDR-1:0] bus_addr = {
	bank_addr[sdram_ba],
	sdram_ba,
	sdram_a[W_COL-1:0]
};

always @ (negedge clk_sys) begin
	if (sdram_cmd == CMD_WRITE) begin
		mem[bus_addr] <= sdram_dq_o;
		burst_is_write <= 1'b1;
		burst_addr <= bus_addr + 1'b1;
		burst_count <= BURST_LEN - 1;
	end else if (sdram_cmd == CMD_READ) begin
		rdata <= mem[bus_addr];
		burst_is_write <= 1'b0;
		burst_addr <= bus_addr + 1'b1;
		burst_count <= BURST_LEN - 1;
	end else if (sdram_cmd == CMD_ACTIVATE) begin
		bank_addr[sdram_ba] <= sdram_a;
	end else if (|burst_count && burst_is_write) begin
		mem[burst_addr] <= sdram_dq_o;
		burst_addr <= burst_addr + 1'b1;
		burst_count <= burst_count - 1;
	end else if (|burst_count && !burst_is_write) begin
		rdata <= mem[burst_addr];
		burst_addr <= burst_addr + 1'b1;
		burst_count <= burst_count - 1;
	end else begin
		rdata <= {W_DATA{1'b0}};
	end
end

reg [W_DATA-1:0] dq_i_delay [0:CAS_LATENCY-2];

always @ (negedge clk_sys) begin: dq_delay_shift
	integer i;
	dq_i_delay[0] <= rdata;
	for (i = 1; i < CAS_LATENCY - 1; i = i + 1) begin
		dq_i_delay[i] <= dq_i_delay[i - 1];
	end
end

assign sdram_dq_i = dq_i_delay[CAS_LATENCY - 2];

reg wtf;

always @ (posedge clk_sys) begin
	wtf <= !wtf;
end

reg wtf_n;

always @ (negedge clk_sys) begin
	if (sdram_cmd == CMD_WRITE)
		wtf_n <= !wtf_n;
end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
