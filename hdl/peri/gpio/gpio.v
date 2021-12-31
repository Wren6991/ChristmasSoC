/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

module gpio #(
	parameter N_GPIOS = 8
) (
	input  wire clk,
	input  wire rst_n,

	input  wire               apbs_psel,
	input  wire               apbs_penable,
	input  wire               apbs_pwrite,
	input  wire [15:0]        apbs_paddr,
	input  wire [31:0]        apbs_pwdata,
	output wire [31:0]        apbs_prdata,
	output wire               apbs_pready,
	output wire               apbs_pslverr,

	output wire [N_GPIOS-1:0] o,
	output wire [N_GPIOS-1:0] oe,
	input  wire [N_GPIOS-1:0] i
);

gpio_regs regs (
	.clk          (clk),
	.rst_n        (rst_n),

	.apbs_psel    (apbs_psel),
	.apbs_penable (apbs_penable),
	.apbs_pwrite  (apbs_pwrite),
	.apbs_paddr   (apbs_paddr),
	.apbs_pwdata  (apbs_pwdata),
	.apbs_prdata  (apbs_prdata),
	.apbs_pready  (apbs_pready),
	.apbs_pslverr (apbs_pslverr),

	.o_o          (o),
	.oe_o         (oe),
	.i_i          (i)
);

endmodule
