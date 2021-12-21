#include "platform_defs.h"
#include "uart.h"
#include "sdram.h"

const char *splash_text = "\n"
"  ___ _        _    _                 ___       ___ \n"
" / __| |_  _ _(_)__| |_ _ __  __ _ __/ __| ___ / __|\n"
"| (__| ' \\| '_| (_-<  _| '  \\/ _` (_-<__ \\/ _ \\ (__ \n"
" \\___|_||_|_| |_/__/\\__|_|_|_\\__,_/__/___/\\___/\\___|\n";

volatile uint32_t *sdram32 = (uint32_t*)SDRAM_BASE;

void main() {
	// Enable SDRAM immediately, before debugger attaches
	if (!sdram_is_enabled())
		sdram_init_seq();

	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	uart_init();

	// 8 kiB offset: 4 banks (so 1 row in same bank), and multiple of cache size
	sdram32[0] = 0x01234567;
	sdram32[1] = 0x01234568;
	sdram32[2] = 0x01234569;
	sdram32[3] = 0x0123456a;
	sdram32[2048] = 0x89abcdef;
	sdram32[2049] = 0x89abcdee;
	sdram32[2050] = 0x89abcded;
	sdram32[2051] = 0x89abcdec;
	for (int i = 0; i < 4; ++i) {
		uart_putint(sdram32[i]);
		uart_puts("\n");
	}
	uart_puts("\n");
	for (int i = 0; i < 4; ++i) {
		uart_putint(sdram32[2048 + i]);
		uart_puts("\n");
	}

	uart_puts(splash_text);
}
