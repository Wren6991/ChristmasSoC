#include "platform_defs.h"
#include "uart.h"
#include "sdram.h"
#include "spi.h"

#define SPI_LOAD_ADDR 0x100000u

const char *splash_text = "\n"
"  ___ _        _    _                 ___       ___ \n"
" / __| |_  _ _(_)__| |_ _ __  __ _ __/ __| ___ / __|\n"
"| (__| ' \\| '_| (_-<  _| '  \\/ _` (_-<__ \\/ _ \\ (__ \n"
" \\___|_||_|_| |_/__/\\__|_|_|_\\__,_/__/___/\\___/\\___|\n";

uint8_t *sdram = (uint8_t*)SDRAM_BASE;
void (*sdram_entry)(void) = (void(*)(void))(SDRAM_BASE + 0x40u);

void main() {
	// Enable SDRAM immediately, before debugger attaches
	if (!sdram_is_enabled())
		sdram_init_seq();

	uart_clkdiv_baud(CLK_SYS_MHZ, UART_BAUD);
	uart_init();
	uart_puts(splash_text);

	spi_init(false, false);
	spi_clkdiv(2);
	mm_spi->csr = mm_spi->csr & ~(SPI_CSR_CSAUTO_MASK | SPI_CSR_CS_MASK);
	uint8_t buf[] = {
		0x03,
		SPI_LOAD_ADDR >> 16 & 0xff,
		SPI_LOAD_ADDR >> 8 & 0xff,
		SPI_LOAD_ADDR & 0xff
	};
	spi_write(buf, 4);

	spi_write_read(buf, buf, 4);
	uart_puts("Magic: ");
	uart_putint(*(uint32_t*)buf);
	uart_puts("\n");
	if (buf[0] != 'C' || buf[1] != 'S' || buf[2] != 'o' || buf[3] != 'C') {
		uart_puts("Bad magic\n");
		return;
	}

	spi_write_read(buf, buf, 4);
	uint32_t len = (uint32_t)buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
	uart_puts("Size:  ");
	uart_putint(len);
	uart_puts("\n");
	if (len > SDRAM_SIZE) {
		uart_puts("Bad size\n");
		return;
	}

	spi_write_read(sdram, sdram, len);
	mm_spi->csr |= SPI_CSR_CS_MASK;

	uart_puts("Flash boot OK\n");

	sdram_entry();

}
