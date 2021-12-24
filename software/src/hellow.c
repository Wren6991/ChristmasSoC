#include "platform_defs.h"
#include "uart.h"

int main() {
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	uart_init();

	uart_puts("Hello, world!\n");
	return 0;
}
