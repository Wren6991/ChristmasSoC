#include "platform_defs.h"
#include "uart.h"

const char *splash_text = "\n"
"  ___ _        _    _                 ___       ___ \n"
" / __| |_  _ _(_)__| |_ _ __  __ _ __/ __| ___ / __|\n"
"| (__| ' \\| '_| (_-<  _| '  \\/ _` (_-<__ \\/ _ \\ (__ \n"
" \\___|_||_|_| |_/__/\\__|_|_|_\\__,_/__/___/\\___/\\___|\n";

void main() {
	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	uart_init();
	uart_puts(splash_text);
}
