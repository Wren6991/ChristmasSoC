MEMORY {
    TCM (wx) : ORIGIN = 0x0, LENGTH = 4K
    SDRAM (wx) : ORIGIN = 128M, LENGTH = 64M
}

OUTPUT_FORMAT("elf32-littleriscv", "elf32-littleriscv", "elf32-littleriscv")
OUTPUT_ARCH(riscv)

SECTIONS {
    ENTRY(_reset_handler)
    .text : {
        KEEP(*(.vectors*))
        *(.text*)
    } > SDRAM

    .rodata : {
        *(.rodata .rodata.*)
    } > SDRAM

    .data : {
        __global_pointer$ = . + 0x800;

        *(.srodata*)
        *(.sdata*)
        *(.data .data.*)
    } > SDRAM
    _edata = .;

    __tcm_src = .;
    .tcm : {
        __tcm_start = .;
        *(.tcm .tcm.*)
        __tcm_end = .;
    } > TCM AT> SDRAM

    .bss : {
        __bss_start = .;
        *(.sbss*)
        *(.bss .bss.*)
        __bss_end = .;
    } > SDRAM
    _end = .;

    __stack_top = ORIGIN(TCM) + LENGTH(TCM);

    .comment       0 : { *(.comment) }
    /* DWARF debug sections.
    /* GNU DWARF 1 extensions */
    .debug_srcinfo  0 : { *(.debug_srcinfo) }
    .debug_sfnames  0 : { *(.debug_sfnames) }
    /* DWARF 1.1 and DWARF 2 */
    .debug_aranges  0 : { *(.debug_aranges) }
    .debug_pubnames 0 : { *(.debug_pubnames) }
    /* DWARF 2 */
    .debug_info     0 : { *(.debug_info .gnu.linkonce.wi.*) }
    .debug_abbrev   0 : { *(.debug_abbrev) }
    .debug_line     0 : { *(.debug_line .debug_line.* .debug_line_end ) }
    .debug_frame    0 : { *(.debug_frame) }
    .debug_str      0 : { *(.debug_str) }
    .debug_loc      0 : { *(.debug_loc) }
    .debug_macinfo  0 : { *(.debug_macinfo) }
    /* DWARF 3 */
    .debug_pubtypes 0 : { *(.debug_pubtypes) }
    .debug_ranges   0 : { *(.debug_ranges) }
}
