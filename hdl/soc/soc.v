/*****************************************************************************\
|                        Copyright (C) 2021 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Christmas SoC -- a minimal dual-core SoC built around Hazard3, at Christmas
//
// This file contains all the digital components of Christmas SoC, and is to
// be instantiated by a per-FPGA top-level file containing a PLL, a reset
// generator, and potentially some FPGA-specific IO primitives.
//
// Current features:
//
// - Standard RISC-V debug (0.13.2) with multicore support
// - Per-core local RAM (TCM) and shared system cache
// - A UART
// - Some more SRAM
//
// This will be expanded!

`default_nettype none

module chistmas_soc #(
	// can be "JTAG" or "ECP5". "JTAG" means the DTM connects to the
	// tck/tms/tdi/tdo pins on this module. "ECP5" means the DTM is attached to
	// the custom DR hooks on the ECP5 chip TAP, so the cores can be debugged
	// through the FPGA's own JTAG.
	parameter DTM_TYPE         = "JTAG",

	parameter TCM_SIZE_BYTES   = 1 << 12,
	parameter TCM_PRELOAD_FILE = "",

	parameter CACHE_SIZE_BYTES = 1 << 12,

	parameter W_SDRAM_DATA     = 16,
	parameter W_SDRAM_ADDR     = 13,
	parameter W_SDRAM_BANKSEL  = 2
) (
	input  wire                       clk_sys,

	// Power-on reset, including debug hardware. Resynchronised internally.
	input  wire                       rst_n_por,

	// JTAG port to RISC-V JTAG-DTM
	input  wire                       tck,
	input  wire                       trst_n,
	input  wire                       tms,
	input  wire                       tdi,
	output wire                       tdo,

	// SDRAM "PHY" interface (tristate avoidance)
	output wire                       sdram_phy_clk_enable,
	output wire [W_SDRAM_BANKSEL-1:0] sdram_phy_ba_next,
	output wire [W_SDRAM_ADDR-1:0]    sdram_phy_a_next,
	output wire [W_SDRAM_DATA/8-1:0]  sdram_phy_dqm_next,

	output wire [W_SDRAM_DATA-1:0]    sdram_phy_dq_o_next,
	output wire                       sdram_phy_dq_oe_next,
	input  wire [W_SDRAM_DATA-1:0]    sdram_phy_dq_i,

	output wire                       sdram_phy_clke_next,
	output wire                       sdram_phy_cs_n_next,
	output wire                       sdram_phy_ras_n_next,
	output wire                       sdram_phy_cas_n_next,
	output wire                       sdram_phy_we_n_next,

	// IO
	output wire                       uart_tx,
	input  wire                       uart_rx,

	output wire                       spi0_sclk,
	output wire                       spi0_cs_n,
	output wire                       spi0_sdo,
	input  wire                       spi0_sdi
);

// ----------------------------------------------------------------------------
// Processor debug

wire              dmi_psel;
wire              dmi_penable;
wire              dmi_pwrite;
wire [8:0]        dmi_paddr;
wire [31:0]       dmi_pwdata;
reg  [31:0]       dmi_prdata;
wire              dmi_pready;
wire              dmi_pslverr;

// TCK-domain DTM logic can force a hard reset of the DMI async bridge.
wire dmihardreset_req;
wire assert_dmi_reset = !rst_n_por || dmihardreset_req;
wire rst_n_dmi;

reset_sync dmi_reset_sync_u (
	.clk       (clk_sys),
	.rst_n_in  (!assert_dmi_reset),
	.rst_n_out (rst_n_dmi)
);

// DM is reset only at power-on.
wire rst_n_dm;

reset_sync dm_reset_sync_u (
	.clk       (clk_sys),
	.rst_n_in  (rst_n_por),
	.rst_n_out (rst_n_dm)
);

generate
if (DTM_TYPE == "JTAG") begin

	// Standard RISC-V JTAG-DTM connected to external IOs.
	// JTAG-DTM IDCODE should be a JEP106-compliant ID:
	localparam IDCODE = 32'hdeadbeef;

	hazard3_jtag_dtm #(
		.IDCODE (IDCODE)
	) dtm_u (
		.tck              (tck),
		.trst_n           (trst_n),
		.tms              (tms),
		.tdi              (tdi),
		.tdo              (tdo),

		.dmihardreset_req (dmihardreset_req),

		.clk_dmi          (clk_sys),
		.rst_n_dmi        (rst_n_dmi),

		.dmi_psel         (dmi_psel),
		.dmi_penable      (dmi_penable),
		.dmi_pwrite       (dmi_pwrite),
		.dmi_paddr        (dmi_paddr),
		.dmi_pwdata       (dmi_pwdata),
		.dmi_prdata       (dmi_prdata),
		.dmi_pready       (dmi_pready),
		.dmi_pslverr      (dmi_pslverr)
	);

end else if (DTM_TYPE == "ECP5") begin

	// Attach RISC-V DTM's DTMCS/DMI registers to ECP5 ER1/ER2 registers. This
	// allows the processor to be debugged through the ECP5 chip TAP, using
	// regular upstream OpenOCD.

	// Connects to ECP5 TAP internally by instantiating a JTAGG primitive.
	assign tdo = 1'b0;

	hazard3_ecp5_jtag_dtm dtm_u (
		.dmihardreset_req (dmihardreset_req),

		.clk_dmi          (clk_sys),
		.rst_n_dmi        (rst_n_dmi),

		.dmi_psel         (dmi_psel),
		.dmi_penable      (dmi_penable),
		.dmi_pwrite       (dmi_pwrite),
		.dmi_paddr        (dmi_paddr),
		.dmi_pwdata       (dmi_pwdata),
		.dmi_prdata       (dmi_prdata),
		.dmi_pready       (dmi_pready),
		.dmi_pslverr      (dmi_pslverr)
	);

end
endgenerate

localparam N_HARTS = 2;
localparam XLEN = 32;

wire                      sys_reset_req;
wire                      sys_reset_done;
wire [N_HARTS-1:0]        hart_reset_req;
wire [N_HARTS-1:0]        hart_reset_done;

wire [N_HARTS-1:0]        hart_req_halt;
wire [N_HARTS-1:0]        hart_req_halt_on_reset;
wire [N_HARTS-1:0]        hart_req_resume;
wire [N_HARTS-1:0]        hart_halted;
wire [N_HARTS-1:0]        hart_running;

wire [N_HARTS*XLEN-1:0]   hart_data0_rdata;
wire [N_HARTS*XLEN-1:0]   hart_data0_wdata;
wire [N_HARTS-1:0]        hart_data0_wen;

wire [N_HARTS*XLEN-1:0]   hart_instr_data;
wire [N_HARTS-1:0]        hart_instr_data_vld;
wire [N_HARTS-1:0]        hart_instr_data_rdy;
wire [N_HARTS-1:0]        hart_instr_caught_exception;
wire [N_HARTS-1:0]        hart_instr_caught_ebreak;

hazard3_dm #(
	.N_HARTS      (N_HARTS),
	.NEXT_DM_ADDR (0)
) dm (
	.clk                         (clk_sys),
	.rst_n                       (rst_n_dm),

	.dmi_psel                    (dmi_psel),
	.dmi_penable                 (dmi_penable),
	.dmi_pwrite                  (dmi_pwrite),
	.dmi_paddr                   (dmi_paddr),
	.dmi_pwdata                  (dmi_pwdata),
	.dmi_prdata                  (dmi_prdata),
	.dmi_pready                  (dmi_pready),
	.dmi_pslverr                 (dmi_pslverr),

	.sys_reset_req               (sys_reset_req),
	.sys_reset_done              (sys_reset_done),
	.hart_reset_req              (hart_reset_req),
	.hart_reset_done             (hart_reset_done),

	.hart_req_halt               (hart_req_halt),
	.hart_req_halt_on_reset      (hart_req_halt_on_reset),
	.hart_req_resume             (hart_req_resume),
	.hart_halted                 (hart_halted),
	.hart_running                (hart_running),

	.hart_data0_rdata            (hart_data0_rdata),
	.hart_data0_wdata            (hart_data0_wdata),
	.hart_data0_wen              (hart_data0_wen),

	.hart_instr_data             (hart_instr_data),
	.hart_instr_data_vld         (hart_instr_data_vld),
	.hart_instr_data_rdy         (hart_instr_data_rdy),
	.hart_instr_caught_exception (hart_instr_caught_exception),
	.hart_instr_caught_ebreak    (hart_instr_caught_ebreak)
);

wire assert_sys_reset = !rst_n_por || sys_reset_req;
wire assert_cpu0_reset = assert_sys_reset || hart_reset_req[0];
wire assert_cpu1_reset = assert_sys_reset || hart_reset_req[1];

wire rst_n_sys;
wire rst_n_cpu0;
wire rst_n_cpu1;

reset_sync sys_reset_sync (
	.clk       (clk_sys),
	.rst_n_in  (!assert_sys_reset),
	.rst_n_out (rst_n_sys)
);

reset_sync cpu0_reset_sync (
	.clk       (clk_sys),
	.rst_n_in  (!assert_cpu0_reset),
	.rst_n_out (rst_n_cpu0)
);

reset_sync cpu1_reset_sync (
	.clk       (clk_sys),
	.rst_n_in  (!assert_cpu1_reset),
	.rst_n_out (rst_n_cpu1)
);

// TODO these should be 2FF-synchronised and handshake extended to 4-phase

assign sys_reset_done = rst_n_sys;
assign hart_reset_done = {rst_n_cpu1, rst_n_cpu0};

// ----------------------------------------------------------------------------
// Processors

localparam W_ADDR = 32;
localparam W_DATA = 32;

// Hazard3 CPU configuration parameters from hazard3_config.vh:

// ----------------------------------------------------------------------------
// Reset state configuration

// RESET_VECTOR: Address of first instruction executed.
localparam RESET_VECTOR    = 32'h0;

// MTVEC_INIT: Initial value of trap vector base. Bits clear in MTVEC_WMASK
// will never change from this initial value. Bits set in MTVEC_WMASK can be
// written/set/cleared as normal.
//
// Note that, if CSR_M_TRAP is set, MTVEC_INIT should probably have a
// different value from RESET_VECTOR.
//
// Note that mtvec bits 1:0 do not affect the trap base (as per RISC-V spec).
// Bit 1 is don't care, bit 0 selects the vectoring mode: unvectored if == 0
// (all traps go to mtvec), vectored if == 1 (exceptions go to mtvec, IRQs to
// mtvec + mcause * 4). This means MTVEC_INIT also sets the initial vectoring
// mode.
localparam MTVEC_INIT      = 32'h00000000;

// ----------------------------------------------------------------------------
// RISC-V ISA and CSR support

// EXTENSION_A: Support for atomic read/modify/write instructions
// (currently, only lr.w/sc.w are supported)
localparam EXTENSION_A     = 1;

// EXTENSION_C: Support for compressed (variable-width) instructions
localparam EXTENSION_C     = 0;

// EXTENSION_M: Support for hardware multiply/divide/modulo instructions
localparam EXTENSION_M     = 1;

// EXTENSION_ZBA: Support for Zba address generation instructions
localparam EXTENSION_ZBA   = 0;

// EXTENSION_ZBB: Support for Zbb basic bit manipulation instructions
localparam EXTENSION_ZBB   = 0;

// EXTENSION_ZBC: Support for Zbc carry-less multiplication instructions
localparam EXTENSION_ZBC   = 0;

// EXTENSION_ZBS: Support for Zbs single-bit manipulation instructions
localparam EXTENSION_ZBS   = 0;

// CSR_M_MANDATORY: Bare minimum CSR support e.g. misa. Spec says must = 1 if
// CSRs are present, but I won't tell anyone.
localparam CSR_M_MANDATORY = 1;

// CSR_M_TRAP: Include M-mode trap-handling CSRs, and enable trap support.
localparam CSR_M_TRAP      = 1;

// CSR_COUNTER: Include performance counters and relevant M-mode CSRs
localparam CSR_COUNTER     = 1;

// DEBUG_SUPPORT: Support for run/halt and instruction injection from an
// external Debug Module, support for Debug Mode, and Debug Mode CSRs.
// Requires: CSR_M_MANDATORY, CSR_M_TRAP.
localparam DEBUG_SUPPORT   = 1;

// NUM_IRQ: Number of external IRQs implemented in meie0 and meip0.
// Minimum 1 (if CSR_M_TRAP = 1), maximum 32.
localparam NUM_IRQ         = 32;

// ----------------------------------------------------------------------------
// ID registers

// JEDEC JEP106-compliant vendor ID, can be left at 0 if "not implemented or
// [...] this is a non-commercial implementation" (RISC-V spec).
// 31:7 is continuation code count, 6:0 is ID. Parity bit is not stored.
localparam MVENDORID_VAL   = 32'hdeadbeef;

// Implementation ID for this specific version of Hazard3. Git hash is perfect.
localparam MIMPID_VAL      = 32'h0;

// Each core has a single hardware thread. Multiple cores should have unique IDs.
// localparam MHARTID_VAL     = 32'h0; // differs between cores

// Pointer to configuration structure blob, or all-zeroes. Must be at least
// 4-byte-aligned.
localparam MCONFIGPTR_VAL  = 32'h0;

// ----------------------------------------------------------------------------
// Performance/size options

// REDUCED_BYPASS: Remove all forwarding paths except X->X (so back-to-back
// ALU ops can still run at 1 CPI), to save area.
localparam REDUCED_BYPASS  = 0;

// MULDIV_UNROLL: Bits per clock for multiply/divide circuit, if present. Must
// be a power of 2.
localparam MULDIV_UNROLL   = 1;

// MUL_FAST: Use single-cycle multiply circuit for MUL instructions, retiring
// to stage M. The sequential multiply/divide circuit is still used for MULH*
localparam MUL_FAST        = 1;

// MULH_FAST: extend the fast multiply circuit to also cover MULH*, and remove
// the multiply functionality from the sequential multiply/divide circuit.
// Requires; MUL_FAST
localparam MULH_FAST       = 0;

// MTVEC_WMASK: Mask of which bits in MTVEC are modifiable. Save gates by
// making trap vector base partly fixed (legal, as it's WARL).
//
// - The vectoring mode can be made fixed by clearing the LSB of MTVEC_WMASK
//
// - Note the entire vector table must always be aligned to its size, rounded
//   up to a power of two, so careful with the low-order bits.
localparam MTVEC_WMASK     = 32'hfffffffd;

// ----------------------------------------------------------------------------
// Core instantiation

// Global
wire [31:0]       irq;
// Per-core
wire [1:0]        timer_irq;
wire [1:0]        soft_irq;

wire [W_ADDR-1:0] cpu0_haddr;
wire              cpu0_hwrite;
wire [1:0]        cpu0_htrans;
wire [2:0]        cpu0_hsize;
wire [2:0]        cpu0_hburst;
wire [3:0]        cpu0_hprot;
wire              cpu0_hmastlock;
wire              cpu0_hexcl;
wire              cpu0_hready;
wire              cpu0_hresp;
wire              cpu0_hexokay = 1'b1; // TODO global exclusives
wire [W_DATA-1:0] cpu0_hwdata;
wire [W_DATA-1:0] cpu0_hrdata;

hazard3_cpu_1port #(
	.RESET_VECTOR    (RESET_VECTOR   ),
	.MTVEC_INIT      (MTVEC_INIT     ),
	.EXTENSION_A     (EXTENSION_A    ),
	.EXTENSION_C     (EXTENSION_C    ),
	.EXTENSION_M     (EXTENSION_M    ),
	.EXTENSION_ZBA   (EXTENSION_ZBA  ),
	.EXTENSION_ZBB   (EXTENSION_ZBB  ),
	.EXTENSION_ZBC   (EXTENSION_ZBC  ),
	.EXTENSION_ZBS   (EXTENSION_ZBS  ),
	.CSR_M_MANDATORY (CSR_M_MANDATORY),
	.CSR_M_TRAP      (CSR_M_TRAP     ),
	.CSR_COUNTER     (CSR_COUNTER    ),
	.DEBUG_SUPPORT   (DEBUG_SUPPORT  ),
	.NUM_IRQ         (NUM_IRQ        ),
	.MVENDORID_VAL   (MVENDORID_VAL  ),
	.MIMPID_VAL      (MIMPID_VAL     ),
	.MHARTID_VAL     (32'h0          ),
	.MCONFIGPTR_VAL  (MCONFIGPTR_VAL ),
	.REDUCED_BYPASS  (REDUCED_BYPASS ),
	.MULDIV_UNROLL   (MULDIV_UNROLL  ),
	.MUL_FAST        (MUL_FAST       ),
	.MULH_FAST       (MULH_FAST      ),
	.MTVEC_WMASK     (MTVEC_WMASK    )

) cpu0 (
	.clk                        (clk_sys                                      ),
	.rst_n                      (rst_n_cpu0                                   ),

	.ahblm_haddr                (cpu0_haddr                                   ),
	.ahblm_hwrite               (cpu0_hwrite                                  ),
	.ahblm_htrans               (cpu0_htrans                                  ),
	.ahblm_hsize                (cpu0_hsize                                   ),
	.ahblm_hburst               (cpu0_hburst                                  ),
	.ahblm_hprot                (cpu0_hprot                                   ),
	.ahblm_hmastlock            (cpu0_hmastlock                               ),
	.ahblm_hexcl                (cpu0_hexcl                                   ),
	.ahblm_hready               (cpu0_hready                                  ),
	.ahblm_hresp                (cpu0_hresp                                   ),
	.ahblm_hexokay              (cpu0_hexokay                                 ),
	.ahblm_hwdata               (cpu0_hwdata                                  ),
	.ahblm_hrdata               (cpu0_hrdata                                  ),

	.dbg_req_halt               (hart_req_halt              [0               ]),
	.dbg_req_halt_on_reset      (hart_req_halt_on_reset     [0               ]),
	.dbg_req_resume             (hart_req_resume            [0               ]),
	.dbg_halted                 (hart_halted                [0               ]),
	.dbg_running                (hart_running               [0               ]),

	.dbg_data0_rdata            (hart_data0_rdata           [0 * XLEN +: XLEN]),
	.dbg_data0_wdata            (hart_data0_wdata           [0 * XLEN +: XLEN]),
	.dbg_data0_wen              (hart_data0_wen             [0               ]),

	.dbg_instr_data             (hart_instr_data            [0 * XLEN +: XLEN]),
	.dbg_instr_data_vld         (hart_instr_data_vld        [0               ]),
	.dbg_instr_data_rdy         (hart_instr_data_rdy        [0               ]),
	.dbg_instr_caught_exception (hart_instr_caught_exception[0               ]),
	.dbg_instr_caught_ebreak    (hart_instr_caught_ebreak   [0               ]),

	.irq                        (irq                                          ),
	.soft_irq                   (soft_irq                   [0               ]),
	.timer_irq                  (timer_irq                  [0               ])
);

wire [W_ADDR-1:0] cpu1_haddr;
wire              cpu1_hwrite;
wire [1:0]        cpu1_htrans;
wire [2:0]        cpu1_hsize;
wire [2:0]        cpu1_hburst;
wire [3:0]        cpu1_hprot;
wire              cpu1_hmastlock;
wire              cpu1_hexcl;
wire              cpu1_hready;
wire              cpu1_hresp;
wire              cpu1_hexokay = 1'b1; // TODO global exclusives
wire [W_DATA-1:0] cpu1_hwdata;
wire [W_DATA-1:0] cpu1_hrdata;

hazard3_cpu_1port #(
	.RESET_VECTOR    (RESET_VECTOR   ),
	.MTVEC_INIT      (MTVEC_INIT     ),
	.EXTENSION_A     (EXTENSION_A    ),
	.EXTENSION_C     (EXTENSION_C    ),
	.EXTENSION_M     (EXTENSION_M    ),
	.EXTENSION_ZBA   (EXTENSION_ZBA  ),
	.EXTENSION_ZBB   (EXTENSION_ZBB  ),
	.EXTENSION_ZBC   (EXTENSION_ZBC  ),
	.EXTENSION_ZBS   (EXTENSION_ZBS  ),
	.CSR_M_MANDATORY (CSR_M_MANDATORY),
	.CSR_M_TRAP      (CSR_M_TRAP     ),
	.CSR_COUNTER     (CSR_COUNTER    ),
	.DEBUG_SUPPORT   (DEBUG_SUPPORT  ),
	.NUM_IRQ         (NUM_IRQ        ),
	.MVENDORID_VAL   (MVENDORID_VAL  ),
	.MIMPID_VAL      (MIMPID_VAL     ),
	.MHARTID_VAL     (32'h1          ),
	.MCONFIGPTR_VAL  (MCONFIGPTR_VAL ),
	.REDUCED_BYPASS  (REDUCED_BYPASS ),
	.MULDIV_UNROLL   (MULDIV_UNROLL  ),
	.MUL_FAST        (MUL_FAST       ),
	.MULH_FAST       (MULH_FAST      ),
	.MTVEC_WMASK     (MTVEC_WMASK    )

) cpu1 (
	.clk                        (clk_sys                                      ),
	.rst_n                      (rst_n_cpu1                                   ),

	.ahblm_haddr                (cpu1_haddr                                   ),
	.ahblm_hwrite               (cpu1_hwrite                                  ),
	.ahblm_htrans               (cpu1_htrans                                  ),
	.ahblm_hsize                (cpu1_hsize                                   ),
	.ahblm_hburst               (cpu1_hburst                                  ),
	.ahblm_hprot                (cpu1_hprot                                   ),
	.ahblm_hmastlock            (cpu1_hmastlock                               ),
	.ahblm_hexcl                (cpu1_hexcl                                   ),
	.ahblm_hready               (cpu1_hready                                  ),
	.ahblm_hresp                (cpu1_hresp                                   ),
	.ahblm_hexokay              (cpu1_hexokay                                 ),
	.ahblm_hwdata               (cpu1_hwdata                                  ),
	.ahblm_hrdata               (cpu1_hrdata                                  ),

	.dbg_req_halt               (hart_req_halt              [1               ]),
	.dbg_req_halt_on_reset      (hart_req_halt_on_reset     [1               ]),
	.dbg_req_resume             (hart_req_resume            [1               ]),
	.dbg_halted                 (hart_halted                [1               ]),
	.dbg_running                (hart_running               [1               ]),

	.dbg_data0_rdata            (hart_data0_rdata           [1 * XLEN +: XLEN]),
	.dbg_data0_wdata            (hart_data0_wdata           [1 * XLEN +: XLEN]),
	.dbg_data0_wen              (hart_data0_wen             [1               ]),

	.dbg_instr_data             (hart_instr_data            [1 * XLEN +: XLEN]),
	.dbg_instr_data_vld         (hart_instr_data_vld        [1               ]),
	.dbg_instr_data_rdy         (hart_instr_data_rdy        [1               ]),
	.dbg_instr_caught_exception (hart_instr_caught_exception[1               ]),
	.dbg_instr_caught_ebreak    (hart_instr_caught_ebreak   [1               ]),

	.irq                        (irq                                          ),
	.soft_irq                   (soft_irq                   [1               ]),
	.timer_irq                  (timer_irq                  [1               ])
);

// ----------------------------------------------------------------------------
// Fabric layer 0: TCMs and System Cache

// TCMs are at address                           32'h0000_0000 (same for both cores)
// SDRAM (through cache, cached) is at address   32'h0800_0000 (must be 64M in size)
// IO    (through cache, uncached) is at address 32'h0c00_0000

wire [W_ADDR-1:0] cpu0_to_tcm_haddr;
wire              cpu0_to_tcm_hwrite;
wire [1:0]        cpu0_to_tcm_htrans;
wire [2:0]        cpu0_to_tcm_hsize;
wire [2:0]        cpu0_to_tcm_hburst;
wire [3:0]        cpu0_to_tcm_hprot;
wire              cpu0_to_tcm_hmastlock;
wire              cpu0_to_tcm_hexcl;
wire              cpu0_to_tcm_hready;
wire              cpu0_to_tcm_hready_resp;
wire              cpu0_to_tcm_hresp;
wire              cpu0_to_tcm_hexokay;
wire [W_DATA-1:0] cpu0_to_tcm_hwdata;
wire [W_DATA-1:0] cpu0_to_tcm_hrdata;

wire [W_ADDR-1:0] cpu1_to_tcm_haddr;
wire              cpu1_to_tcm_hwrite;
wire [1:0]        cpu1_to_tcm_htrans;
wire [2:0]        cpu1_to_tcm_hsize;
wire [2:0]        cpu1_to_tcm_hburst;
wire [3:0]        cpu1_to_tcm_hprot;
wire              cpu1_to_tcm_hmastlock;
wire              cpu1_to_tcm_hexcl;
wire              cpu1_to_tcm_hready;
wire              cpu1_to_tcm_hready_resp;
wire              cpu1_to_tcm_hresp;
wire              cpu1_to_tcm_hexokay;
wire [W_DATA-1:0] cpu1_to_tcm_hwdata;
wire [W_DATA-1:0] cpu1_to_tcm_hrdata;

wire [W_ADDR-1:0] cpu0_to_cache_haddr;
wire              cpu0_to_cache_hwrite;
wire [1:0]        cpu0_to_cache_htrans;
wire [2:0]        cpu0_to_cache_hsize;
wire [2:0]        cpu0_to_cache_hburst;
wire [3:0]        cpu0_to_cache_hprot;
wire              cpu0_to_cache_hmastlock;
wire              cpu0_to_cache_hexcl;
wire              cpu0_to_cache_hready;
wire              cpu0_to_cache_hready_resp;
wire              cpu0_to_cache_hresp;
wire              cpu0_to_cache_hexokay;
wire [W_DATA-1:0] cpu0_to_cache_hwdata;
wire [W_DATA-1:0] cpu0_to_cache_hrdata;

wire [W_ADDR-1:0] cpu1_to_cache_haddr;
wire              cpu1_to_cache_hwrite;
wire [1:0]        cpu1_to_cache_htrans;
wire [2:0]        cpu1_to_cache_hsize;
wire [2:0]        cpu1_to_cache_hburst;
wire [3:0]        cpu1_to_cache_hprot;
wire              cpu1_to_cache_hmastlock;
wire              cpu1_to_cache_hexcl;
wire              cpu1_to_cache_hready;
wire              cpu1_to_cache_hready_resp;
wire              cpu1_to_cache_hresp;
wire              cpu1_to_cache_hexokay;
wire [W_DATA-1:0] cpu1_to_cache_hwdata;
wire [W_DATA-1:0] cpu1_to_cache_hrdata;

wire [W_ADDR-1:0] cache_src_haddr;
wire              cache_src_hwrite;
wire [1:0]        cache_src_htrans;
wire [2:0]        cache_src_hsize;
wire [2:0]        cache_src_hburst;
wire [3:0]        cache_src_hprot;
wire              cache_src_hmastlock;
wire              cache_src_hexcl;
wire              cache_src_hready;
wire              cache_src_hready_resp;
wire              cache_src_hresp;
wire              cache_src_hexokay;
wire [W_DATA-1:0] cache_src_hwdata;
wire [W_DATA-1:0] cache_src_hrdata;

ahbl_splitter #(
	.N_PORTS     (2),
	.W_ADDR      (W_ADDR),
	.W_DATA      (W_DATA),
	.ADDR_MAP    (64'h08000000_00000000),
	.ADDR_MASK   (64'h08000000_08000000)
) split_cpu0 (
	.clk             (clk_sys       ),
	.rst_n           (rst_n_sys     ),

	.src_hready      (cpu0_hready   ), // TODO exclusives!
	.src_hready_resp (cpu0_hready   ),
	.src_hresp       (cpu0_hresp    ),
	.src_haddr       (cpu0_haddr    ),
	.src_hwrite      (cpu0_hwrite   ),
	.src_htrans      (cpu0_htrans   ),
	.src_hsize       (cpu0_hsize    ),
	.src_hburst      (cpu0_hburst   ),
	.src_hprot       (cpu0_hprot    ),
	.src_hmastlock   (cpu0_hmastlock),
	.src_hwdata      (cpu0_hwdata   ),
	.src_hrdata      (cpu0_hrdata   ),

	.dst_hready      ({cpu0_to_cache_hready      , cpu0_to_tcm_hready     }),
	.dst_hready_resp ({cpu0_to_cache_hready_resp , cpu0_to_tcm_hready_resp}),
	.dst_hresp       ({cpu0_to_cache_hresp       , cpu0_to_tcm_hresp      }),
	.dst_haddr       ({cpu0_to_cache_haddr       , cpu0_to_tcm_haddr      }),
	.dst_hwrite      ({cpu0_to_cache_hwrite      , cpu0_to_tcm_hwrite     }),
	.dst_htrans      ({cpu0_to_cache_htrans      , cpu0_to_tcm_htrans     }),
	.dst_hsize       ({cpu0_to_cache_hsize       , cpu0_to_tcm_hsize      }),
	.dst_hburst      ({cpu0_to_cache_hburst      , cpu0_to_tcm_hburst     }),
	.dst_hprot       ({cpu0_to_cache_hprot       , cpu0_to_tcm_hprot      }),
	.dst_hmastlock   ({cpu0_to_cache_hmastlock   , cpu0_to_tcm_hmastlock  }),
	.dst_hwdata      ({cpu0_to_cache_hwdata      , cpu0_to_tcm_hwdata     }),
	.dst_hrdata      ({cpu0_to_cache_hrdata      , cpu0_to_tcm_hrdata     })
);

ahbl_splitter #(
	.N_PORTS     (2),
	.W_ADDR      (W_ADDR),
	.W_DATA      (W_DATA),
	.ADDR_MAP    (64'h08000000_00000000),
	.ADDR_MASK   (64'h08000000_08000000)
) split_cpu1 (
	.clk             (clk_sys       ),
	.rst_n           (rst_n_sys     ),

	.src_hready      (cpu1_hready   ), // TODO exclusives!
	.src_hready_resp (cpu1_hready   ),
	.src_hresp       (cpu1_hresp    ),
	.src_haddr       (cpu1_haddr    ),
	.src_hwrite      (cpu1_hwrite   ),
	.src_htrans      (cpu1_htrans   ),
	.src_hsize       (cpu1_hsize    ),
	.src_hburst      (cpu1_hburst   ),
	.src_hprot       (cpu1_hprot    ),
	.src_hmastlock   (cpu1_hmastlock),
	.src_hwdata      (cpu1_hwdata   ),
	.src_hrdata      (cpu1_hrdata   ),

	.dst_hready      ({cpu1_to_cache_hready      , cpu1_to_tcm_hready     }),
	.dst_hready_resp ({cpu1_to_cache_hready_resp , cpu1_to_tcm_hready_resp}),
	.dst_hresp       ({cpu1_to_cache_hresp       , cpu1_to_tcm_hresp      }),
	.dst_haddr       ({cpu1_to_cache_haddr       , cpu1_to_tcm_haddr      }),
	.dst_hwrite      ({cpu1_to_cache_hwrite      , cpu1_to_tcm_hwrite     }),
	.dst_htrans      ({cpu1_to_cache_htrans      , cpu1_to_tcm_htrans     }),
	.dst_hsize       ({cpu1_to_cache_hsize       , cpu1_to_tcm_hsize      }),
	.dst_hburst      ({cpu1_to_cache_hburst      , cpu1_to_tcm_hburst     }),
	.dst_hprot       ({cpu1_to_cache_hprot       , cpu1_to_tcm_hprot      }),
	.dst_hmastlock   ({cpu1_to_cache_hmastlock   , cpu1_to_tcm_hmastlock  }),
	.dst_hwdata      ({cpu1_to_cache_hwdata      , cpu1_to_tcm_hwdata     }),
	.dst_hrdata      ({cpu1_to_cache_hrdata      , cpu1_to_tcm_hrdata     })
);

ahbl_arbiter #(
	.N_PORTS (2),
	.W_ADDR  (W_ADDR),
	.W_DATA  (W_DATA)
) arbiter_cache (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready      ({cpu1_to_cache_hready      , cpu0_to_cache_hready     }),
	.src_hready_resp ({cpu1_to_cache_hready_resp , cpu0_to_cache_hready_resp}),
	.src_hresp       ({cpu1_to_cache_hresp       , cpu0_to_cache_hresp      }),
	.src_haddr       ({cpu1_to_cache_haddr       , cpu0_to_cache_haddr      }),
	.src_hwrite      ({cpu1_to_cache_hwrite      , cpu0_to_cache_hwrite     }),
	.src_htrans      ({cpu1_to_cache_htrans      , cpu0_to_cache_htrans     }),
	.src_hsize       ({cpu1_to_cache_hsize       , cpu0_to_cache_hsize      }),
	.src_hburst      ({cpu1_to_cache_hburst      , cpu0_to_cache_hburst     }),
	.src_hprot       ({cpu1_to_cache_hprot       , cpu0_to_cache_hprot      }),
	.src_hmastlock   ({cpu1_to_cache_hmastlock   , cpu0_to_cache_hmastlock  }),
	.src_hwdata      ({cpu1_to_cache_hwdata      , cpu0_to_cache_hwdata     }),
	.src_hrdata      ({cpu1_to_cache_hrdata      , cpu0_to_cache_hrdata     }),

	.dst_hready      (cache_src_hready     ),
	.dst_hready_resp (cache_src_hready_resp),
	.dst_hresp       (cache_src_hresp      ),
	.dst_haddr       (cache_src_haddr      ),
	.dst_hwrite      (cache_src_hwrite     ),
	.dst_htrans      (cache_src_htrans     ),
	.dst_hsize       (cache_src_hsize      ),
	.dst_hburst      (cache_src_hburst     ),
	.dst_hprot       (cache_src_hprot      ),
	.dst_hmastlock   (cache_src_hmastlock  ),
	.dst_hwdata      (cache_src_hwdata     ),
	.dst_hrdata      (cache_src_hrdata     )
);

// ----------------------------------------------------------------------------
// Memories for layer 0

// Note both TCMs get the same preload contents. Software needs to check which
// core it is running on (via `mhartid`), and presumably put core 1 to sleep
// until core 0 loads a suitable program binary into main memory.

ahb_sync_sram #(
	.W_DATA       (W_DATA),
	.W_ADDR       (W_ADDR),
	.DEPTH        (TCM_SIZE_BYTES / (W_DATA / 8)),
	.PRELOAD_FILE (TCM_PRELOAD_FILE)
) cpu0_tcm (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),
	.ahbls_hready_resp (cpu0_to_tcm_hready_resp),
	.ahbls_hready      (cpu0_to_tcm_hready),
	.ahbls_hresp       (cpu0_to_tcm_hresp),
	.ahbls_haddr       (cpu0_to_tcm_haddr),
	.ahbls_hwrite      (cpu0_to_tcm_hwrite),
	.ahbls_htrans      (cpu0_to_tcm_htrans),
	.ahbls_hsize       (cpu0_to_tcm_hsize),
	.ahbls_hburst      (cpu0_to_tcm_hburst),
	.ahbls_hprot       (cpu0_to_tcm_hprot),
	.ahbls_hmastlock   (cpu0_to_tcm_hmastlock),
	.ahbls_hwdata      (cpu0_to_tcm_hwdata),
	.ahbls_hrdata      (cpu0_to_tcm_hrdata)
);

ahb_sync_sram #(
	.W_DATA       (W_DATA),
	.W_ADDR       (W_ADDR),
	.DEPTH        (TCM_SIZE_BYTES / (W_DATA / 8)),
	.PRELOAD_FILE (TCM_PRELOAD_FILE)
) cpu1_tcm (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),
	.ahbls_hready_resp (cpu1_to_tcm_hready_resp),
	.ahbls_hready      (cpu1_to_tcm_hready),
	.ahbls_hresp       (cpu1_to_tcm_hresp),
	.ahbls_haddr       (cpu1_to_tcm_haddr),
	.ahbls_hwrite      (cpu1_to_tcm_hwrite),
	.ahbls_htrans      (cpu1_to_tcm_htrans),
	.ahbls_hsize       (cpu1_to_tcm_hsize),
	.ahbls_hburst      (cpu1_to_tcm_hburst),
	.ahbls_hprot       (cpu1_to_tcm_hprot),
	.ahbls_hmastlock   (cpu1_to_tcm_hmastlock),
	.ahbls_hwdata      (cpu1_to_tcm_hwdata),
	.ahbls_hrdata      (cpu1_to_tcm_hrdata)
);

wire [W_ADDR-1:0] cache_dst_haddr;
wire              cache_dst_hwrite;
wire [1:0]        cache_dst_htrans;
wire [2:0]        cache_dst_hsize;
wire [2:0]        cache_dst_hburst;
wire [3:0]        cache_dst_hprot;
wire              cache_dst_hmastlock;
wire              cache_dst_hready;
wire              cache_dst_hready_resp;
wire              cache_dst_hresp;
wire [W_DATA-1:0] cache_dst_hwdata;
wire [W_DATA-1:0] cache_dst_hrdata;

ahb_cache_writeback #(
	.N_WAYS         (1                    ),
	.W_ADDR         (W_ADDR               ),
	.W_DATA         (W_DATA               ),
	.W_LINE         (128                  ), // 8-beat bursts on 16b SDRAM bus. Minimum efficient burst.
	.DEPTH          (CACHE_SIZE_BYTES / 16)
) cache_u (
	.clk             (clk_sys),
	.rst_n           (rst_n_sys),

	.src_hready_resp (cache_src_hready_resp),
	.src_hready      (cache_src_hready),
	.src_hresp       (cache_src_hresp),
	.src_haddr       (cache_src_haddr),
	.src_hwrite      (cache_src_hwrite),
	.src_htrans      (cache_src_htrans),
	.src_hsize       (cache_src_hsize),
	.src_hburst      (cache_src_hburst),
	// Map IO as noncacheable and SDRAM as cacheable:
	.src_hprot       ({{2{!cache_src_haddr[26]}}, cache_src_hprot[1:0]}),
	.src_hmastlock   (cache_src_hmastlock),
	.src_hwdata      (cache_src_hwdata),
	.src_hrdata      (cache_src_hrdata),

	.dst_hready_resp (cache_dst_hready_resp),
	.dst_hready      (cache_dst_hready),
	.dst_hresp       (cache_dst_hresp),
	.dst_haddr       (cache_dst_haddr),
	.dst_hwrite      (cache_dst_hwrite),
	.dst_htrans      (cache_dst_htrans),
	.dst_hsize       (cache_dst_hsize),
	.dst_hburst      (cache_dst_hburst),
	.dst_hprot       (cache_dst_hprot),
	.dst_hmastlock   (cache_dst_hmastlock),
	.dst_hwdata      (cache_dst_hwdata),
	.dst_hrdata      (cache_dst_hrdata)
);

// ----------------------------------------------------------------------------
// Fabric layer 1: SDRAM and APB bridge

// SDRAM     is at 32'h0800_0000
// APB peri  is at 32'h0c00_0000

wire [W_ADDR-1:0] sdram_haddr;
wire              sdram_hwrite;
wire [1:0]        sdram_htrans;
wire [2:0]        sdram_hsize;
wire [2:0]        sdram_hburst;
wire [3:0]        sdram_hprot;
wire              sdram_hmastlock;
wire              sdram_hready;
wire              sdram_hready_resp;
wire              sdram_hresp;
wire [W_DATA-1:0] sdram_hwdata;
wire [W_DATA-1:0] sdram_hrdata;

wire [W_ADDR-1:0] peri_haddr;
wire              peri_hwrite;
wire [1:0]        peri_htrans;
wire [2:0]        peri_hsize;
wire [2:0]        peri_hburst;
wire [3:0]        peri_hprot;
wire              peri_hmastlock;
wire              peri_hready;
wire              peri_hready_resp;
wire              peri_hresp;
wire [W_DATA-1:0] peri_hwdata;
wire [W_DATA-1:0] peri_hrdata;

ahbl_splitter #(
	.N_PORTS     (2),
	.W_ADDR      (W_ADDR),
	.W_DATA      (W_DATA),
	.ADDR_MAP    (64'h0c000000_08000000),
	.ADDR_MASK   (64'h0c000000_0c000000)
) split_cache (
	.clk             (clk_sys       ),
	.rst_n           (rst_n_sys     ),

	.src_hready      (cache_dst_hready     ),
	.src_hready_resp (cache_dst_hready_resp),
	.src_hresp       (cache_dst_hresp      ),
	.src_haddr       (cache_dst_haddr      ),
	.src_hwrite      (cache_dst_hwrite     ),
	.src_htrans      (cache_dst_htrans     ),
	.src_hsize       (cache_dst_hsize      ),
	.src_hburst      (cache_dst_hburst     ),
	.src_hprot       (cache_dst_hprot      ),
	.src_hmastlock   (cache_dst_hmastlock  ),
	.src_hwdata      (cache_dst_hwdata     ),
	.src_hrdata      (cache_dst_hrdata     ),

	.dst_hready      ({peri_hready      , sdram_hready     }),
	.dst_hready_resp ({peri_hready_resp , sdram_hready_resp}),
	.dst_hresp       ({peri_hresp       , sdram_hresp      }),
	.dst_haddr       ({peri_haddr       , sdram_haddr      }),
	.dst_hwrite      ({peri_hwrite      , sdram_hwrite     }),
	.dst_htrans      ({peri_htrans      , sdram_htrans     }),
	.dst_hsize       ({peri_hsize       , sdram_hsize      }),
	.dst_hburst      ({peri_hburst      , sdram_hburst     }),
	.dst_hprot       ({peri_hprot       , sdram_hprot      }),
	.dst_hmastlock   ({peri_hmastlock   , sdram_hmastlock  }),
	.dst_hwdata      ({peri_hwdata      , sdram_hwdata     }),
	.dst_hrdata      ({peri_hrdata      , sdram_hrdata     })
);

wire        peri_psel;
wire        peri_penable;
wire        peri_pwrite;
wire [15:0] peri_paddr;
wire [31:0] peri_pwdata;
wire [31:0] peri_prdata;
wire        peri_pready;
wire        peri_pslverr;

ahbl_to_apb #(
	.W_HADDR (W_ADDR),
	.W_PADDR (16),
	.W_DATA  (W_DATA)
) peri_apb_bridge (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),

	.ahbls_hready      (peri_hready),
	.ahbls_hready_resp (peri_hready_resp),
	.ahbls_hresp       (peri_hresp),
	.ahbls_haddr       (peri_haddr),
	.ahbls_hwrite      (peri_hwrite),
	.ahbls_htrans      (peri_htrans),
	.ahbls_hsize       (peri_hsize),
	.ahbls_hburst      (peri_hburst),
	.ahbls_hprot       (peri_hprot),
	.ahbls_hmastlock   (peri_hmastlock),
	.ahbls_hwdata      (peri_hwdata),
	.ahbls_hrdata      (peri_hrdata),

	.apbm_paddr        (peri_paddr),
	.apbm_psel         (peri_psel),
	.apbm_penable      (peri_penable),
	.apbm_pwrite       (peri_pwrite),
	.apbm_pwdata       (peri_pwdata),
	.apbm_pready       (peri_pready),
	.apbm_prdata       (peri_prdata),
	.apbm_pslverr      (peri_pslverr)
);

// ----------------------------------------------------------------------------
// Fabric layer 2: APB peripherals

// UART      is at 32'h0c00_0000
// SPI       is at 32'h0c00_1000
// SDRAM cfg is at 32'h0c00_2000
// Timer/IRQ is at 32'h0c00_3000
// GPIO      is at 32'h0c00_4000

wire        uart_psel;
wire        uart_penable;
wire        uart_pwrite;
wire [15:0] uart_paddr;
wire [31:0] uart_pwdata;
wire [31:0] uart_prdata;
wire        uart_pready;
wire        uart_pslverr;

wire        spi0_psel;
wire        spi0_penable;
wire        spi0_pwrite;
wire [15:0] spi0_paddr;
wire [31:0] spi0_pwdata;
wire [31:0] spi0_prdata;
wire        spi0_pready;
wire        spi0_pslverr;

wire        sdram_psel;
wire        sdram_penable;
wire        sdram_pwrite;
wire [15:0] sdram_paddr;
wire [31:0] sdram_pwdata;
wire [31:0] sdram_prdata;
wire        sdram_pready;
wire        sdram_pslverr;

wire        timer_psel;
wire        timer_penable;
wire        timer_pwrite;
wire [15:0] timer_paddr;
wire [31:0] timer_pwdata;
wire [31:0] timer_prdata;
wire        timer_pready;
wire        timer_pslverr;

wire        gpio_psel;
wire        gpio_penable;
wire        gpio_pwrite;
wire [15:0] gpio_paddr;
wire [31:0] gpio_pwdata;
wire [31:0] gpio_prdata;
wire        gpio_pready;
wire        gpio_pslverr;

apb_splitter #(
	.W_ADDR    (16),
	.W_DATA    (32),
	.N_SLAVES  (5),
	.ADDR_MAP  (80'h4000_3000_2000_1000_0000),
	.ADDR_MASK (80'hf000_f000_f000_f000_f000)
) inst_apb_splitter (
	.apbs_paddr   (peri_paddr  ),
	.apbs_psel    (peri_psel   ),
	.apbs_penable (peri_penable),
	.apbs_pwrite  (peri_pwrite ),
	.apbs_pwdata  (peri_pwdata ),
	.apbs_pready  (peri_pready ),
	.apbs_prdata  (peri_prdata ),
	.apbs_pslverr (peri_pslverr),

	.apbm_paddr   ({gpio_paddr   , timer_paddr   , sdram_paddr   , spi0_paddr   , uart_paddr  }),
	.apbm_psel    ({gpio_psel    , timer_psel    , sdram_psel    , spi0_psel    , uart_psel   }),
	.apbm_penable ({gpio_penable , timer_penable , sdram_penable , spi0_penable , uart_penable}),
	.apbm_pwrite  ({gpio_pwrite  , timer_pwrite  , sdram_pwrite  , spi0_pwrite  , uart_pwrite }),
	.apbm_pwdata  ({gpio_pwdata  , timer_pwdata  , sdram_pwdata  , spi0_pwdata  , uart_pwdata }),
	.apbm_pready  ({gpio_pready  , timer_pready  , sdram_pready  , spi0_pready  , uart_pready }),
	.apbm_prdata  ({gpio_prdata  , timer_prdata  , sdram_prdata  , spi0_prdata  , uart_prdata }),
	.apbm_pslverr ({gpio_pslverr , timer_pslverr , sdram_pslverr , spi0_pslverr , uart_pslverr})
);

// ----------------------------------------------------------------------------
// Peripherals

wire uart_irq;

// Error response on currently-empty ports

assign gpio_prdata   = 32'h00000000;
assign gpio_pready   = 1'b1;
assign gpio_pslverr  = 1'b1;

ahbl_sdram #(
	.COLUMN_BITS     (10),
	.ROW_BITS        (13),
	.W_SDRAM_BANKSEL (W_SDRAM_BANKSEL),
	.W_SDRAM_ADDR    (W_SDRAM_ADDR),
	.W_SDRAM_DATA    (W_SDRAM_DATA),
	.N_MASTERS       (1),
	.LEN_AHBL_BURST  (4),
	.FIXED_TIMINGS   (0),
	.W_HADDR         (W_ADDR),
	.W_HDATA         (W_DATA)
) sdram_u (
	.clk               (clk_sys),
	.rst_n             (rst_n_sys),

	.phy_clk_enable    (sdram_phy_clk_enable),
	.phy_ba_next       (sdram_phy_ba_next),
	.phy_a_next        (sdram_phy_a_next),
	.phy_dqm_next      (sdram_phy_dqm_next),

	.phy_dq_o_next     (sdram_phy_dq_o_next),
	.phy_dq_oe_next    (sdram_phy_dq_oe_next),
	.phy_dq_i          (sdram_phy_dq_i),

	.phy_clke_next     (sdram_phy_clke_next),
	.phy_cs_n_next     (sdram_phy_cs_n_next),
	.phy_ras_n_next    (sdram_phy_ras_n_next),
	.phy_cas_n_next    (sdram_phy_cas_n_next),
	.phy_we_n_next     (sdram_phy_we_n_next),

	.apbs_psel         (sdram_psel),
	.apbs_penable      (sdram_penable),
	.apbs_pwrite       (sdram_pwrite),
	.apbs_paddr        (sdram_paddr),
	.apbs_pwdata       (sdram_pwdata),
	.apbs_prdata       (sdram_prdata),
	.apbs_pready       (sdram_pready),
	.apbs_pslverr      (sdram_pslverr),

	.ahbls_hready      (sdram_hready),
	.ahbls_hready_resp (sdram_hready_resp),
	.ahbls_hresp       (sdram_hresp),
	.ahbls_haddr       (sdram_haddr),
	.ahbls_hwrite      (sdram_hwrite),
	.ahbls_htrans      (sdram_htrans),
	.ahbls_hsize       (sdram_hsize),
	.ahbls_hburst      (sdram_hburst),
	.ahbls_hprot       (sdram_hprot),
	.ahbls_hmastlock   (sdram_hmastlock),
	.ahbls_hwdata      (sdram_hwdata),
	.ahbls_hrdata      (sdram_hrdata)
);

uart_mini uart_u (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),

	.apbs_psel    (uart_psel),
	.apbs_penable (uart_penable),
	.apbs_pwrite  (uart_pwrite),
	.apbs_paddr   (uart_paddr),
	.apbs_pwdata  (uart_pwdata),
	.apbs_prdata  (uart_prdata),
	.apbs_pready  (uart_pready),
	.apbs_pslverr (uart_pslverr),

	.rx           (uart_rx),
	.tx           (uart_tx),
	.cts          (1'b0),
	.rts          (/* unused */),
	.irq          (uart_irq),
	.dreq         (/* unused */)
);

