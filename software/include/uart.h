#ifndef _UART_H_
#define _UART_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdarg.h>

#include "platform_defs.h"
#include "hw/uart_regs.h"

typedef struct uart_hw {
	io_rw_32 csr;
	io_rw_32 div;
	io_rw_32 fstat;
	io_wo_32 tx;
	io_ro_32 rx;
} uart_hw_t;

#define mm_uart ((uart_hw_t*)UART_BASE)

static inline void uart_enable(bool en) {
	mm_uart->csr = (mm_uart->csr & ~UART_CSR_EN_MASK) | (!!en << UART_CSR_EN_LSB);
}

// 10.4 fixed point format.
// Encodes number of clock cycles per clock enable.
// Each baud period is 16 clock enables (default modparam)
static inline void uart_clkdiv(uint32_t div) {
	mm_uart->div = div;
}

// Use constant arguments:
#define uart_clkdiv_baud(clk_mhz, baud) uart_clkdiv((uint32_t)((clk_mhz) * 1e6 * (16.0 / 8.0) / (float)(baud)))

static inline bool uart_tx_full() {
	return !!(mm_uart->fstat & UART_FSTAT_TXFULL_MASK);
}

static inline bool uart_tx_empty() {
	return !!(mm_uart->fstat & UART_FSTAT_TXEMPTY_MASK);
}

static inline size_t uart_tx_level() {
	return (mm_uart->fstat & UART_FSTAT_TXLEVEL_MASK) >> UART_FSTAT_TXLEVEL_LSB;
}

static inline bool uart_rx_full() {
	return !!(mm_uart->fstat & UART_FSTAT_RXFULL_MASK);
}

static inline bool uart_rx_empty() {
	return !!(mm_uart->fstat & UART_FSTAT_RXEMPTY_MASK);
}


static inline size_t uart_rx_level() {
	return (mm_uart->fstat & UART_FSTAT_RXLEVEL_MASK) >> UART_FSTAT_RXLEVEL_LSB;
}

static inline void uart_put(uint8_t x) {
	while (uart_tx_full())
		;
	mm_uart->tx = x;
}

static inline uint8_t uart_get() {
	while (uart_rx_empty())
		;
	return (uint8_t)mm_uart->rx;
}

static inline void uart_puts(const char *s) {
	while (*s) {
		if (*s == '\n')
			uart_put('\r');
		uart_put((uint8_t)(*s++));
	}
}

// Have you seen how big printf is?
static const char hextable[16] = {
	'0', '1', '2', '3', '4', '5', '6', '7',
	'8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
};

static inline void uart_putint(uint32_t x) {
	for (int i = 0; i < 8; ++i) {
		uart_put((uint8_t)(hextable[x >> 28]));
		x <<= 4;
	}
}

static inline void uart_printf(const char *fmt, ...) {
	char buf[PRINTF_BUF_SIZE];
	va_list args;
	va_start(args, fmt);
	vsnprintf(buf, PRINTF_BUF_SIZE, fmt, args);
	uart_puts(buf);
	va_end(args);
}

static inline void uart_putbyte(uint8_t x) {
	uart_put((uint8_t)(hextable[x >> 4]));
	uart_put((uint8_t)(hextable[x & 0xf]));
}

static inline void uart_wait_done() {
	while (mm_uart->csr & UART_CSR_BUSY_MASK)
		;
}

static inline void uart_init() {
	while (mm_uart->csr & UART_CSR_BUSY_MASK)
		;
	mm_uart->csr = 0;
	while (!uart_rx_empty())
		(void)uart_get();
	uart_enable(true);
}

static inline void uart_enable_cts(bool en) {
	mm_uart->csr = (mm_uart->csr & ~UART_CSR_CTSEN_MASK) | (!!en << UART_CSR_CTSEN_LSB);
}

#endif // _UART_H_
