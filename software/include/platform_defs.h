#ifndef _PLATFORM_DEFS_H
#define _PLATFORM_DEFS_H

#include "addressmap.h"

#ifndef CLK_SYS_MHZ
#define CLK_SYS_MHZ 40
#endif

#ifndef UART_BAUD
#define UART_BAUD (3 * 1000 * 1000)
#endif

#ifndef PRINTF_BUF_SIZE
#define PRINTF_BUF_SIZE 128
#endif

#define CACHE_SIZE_WORDS 1024
#define CACHE_LINE_SIZE_WORDS 4

#define __tcm(obj) __attribute__((section(".tcm." #obj) obj

#endif
