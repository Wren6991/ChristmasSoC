/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Nothing much to see here. Possibly a synthesisable SDRAM model soon.

`default_nettype none

module tb (
	input  wire                       clk_sys,
	input  wire                       rst_n_por,

	input  wire                       tck,
	input  wire                       trst_n,
	input  wire                       tms,
	input  wire                       tdi,
	output wire                       tdo,

	output wire                       uart_tx,
	input  wire                       uart_rx
);

localparam W_SDRAM_BANKSEL = 2;
localparam W_SDRAM_ADDR = 13;
localparam W_SDRAM_DATA = 16;

// SDRAM-to-PHY signals
wire                       sdram_phy_clk_enable;
wire [W_SDRAM_BANKSEL-1:0] sdram_phy_ba_next;
wire [W_SDRAM_ADDR-1:0]    sdram_phy_a_next;
wire [W_SDRAM_DATA/8-1:0]  sdram_phy_dqm_next;

wire [W_SDRAM_DATA-1:0]    sdram_phy_dq_o_next;
wire                       sdram_phy_dq_oe_next;
wire [W_SDRAM_DATA-1:0]    sdram_phy_dq_i;

wire                       sdram_phy_clke_next;
wire                       sdram_phy_cs_n_next;
wire                       sdram_phy_ras_n_next;
wire                       sdram_phy_cas_n_next;
wire                       sdram_phy_we_n_next;


chistmas_soc #(
	.DTM_TYPE         ("JTAG"),
	.TCM_SIZE_BYTES   (4096),
	.TCM_PRELOAD_FILE ("bootloader32.hex"),
	.CACHE_SIZE_BYTES (4096)
) soc_u (
	.clk_sys              (clk_sys),
	.rst_n_por            (rst_n_por),

	.tck                  (tck),
	.trst_n               (trst_n),
	.tms                  (tms),
	.tdi                  (tdi),
	.tdo                  (tdo),

	.sdram_phy_clk_enable (sdram_phy_clk_enable),
	.sdram_phy_ba_next    (sdram_phy_ba_next),
	.sdram_phy_a_next     (sdram_phy_a_next),
	.sdram_phy_dqm_next   (sdram_phy_dqm_next),
	.sdram_phy_dq_o_next  (sdram_phy_dq_o_next),
	.sdram_phy_dq_oe_next (sdram_phy_dq_oe_next),
	.sdram_phy_dq_i       (sdram_phy_dq_i),
	.sdram_phy_clke_next  (sdram_phy_clke_next),
	.sdram_phy_cs_n_next  (sdram_phy_cs_n_next),
	.sdram_phy_ras_n_next (sdram_phy_ras_n_next),
	.sdram_phy_cas_n_next (sdram_phy_cas_n_next),
	.sdram_phy_we_n_next  (sdram_phy_we_n_next),

	.uart_tx              (uart_tx),
	.uart_rx              (uart_rx)
);

// ----------------------------------------------------------------------------

// Regular SDRAM interface, but with DQs replaced with separate D/Q buses to
// avoid using tristate logic
wire                       sdram_clk;
wire [W_SDRAM_BANKSEL-1:0] sdram_ba;
wire [W_SDRAM_ADDR-1:0]    sdram_a;
wire [W_SDRAM_DATA/8-1:0]  sdram_dqm;

reg  [W_SDRAM_DATA-1:0]    sdram_dq_o;
wire [W_SDRAM_DATA-1:0]    sdram_dq_i;

wire                       sdram_clke;
wire                       sdram_cs_n;
wire                       sdram_ras_n;
wire                       sdram_cas_n;
wire                       sdram_we_n;

// Remember, "synthesisable", not synthesisable
assign sdram_clk = !clk_sys && sdram_phy_clk_enable;

sdram_addr_buf addr_buf [W_SDRAM_ADDR-1:0] (
	.clk   (clk_sys),
	.rst_n (rst_n_por),
	.d     (sdram_phy_a_next),
	.q     (sdram_a)
);

sdram_addr_buf ctrl_buf [W_SDRAM_BANKSEL + W_SDRAM_DATA / 8 + 5 - 1 : 0] (
	.clk   (clk_sys),
	.rst_n (rst_n_por),
	.d     ({
		sdram_phy_ba_next,
		sdram_phy_dqm_next,
		sdram_phy_clke_next,
		sdram_phy_cs_n_next,
		sdram_phy_ras_n_next,
		sdram_phy_cas_n_next,
		sdram_phy_we_n_next
	}),
	.q     ({
		sdram_ba,
		sdram_dqm,
		sdram_clke,
		sdram_cs_n,
		sdram_ras_n,
		sdram_cas_n,
		sdram_we_n
	})
);

always @ (posedge clk_sys or negedge rst_n_por) begin
	if (!rst_n_por) begin
		sdram_dq_o <= {W_SDRAM_DATA{1'b0}};
	end else begin
		sdram_dq_o <= sdram_phy_dq_o_next & {W_SDRAM_DATA{sdram_phy_dq_oe_next}};
	end
end

reg [W_SDRAM_DATA-1:0] dq_i_neg;
reg [W_SDRAM_DATA-1:0] dq_i_pos;

always @ (negedge clk_sys or negedge rst_n_por) begin
	if (!rst_n_por) begin
		dq_i_neg <= {W_SDRAM_DATA{1'b0}};
	end else begin
		dq_i_neg <= sdram_dq_i;
	end
end

always @ (posedge clk_sys or negedge rst_n_por) begin
	if (!rst_n_por) begin
		dq_i_pos <= {W_SDRAM_DATA{1'b0}};
	end else begin
		dq_i_pos <= dq_i_neg;
	end
end

assign sdram_phy_dq_i = dq_i_pos;

// ----------------------------------------------------------------------------

sdram_model #(
	.W_BANKSEL   (W_SDRAM_BANKSEL),
	.W_ADDR      (W_SDRAM_ADDR),
	.W_DATA      (W_SDRAM_DATA),
	.W_ROW       (13),
	.W_COL       (10),
	.CAS_LATENCY (2),
	.BURST_LEN   (8)
) sdram (
	.clk_sys     (clk_sys),
	.sdram_ba    (sdram_ba),
	.sdram_a     (sdram_a),
	.sdram_dqm   (sdram_dqm),
	.sdram_dq_o  (sdram_dq_o),
	.sdram_dq_i  (sdram_dq_i),
	.sdram_clke  (sdram_clke),
	.sdram_cs_n  (sdram_cs_n),
	.sdram_ras_n (sdram_ras_n),
	.sdram_cas_n (sdram_cas_n),
	.sdram_we_n  (sdram_we_n)
);

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
