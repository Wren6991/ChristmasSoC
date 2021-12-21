/*******************************************************************************
*                          AUTOGENERATED BY REGBLOCK                           *
*                            Do not edit manually.                             *
*          Edit the source file (or regblock utility) and regenerate.          *
*******************************************************************************/

#ifndef _UART_REGS_H_
#define _UART_REGS_H_

// Block name           : uart
// Bus type             : apb
// Bus data width       : 32
// Bus address width    : 16

#define UART_CSR_OFFS 0
#define UART_DIV_OFFS 4
#define UART_FSTAT_OFFS 8
#define UART_TX_OFFS 12
#define UART_RX_OFFS 16

/*******************************************************************************
*                                     CSR                                      *
*******************************************************************************/

// Control and status register

// Field: CSR_EN  Access: RW
// UART runs when en is high. Synchronous reset (excluding FIFOs) when low.
#define UART_CSR_EN_LSB  0
#define UART_CSR_EN_BITS 1
#define UART_CSR_EN_MASK 0x1
// Field: CSR_BUSY  Access: ROV
// UART TX is still sending data
#define UART_CSR_BUSY_LSB  1
#define UART_CSR_BUSY_BITS 1
#define UART_CSR_BUSY_MASK 0x2
// Field: CSR_TXIE  Access: RW
// Enable TX FIFO interrupt
#define UART_CSR_TXIE_LSB  2
#define UART_CSR_TXIE_BITS 1
#define UART_CSR_TXIE_MASK 0x4
// Field: CSR_RXIE  Access: RW
// Enable RX FIFO interrupt
#define UART_CSR_RXIE_LSB  3
#define UART_CSR_RXIE_BITS 1
#define UART_CSR_RXIE_MASK 0x8
// Field: CSR_CTSEN  Access: RW
// Enable pausing of TX while CTS is not asserted
#define UART_CSR_CTSEN_LSB  4
#define UART_CSR_CTSEN_BITS 1
#define UART_CSR_CTSEN_MASK 0x10
// Field: CSR_LOOPBACK  Access: RW
// Connect TX -> RX and RTS -> CTS internally (for testing).
#define UART_CSR_LOOPBACK_LSB  8
#define UART_CSR_LOOPBACK_BITS 1
#define UART_CSR_LOOPBACK_MASK 0x100

/*******************************************************************************
*                                     DIV                                      *
*******************************************************************************/

// Clock divider control fields

// Field: DIV_INT  Access: WO
#define UART_DIV_INT_LSB  4
#define UART_DIV_INT_BITS 10
#define UART_DIV_INT_MASK 0x3ff0
// Field: DIV_FRAC  Access: WO
#define UART_DIV_FRAC_LSB  0
#define UART_DIV_FRAC_BITS 4
#define UART_DIV_FRAC_MASK 0xf

/*******************************************************************************
*                                    FSTAT                                     *
*******************************************************************************/

// FIFO status register

// Field: FSTAT_TXLEVEL  Access: ROV
#define UART_FSTAT_TXLEVEL_LSB  0
#define UART_FSTAT_TXLEVEL_BITS 8
#define UART_FSTAT_TXLEVEL_MASK 0xff
// Field: FSTAT_TXFULL  Access: ROV
#define UART_FSTAT_TXFULL_LSB  8
#define UART_FSTAT_TXFULL_BITS 1
#define UART_FSTAT_TXFULL_MASK 0x100
// Field: FSTAT_TXEMPTY  Access: ROV
#define UART_FSTAT_TXEMPTY_LSB  9
#define UART_FSTAT_TXEMPTY_BITS 1
#define UART_FSTAT_TXEMPTY_MASK 0x200
// Field: FSTAT_TXOVER  Access: W1C
#define UART_FSTAT_TXOVER_LSB  10
#define UART_FSTAT_TXOVER_BITS 1
#define UART_FSTAT_TXOVER_MASK 0x400
// Field: FSTAT_TXUNDER  Access: W1C
#define UART_FSTAT_TXUNDER_LSB  11
#define UART_FSTAT_TXUNDER_BITS 1
#define UART_FSTAT_TXUNDER_MASK 0x800
// Field: FSTAT_RXLEVEL  Access: ROV
#define UART_FSTAT_RXLEVEL_LSB  16
#define UART_FSTAT_RXLEVEL_BITS 8
#define UART_FSTAT_RXLEVEL_MASK 0xff0000
// Field: FSTAT_RXFULL  Access: ROV
#define UART_FSTAT_RXFULL_LSB  24
#define UART_FSTAT_RXFULL_BITS 1
#define UART_FSTAT_RXFULL_MASK 0x1000000
// Field: FSTAT_RXEMPTY  Access: ROV
#define UART_FSTAT_RXEMPTY_LSB  25
#define UART_FSTAT_RXEMPTY_BITS 1
#define UART_FSTAT_RXEMPTY_MASK 0x2000000
// Field: FSTAT_RXOVER  Access: W1C
#define UART_FSTAT_RXOVER_LSB  26
#define UART_FSTAT_RXOVER_BITS 1
#define UART_FSTAT_RXOVER_MASK 0x4000000
// Field: FSTAT_RXUNDER  Access: W1C
#define UART_FSTAT_RXUNDER_LSB  27
#define UART_FSTAT_RXUNDER_BITS 1
#define UART_FSTAT_RXUNDER_MASK 0x8000000

/*******************************************************************************
*                                      TX                                      *
*******************************************************************************/

// TX data FIFO

// Field: TX  Access: WF
#define UART_TX_LSB  0
#define UART_TX_BITS 8
#define UART_TX_MASK 0xff

/*******************************************************************************
*                                      RX                                      *
*******************************************************************************/

// RX data FIFO

// Field: RX  Access: RF
#define UART_RX_LSB  0
#define UART_RX_BITS 8
#define UART_RX_MASK 0xff

#endif // _UART_REGS_H_