#ifndef _ADDRESSMAP_H
#define _ADDRESSMAP_H

#define _u(x) __u(x)
#ifdef __ASSEMBLER__
#define __u(x) x
#else
#define __u(x) x ## u
#endif

#define TCM_BASE   _u(0x00000000)
#define TCM_SIZE   _u(0x00001000)
#define SDRAM_BASE _u(0x08000000)
#define SDRAM_SIZE _u(0x04000000)
#define PERI_BASE  _u(0x0c000000)

#define UART_BASE       (PERI_BASE + _u(0x0000))
#define SPI_BASE        (PERI_BASE + _u(0x1000))
#define SDRAM_CTRL_BASE (PERI_BASE + _u(0x2000))
#define TIMER_BASE      (PERI_BASE + _u(0x3000))
#define GPIO_BASE       (PERI_BASE + _u(0x4000))

#ifndef __ASSEMBLER__

#include <stdint.h>

typedef volatile uint32_t io_rw_32;
typedef volatile uint32_t io_wo_32;
typedef volatile const uint32_t io_ro_32;

#endif

#endif
