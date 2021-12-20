/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Nothing much to see here. Possibly a synthesisable SDRAM model soon.

`default_nettype none

module tb (
	input  wire clk_sys,
	input  wire rst_n_por,

	input  wire tck,
	input  wire trst_n,
	input  wire tms,
	input  wire tdi,
	output wire tdo,

	output wire uart_tx,
	input  wire uart_rx
);

chistmas_soc #(
	.DTM_TYPE         ("JTAG"),
	.TCM_DEPTH        (1024),
	.TCM_PRELOAD_FILE (""),
	.CACHE_SIZE_BYTES (4096)
) soc_u (
	.clk_sys   (clk_sys),
	.rst_n_por (rst_n_por),
	.tck       (tck),
	.trst_n    (trst_n),
	.tms       (tms),
	.tdi       (tdi),
	.tdo       (tdo),
	.uart_tx   (uart_tx),
	.uart_rx   (uart_rx)
);

endmodule

`default_nettype wire
