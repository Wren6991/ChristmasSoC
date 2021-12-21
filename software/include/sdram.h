#ifndef _SDRAM_H
#define _SDRAM_H

#include "platform_defs.h"
#include "hw/sdram_ctrl_regs.h"
#include "delay.h"

#include <stdint.h>
#include <stdbool.h>

typedef struct sdram_ctrl_hw {
	io_rw_32 csr;
	io_rw_32 time;
	io_rw_32 refresh;
	io_rw_32 cmd_direct;
} sdram_ctrl_hw_t;

#define mm_sdram_ctrl ((struct sdram_ctrl_hw *)SDRAM_CTRL_BASE)

#define SDRAM_CMD_REFRESH       0x1u
#define SDRAM_CMD_PRECHARGE     0x2u
#define SDRAM_CMD_LOAD_MODE_REG 0x0u

#if CLK_SYS_MHZ != 40
#warning SDRAM timing parameters are for the wrong system clock frequency
#endif

static inline void sdram_init_seq() {
	// Power up (start transmitting clock) but don't enable automatic operations
	mm_sdram_ctrl->csr = SDRAM_CSR_PU_MASK;
	delay_us(10);
	// PrechargeAll, 3 refreshes
	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_PRECHARGE | (1u << SDRAM_CMD_DIRECT_ADDR_LSB + 10);
	delay_us(10);
	for (int i = 0; i < 3; ++i)	{
		mm_sdram_ctrl->cmd_direct = SDRAM_CMD_REFRESH;
		delay_us(10);
	}

	// Our ULX3S has a AS4C32M16SB-7TCN (-7 speed grade) This grade supports up
	// to 100 MHz with CL2, 144 MHz CL3.
	const uint32_t modereg =
		(0x3u << 0) | // 8 beat bursts
		(0x0u << 3) | // Sequential (wrapped) bursts
		(0x2u << 4) | // CAS latency 2
		(0x0u << 9);  // Write bursts same length as reads

	mm_sdram_ctrl->cmd_direct = SDRAM_CMD_LOAD_MODE_REG | modereg << SDRAM_CMD_DIRECT_ADDR_LSB;
	delay_us(10);

	mm_sdram_ctrl->time =
		(1u << SDRAM_TIME_CAS_LSB) | // tCAS - 1    2 clk
		(0u << SDRAM_TIME_WR_LSB)  | // tWR - 1     14 ns 1 clk
		(1u << SDRAM_TIME_RAS_LSB) | // tRAS - 1    42 ns 2 clk
		(0u << SDRAM_TIME_RRD_LSB) | // tRRD - 1    14 ns 1 clk
		(0u << SDRAM_TIME_RP_LSB)  | // tRP - 1     21 ns 1 clk
		(0u << SDRAM_TIME_RCD_LSB) | // tRCD - 1    21 ns 1 clk
		(2u << SDRAM_TIME_RC_LSB);   // tRC - 1     63 ns 3 clk (also tRFC)

	mm_sdram_ctrl->refresh = 312; // 7.8 us

	// Now that we don't need the direct cmd interface, and safe timings are
	// configured, we can enable the controller
	mm_sdram_ctrl->csr |= SDRAM_CSR_EN_MASK;
}

static inline bool sdram_is_enabled() {
	return !!(mm_sdram_ctrl->csr & SDRAM_CSR_EN_MASK);
}

#endif
