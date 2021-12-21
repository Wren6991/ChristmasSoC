#ifndef _DELAY_H_
#define _DELAY_H_

#include <stdint.h>

#include "platform_defs.h"

static inline void delay_ms(uint32_t ms) {
	uint32_t delay_count = (ms * 1000 * CLK_SYS_MHZ) / 3;
	asm volatile (
		"1:                 \n\t"
		"	addi %0, %0, -1 \n\t"
		"	bge %0, x0, 1b  \n\t"
		: "+r" (delay_count)
	);
}

static inline void delay_us(uint32_t us) {
	uint32_t delay_count = (us * CLK_SYS_MHZ) / 3;
	asm volatile (
		"1:                 \n\t"
		"	addi %0, %0, -1 \n\t"
		"	bge %0, x0, 1b  \n\t"
		: "+r" (delay_count)
	);
}

#endif // _DELAY_H_
