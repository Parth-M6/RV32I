
ENTRY(_start)
OUTPUT_ARCH(riscv)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 64K
}

/* Explicitly define ELF load-segment permissions.
   PF_R = 4, PF_W = 2, PF_X = 1. */
PHDRS
{
    text PT_LOAD FLAGS(5);  /* Read + Execute */
    data PT_LOAD FLAGS(6);  /* Read + Write */
}

SECTIONS
{
    . = ORIGIN(RAM);

    /* Instructions and read-only constants */
    .text ALIGN(4) :
    {
        *(.text.init)
        *(.text .text.*)
    } > RAM :text

    .rodata ALIGN(4) :
    {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
    } > RAM :text

    /* Host communication area, if used by your testbench */
    .tohost ALIGN(8) :
    {
        *(.tohost)
    } > RAM :data

    /* Initialized writable data */
    .data ALIGN(4) :
    {
        *(.data .data.*)
        *(.sdata .sdata.*)
    } > RAM :data

    /* Zero-initialized writable data */
    .bss ALIGN(4) :
    {
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
    } > RAM :data
}
