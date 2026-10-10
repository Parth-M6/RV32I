
ENTRY(_start)

PHDRS
{
    text PT_LOAD FLAGS(5);  /* R | X */
    data PT_LOAD FLAGS(6);  /* R | W */
}

SECTIONS
{
    . = 0x0;

    .text : {
        *(.text.init)
        *(.text*)
    } :text

    .rodata : {
        *(.rodata*)
    } :text

    .tohost : {
        *(.tohost)
    } :data

    .data : {
        *(.data*)
    } :data

    .bss : {
        *(.bss*)
        *(COMMON)
    } :data
}
