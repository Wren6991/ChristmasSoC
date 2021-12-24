#ifndef _SPI_H_
#define _SPI_H_

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>

#include "addressmap.h"
#include "hw/spi_regs.h"

typedef struct spi_hw {
	io_rw_32 csr;
	io_rw_32 div;
	io_rw_32 fstat;
	io_wo_32 tx;
	io_ro_32 rx;
} spi_hw_t;

#define mm_spi ((spi_hw_t *)SPI_BASE)

static inline void spi_init(bool cpol, bool cpha)
{
	// TODO: need to drain TX FIFO etc
	mm_spi->csr = (SPI_CSR_CSAUTO_MASK | SPI_CSR_READ_EN_MASK) |
		(!!cpol << SPI_CSR_CPOL_LSB) |
		(!!cpha << SPI_CSR_CPHA_LSB);

	while (!(mm_spi->fstat & SPI_FSTAT_RXEMPTY_MASK))
		(void)mm_spi->rx;

	mm_spi->fstat = SPI_FSTAT_TXOVER_MASK | SPI_FSTAT_RXOVER_MASK | SPI_FSTAT_RXUNDER_MASK;
}

static inline void spi_write(const uint8_t *data, size_t len)
{
	for(; len > 0; --len)
	{
		while (mm_spi->fstat & SPI_FSTAT_TXFULL_MASK)
			;
		mm_spi->tx = *data++;
	}
}

static inline void _spi_get_if_nonempty(uint8_t **rx)
{
	if (!(mm_spi->fstat & SPI_FSTAT_RXEMPTY_MASK))
		*(*rx)++ = mm_spi->rx;
}

static inline void spi_write_read(const uint8_t *tx, uint8_t *rx, size_t len)
{
	while (!(mm_spi->fstat & SPI_FSTAT_RXEMPTY_MASK))
		(void)mm_spi->rx;

	for (; len > 0; --len)
	{
		_spi_get_if_nonempty(&rx);
		while (mm_spi->fstat & SPI_FSTAT_TXFULL_MASK)
			;
		mm_spi->tx = *tx++;
	}
	while (mm_spi->csr & SPI_CSR_BUSY_MASK)
		_spi_get_if_nonempty(&rx);
	_spi_get_if_nonempty(&rx);
}

static inline void spi_wait_done()
{
	while (mm_spi->csr & SPI_CSR_BUSY_MASK)
		;
}

static inline void spi_clkdiv(int div)
{
	mm_spi->div = div;
}

#endif // _SPI_H_
