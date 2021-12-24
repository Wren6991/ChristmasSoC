/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// RISC-V timer with two comparators and two timer IRQ outputs. Also bundle in
// two soft-IRQ registers with set/clear, and two soft IRQ outputs.

`default_nettype none

module platform_timer (
	input  wire        clk,
	input  wire        rst_n,

	input  wire        apbs_psel,
	input  wire        apbs_penable,
	input  wire        apbs_pwrite,
	input  wire [15:0] apbs_paddr,
	input  wire [31:0] apbs_pwdata,
	output wire [31:0] apbs_prdata,
	output wire        apbs_pready,
	output wire        apbs_pslverr,

	// Processor halt status
	input  wire        halt,

	output wire [1:0]  timer_irq,
	output wire [1:0]  soft_irq
);

reg  [63:0] mtime;
wire [63:0] mtime_wdata;
wire [1:0]  mtime_wen;

wire [63:0] mtimecmp0;
wire [63:0] mtimecmp1;

reg  [1:0]  soft_irq_reg;
wire [1:0]  soft_irq_clr;
wire        soft_irq_clr_wen;
wire [1:0]  soft_irq_set;
wire        soft_irq_set_wen;


timer_regs regs (
	.clk             (clk),
	.rst_n           (rst_n),

	.apbs_psel       (apbs_psel),
	.apbs_penable    (apbs_penable),
	.apbs_pwrite     (apbs_pwrite),
	.apbs_paddr      (apbs_paddr),
	.apbs_pwdata     (apbs_pwdata),
	.apbs_prdata     (apbs_prdata),
	.apbs_pready     (apbs_pready),
	.apbs_pslverr    (apbs_pslverr),

	.time_i          (mtime[31:0]),
	.time_o          (mtime_wdata[31:0]),
	.time_wen        (mtime_wen[0]),
	.time_ren        (/* unused */),
	.timeh_i         (mtime[63:32]),
	.timeh_o         (mtime_wdata[63:32]),
	.timeh_wen       (mtime_wen[1]),
	.timeh_ren       (/* unused */),
	.timecmp0_o      (mtimecmp0[31:0]),
	.timecmp0h_o     (mtimecmp0[63:32]),
	.timecmp1_o      (mtimecmp1[31:0]),
	.timecmp1h_o     (mtimecmp1[63:32]),

	.softirq_set_i   (soft_irq_reg),
	.softirq_set_o   (soft_irq_set),
	.softirq_set_wen (soft_irq_set_wen),
	.softirq_set_ren (/* unused */),
	.softirq_clr_i   (soft_irq_reg),
	.softirq_clr_o   (soft_irq_clr),
	.softirq_clr_wen (soft_irq_clr_wen),
	.softirq_clr_ren (/* unused */)
);

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		mtime <= 64'h0;
	end else begin
		if (!halt)
			mtime <= mtime + 64'h1;

		if (mtime_wen[1])
			mtime[63:32] <= mtime_wdata[63:32];
		if (mtime_wen[0])
			mtime[31:0]  <= mtime_wdata[31:0];		
	end
end

reg [1:0] timer_cmp_reg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		timer_cmp_reg <= 2'h0;
	end else begin
		timer_cmp_reg[0] <= mtime >= mtimecmp0;
		timer_cmp_reg[1] <= mtime >= mtimecmp1;
	end
end

assign timer_irq = timer_cmp_reg;

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		soft_irq_reg <= 2'h0;
	end else if (soft_irq_clr_wen) begin
		soft_irq_reg <= soft_irq_reg & ~soft_irq_clr;
	end else if (soft_irq_set_wen) begin
		soft_irq_reg <= soft_irq_reg | soft_irq_set;
	end
end

assign soft_irq = soft_irq_reg;

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
