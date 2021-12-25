#include "platform_defs.h"
#include "uart.h"
#include "multicore.h"

void core1_main() {
	uart_puts("Hello, world from core 1!\n");
}

int main() {
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	uart_init();

	uart_puts("Hello, world from core 0!\n");
	launch_core1(core1_main);
	__wfi();
}
