/* Each core boots from its TCM -- code, static data, stack are all in there.
 * Both TCMs contain the same boot image.
 *
 * We only care about running C, with a limited runtime.
 */

MEMORY {
    TCM (wx) : ORIGIN = 0x0, LENGTH = 4K
}

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)

SECTIONS {
    .text : {
        KEEP(*(.vectors*))
        *(.text*)
    }

    /* .rodata, .data and .bss are merged into a single section (!!!) to allow
     * gp-relative relaxation of all data references. The TCM is small enough to be
     * completely covered by gp-relative addressing, but relaxations only occur
     * within the section containing __global_pointer$.
     */
     .data : {
        __global_pointer$ = . + 0x800;
        __global_pointer = . + 0x800;

        *(.srodata*)
        *(.sdata*)
        *(.sbss*)
        *(.rodata .rodata.*)
        *(.data .data.*)
        *(.bss .bss.*)
    }

    __stack_top = ORIGIN(TCM) + LENGTH(TCM);
}
