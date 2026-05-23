/* Linker script for larger Embench-IoT benchmarks on RV32IM processor.
 * Uses 16KB DMEM (4096 words) instead of 8KB for benchmarks with larger
 * data footprints (nettle-aes, huffbench, matmult-int, etc.)
 */

ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    .rodata : { *(.rodata*) *(.srodata*) } > DMEM
    .data : {
        *(.data*)
        *(.sdata*)
    } > DMEM

    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > DMEM

    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
