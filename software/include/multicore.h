#ifndef _MULTICORE_H
#define _MULTICORE_H

#include "timer.h"

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
