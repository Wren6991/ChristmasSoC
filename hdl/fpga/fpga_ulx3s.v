/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

`default_nettype none

module fpga_ulx3s (
	input  wire        clk_osc,
	output wire [7:0]  led,

	// SDRAM
	output wire        sdram_clk,
	output wire [12:0] sdram_a,
	inout  wire [15:0] sdram_dq,
	output wire [1:0]  sdram_ba,
	output wire [1:0]  sdram_dqm,
	output wire        sdram_clke,
	output wire        sdram_cs_n,
	output wire        sdram_ras_n,
	output wire        sdram_cas_n,
	output wire        sdram_we_n,

	output wire        uart_tx,
	input  wire        uart_rx
);

// ----------------------------------------------------------------------------
// Clock + reset

wire clk_sys;
wire pll_sys_locked;
wire rst_n_por;

pll_25_40 pll_sys (
	.clkin   (clk_osc),
	.clkout0 (clk_sys),
	.locked  (pll_sys_locked)
);

fpga_reset #(
	.SHIFT (3)
) rstgen (
	.clk         (clk_sys),
	.force_rst_n (pll_sys_locked),
	.rst_n       (rst_n_por)
);

// ----------------------------------------------------------------------------
// Core instantiation

localparam W_SDRAM_BANKSEL = 2;
localparam W_SDRAM_ADDR = 13;
localparam W_SDRAM_DATA = 16;

localparam N_GPIOS      = 8;

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

wire [N_GPIOS-1:0]         gpio_o;
wire [N_GPIOS-1:0]         gpio_oe;
wire [N_GPIOS-1:0]         gpio_i;

christmas_soc #(
	.DTM_TYPE      ("ECP5")
) soc_u (
	.clk_sys              (clk_sys),
	.rst_n_por            (rst_n_por),

	// JTAG connections provided internally by ECP5 JTAGG primitive
	.tck                  (1'b0),
	.trst_n               (1'b0),
	.tms                  (1'b0),
	.tdi                  (1'b0),
	.tdo                  (/* unused */),

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

	.gpio_o               (gpio_o),
	.gpio_oe              (gpio_oe),
	.gpio_i               (gpio_i),

	.uart_tx              (uart_tx),
	.uart_rx              (uart_rx)
);

// ----------------------------------------------------------------------------
// IO resources

sdram_phy #(
	.W_SDRAM_BANKSEL(W_SDRAM_BANKSEL),
	.W_SDRAM_ADDR(W_SDRAM_ADDR),
	.W_SDRAM_DATA(W_SDRAM_DATA)
) sdram_phy_u (
	.clk             (clk_sys),
	.rst_n           (rst_n_por),

	.ctrl_clk_enable (sdram_phy_clk_enable),
	.ctrl_ba_next    (sdram_phy_ba_next),
	.ctrl_a_next     (sdram_phy_a_next),
	.ctrl_dqm_next   (sdram_phy_dqm_next),
	.ctrl_dq_o_next  (sdram_phy_dq_o_next),
	.ctrl_dq_oe_next (sdram_phy_dq_oe_next),
	.ctrl_dq_i       (sdram_phy_dq_i),
	.ctrl_clke_next  (sdram_phy_clke_next),
	.ctrl_cs_n_next  (sdram_phy_cs_n_next),
	.ctrl_ras_n_next (sdram_phy_ras_n_next),
	.ctrl_cas_n_next (sdram_phy_cas_n_next),
	.ctrl_we_n_next  (sdram_phy_we_n_next),

	.sdram_clk       (sdram_clk),
	.sdram_a         (sdram_a),
	.sdram_dq        (sdram_dq),
	.sdram_ba        (sdram_ba),
	.sdram_dqm       (sdram_dqm),
	.sdram_clke      (sdram_clke),
	.sdram_cs_n      (sdram_cs_n),
	.sdram_ras_n     (sdram_ras_n),
	.sdram_cas_n     (sdram_cas_n),
	.sdram_we_n      (sdram_we_n)
);

assign led = gpio_o;

endmodule
