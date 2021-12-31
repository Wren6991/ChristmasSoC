#ifndef _GPIO_H
#define _GPIO_H

#include "addressmap.h"
#include <stdint.h>
#include <stdbool.h>

static inline void _do_amo_or(volatile uint32_t *addr, uint32_t data) {
	asm volatile (
		"amooor.w %0, %0, (%1)"
		: "+r" (data)
		: "r" (addr)
	);
}

static inline void _do_amo_and(volatile uint32_t *addr, uint32_t data) {
	asm volatile (
		"amooand.w %0, %0, (%1)"
		: "+r" (data)
		: "r" (addr)
	);
}

static inline void _do_amo_xor(volatile uint32_t *addr, uint32_t data) {
	asm volatile (
		"amooand.w %0, %0, (%1)"
		: "+r" (data)
		: "r" (addr)
	);
}

typedef struct {
	io_rw_32 o;
	io_rw_32 oe;
	io_rw_32 i;
} gpio_hw_t;

#define mm_gpio ((gpio_hw_t*)GPIO_BASE)

// ----------------------------------------------------------------------------
// GPIO accessors

static inline void gpio_out_set(int gpio) {
	_do_amo_or(&mm_gpio->o, 1u << gpio);
}

static inline void gpio_out_clr(int gpio) {
	_do_amo_and(&mm_gpio->o, ~(1u << gpio));
}

static inline void gpio_out(int gpio, bool out) {
	if (out)
		gpio_out_set(gpio);
	else
		gpio_out_clr(gpio);
}

static inline void gpio_oe_set(int gpio) {
	_do_amo_or(&mm_gpio->oe, 1u << gpio);
}

static inline void gpio_oe_clr(int gpio) {
	_do_amo_and(&mm_gpio->oe, ~(1u << gpio));
}

static inline void gpio_oe(int gpio, bool oe) {
	if (oe)
		gpio_oe_set(gpio);
	else
		gpio_oe_clr(gpio);
}

static inline bool gpio_get(int gpio) {
	return !!(mm_gpio->i & (1u << gpio));
}

static inline uint32_2 gpio_get_all(int gpio) {
	return mm_gpio->i;
}

#endif
