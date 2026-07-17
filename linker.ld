ENTRY(_start)

SECTIONS
{
    . = 0x0;

    .text : {
        *(.text.init)
        *(.text*)
    }

    .rodata : {
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(.bss*)
        *(COMMON)
    }
}
