#ifndef _TIMER_H
#define _TIMER_H

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

void timer_set_time(uint64_t t) {
	mm_timer->time = 0;
	mm_timer->timeh = t >> 32;
	mm_timer->time = t & 0xffffffffu;
}

uint64_t timer_get_time(void) {
	uint32_t h0, l, h1;
	do {
		h0 = mm_timer->timeh;
		l  = mm_timer->time;
		h1 = mm_timer->timeh;
	} while (h0 != h1);
	return (uint64_t)h0 << 32 | l;
}

void timer_set_timecmp(int core, uint64_t cmp) {
	io_rw_32 *l = core == 0 ? &mm_timer->timecmp0 : &mm_timer->timecmp1;
	io_rw_32 *h = core == 0 ? &mm_timer->timecmp0h : &mm_timer->timecmp1h;

	// No lower than requested
	l = 0xffffffffu;
	// No lower than requested
	h = cmp >> 32;
	// Equal to requested
	l = cmp & 0xffffffffu;
}

#endif
