#ifndef _MULTICORE_H
#define _MULTICORE_H

#include "addressmap.h"
#include "hw/timer_regs.h"

typedef struct timer_hw {
	io_rw_32 time;
	io_rw_32 timeh;
	io_rw_32 timecmp0;
	io_rw_32 timecmp0h;
	io_rw_32 timecmp1;
	io_rw_32 timecmp1h;
	io_rw_32 softirq_set;
	io_rw_32 softirq_clr;
} timer_hw_t;

#define mm_timer ((timer_hw_t*)TIMER_BASE)

static inline void set_softirq(int i) {
	mm_timer->softirq_set = 1u << i;
}

static inline void clr_softirq(int i) {
	mm_timer->softirq_clr = 1u << i;
}

static inline bool get_softirq(int i) {
	return !!(mm_timer->softirq_set & (1u << i));
}

extern void (*core1_entry_vector)(void);

static inline void launch_core1(void (*entry)(void)) {
	core1_entry_vector = entry;
	asm volatile ("" : : : "memory");
	set_softirq(1);
}

#define __wfi() asm volatile ("wfi")

#endif
