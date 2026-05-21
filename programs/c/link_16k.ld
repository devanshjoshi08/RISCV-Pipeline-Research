/* 16KB ROM / 16KB RAM linker script for benchmark programs */
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : { *(.text.init) *(.text*) } > ROM
    .rodata : { *(.rodata*) } > ROM
    .data : { *(.data*) } > RAM AT> ROM
    .bss : {
        __bss_start = .;
        *(.bss*) *(COMMON)
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