platform_timer timer_u (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),

	.apbs_psel    (timer_psel),
	.apbs_penable (timer_penable),
	.apbs_pwrite  (timer_pwrite),
	.apbs_paddr   (timer_paddr),
	.apbs_pwdata  (timer_pwdata),
	.apbs_prdata  (timer_prdata),
	.apbs_pready  (timer_pready),
	.apbs_pslverr (timer_pslverr),

	.halt         (|hart_halted),

	.timer_irq    (timer_irq),
	.soft_irq     (soft_irq)
);

spi_mini #(
	.FIFO_DEPTH (2)
) spi0_u (
	.clk          (clk_sys),
	.rst_n        (rst_n_sys),

	.apbs_psel    (spi0_psel),
	.apbs_penable (spi0_penable),
	.apbs_pwrite  (spi0_pwrite),
	.apbs_paddr   (spi0_paddr),
	.apbs_pwdata  (spi0_pwdata),
	.apbs_prdata  (spi0_prdata),
	.apbs_pready  (spi0_pready),
	.apbs_pslverr (spi0_pslverr),

	.sclk         (spi0_sclk),
	.sdo          (spi0_sdo),
	.sdi          (spi0_sdi),
	.cs_n         (spi0_cs_n)
);


assign irq = {31'h0, uart_irq};

endmodule

// ifndef is a workaround for https://github.com/YosysHQ/yosys/issues/1217
`ifndef YOSYS
`default_nettype wire
`endif
