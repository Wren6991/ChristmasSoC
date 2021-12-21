#include "addressmap.h"

// Processor is configured to enter from offset 0. No IRQs required, so all
// traps are routed to a dead-loop.

.section .vectors, "ax"

.option push
.option norelax
_reset_handler:
	la sp, __stack_top
	la gp, __global_pointer
.option pop
	la a0, _dead
	csrw mtvec, a0
	csrr a0, mhartid
	bnez a0, _core1_wait

	// Call main directly. Data sections are already in place (this is a flat TCM
	// binary). Everything else, except setting up stack and global pointer, can
	// be done in C.
	jal main

	// Fall-through:

// Word-aligned for mtvec
.p2align 2
_dead:
	wfi
	j _dead

_core1_wait:
	// IRQs disabled, but soft IRQ unmasked -> soft IRQ will exit WFI.
	csrci mstatus, 0x8
	csrw mie, 0x8
	wfi
	// For now, assume entry point immediately follows a vector table at the
	// start of SDRAM.
	li a0, SDRAM_BASE + 0x40
	jalr a0
	j _dead
