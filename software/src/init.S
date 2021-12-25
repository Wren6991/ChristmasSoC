#include "addressmap.h"
#include "hw/timer_regs.h"

.option push
.option norelax

.section .vectors

.macro VEC name:req
.p2align 2
j \name
.p2align 2
.endm

// ----------------------------------------------------------------------------
// Vector table (must be at least aligned to its size rounded up to power of 2)

.p2align 12
.vector_table:

// Single exception vector, also takes IRQs if vectoring is disabled

	VEC handle_exception

// Standard interrupts, if vectoring is enabled
// Note: global EIRQ does not fire. Instead we have 16 separate vectors

	// handle_exception ^^^ takes the slot where U-mode softirq would be
	VEC _halt
	VEC _halt
	VEC isr_machine_softirq
	VEC _halt
	VEC _halt
	VEC _halt
	VEC isr_machine_timer
	VEC _halt
	VEC _halt
	VEC _halt
	VEC isr_external_irq
	VEC _halt
	VEC _halt
	VEC _halt
	VEC _halt

// ----------------------------------------------------------------------------
// Reset handler

.global _reset_handler
_reset_handler:
	// Set counters running, as they are off by default. This may trap if counters
	// are unimplemented, so catch the trap and continue.
	la a0, 1f
	csrw mtvec, a0
	csrci mcountinhibit, 0x5
.p2align 2
1:
	// Set up trap vector table. mtvec LSB enables vectoring
	la a0, .vector_table + 1
	csrw mtvec, a0

	// Set up stack pointer before doing anything else. Stack is assumed to be
	// at top of TCM for both cores, so same address is used.
	la sp, __stack_top

	// Initialise TCMs. Same image for both cores.
	la a0, __tcm_start
	la a1, __tcm_end
	la a2, __tcm_src
	j 2f
1:
	lw a3, (a0)
	sw a3, (a2)
	addi a0, a0, 4
	addi a2, a2, 4
2:
	bltu a0, a1, 1b

	// Core 1 waits for a second soft IRQ before going to its entry point.
	csrr a0, mhartid
	bnez a0, _core1_wait

	// newlib _start expects argc, argv on the stack. Leave stack 16-byte aligned.
	addi sp, sp, -16
	li a0, 1
	sw a0, (sp)
	la a0, progname
	sw a0, 4(sp)

	jal _start
	j _halt

_core1_wait:
	// IRQs disabled, but soft IRQ unmasked -> soft IRQ will exit WFI.
	csrci mstatus, 0x8
	csrw mie, 0x8
_core1_wait_loop:
	// This WFI will probably fall straight through:
	//
	// - Core 1 was spinning in its TCM bootcode when core 0, having booted,
	//   set the entry point and posted an IRQ to kick it into this routine
	//
	// Less likely:
	//
	// - Debugger has done a warm boot, and there is a stale IRQ left behind,
	//   in which case we see the zero entry point and wait for another IRQ.
	//   (this is why it's critical to clear the IRQ *before* checking the
	//   entry point, to avoid permasleep!)
	wfi
	// Clear the IRQ first, *then* check the entry point
	li a0, TIMER_BASE
	li a1, 1 << 1
	sw a1, TIMER_SOFTIRQ_CLR_OFFS(a0)
	la a0, core1_entry_vector
	lw a0, (a0)
	beqz a0, _core1_wait_loop
_core1_go:
	// Stack was already initialised in reset handler. Static data sections
	// were initialised by core 0.
	jalr a0
_core1_finish:
	wfi
	j _core1_finish

.p2align 2
.global core1_entry_vector
core1_entry_vector:
	.word 0

.global _exit
_exit:
1:
	wfi
	j 1b

.global _sbrk
_sbrk:
	la a1, heap_ptr
	lw a2, (a1)
	add a0, a0, a2
	sw a0, (a1)
	mv a0, a2
	ret

.p2align 2
heap_ptr:
	.word _end

.global _halt
_halt:
	wfi
	j _halt

progname:
	.asciz "christmas-soc"

// ----------------------------------------------------------------------------
// Weak handler/ISR symbols

.macro weak_handler name:req
.p2align 2
.global \name
.weak \name
\name:
1:
	wfi
	j 1b
.endm

weak_handler handle_exception
weak_handler isr_machine_softirq
weak_handler isr_machine_timer
weak_handler isr_external_irq

// You can relax now
.option pop
