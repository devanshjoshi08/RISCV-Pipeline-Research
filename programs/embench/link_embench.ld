/* Linker script for Embench-IoT benchmarks on RV32IM processor.
 *
 * Memory architecture:
 *   imem: up to 4096 words = 16KB instruction ROM (PC-based fetches)
 *   dmem: 2048 words = 8KB data RAM (load/store), overridden via defparam
 *
 * IMPORTANT: Harvard architecture -- loads go to DMEM only.
 * .rodata MUST be in DMEM for const data to be readable.
 * .rodata initial values are pre-loaded via $readmemh in testbench.
 */

ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 8K
}

SECTIONS
{
    /* Code in instruction memory */
    .text : {
        *(.text.init)
        *(.text*)
    } > IMEM

    /* Read-only data and initialized data in DMEM */
    .rodata : { *(.rodata*) *(.srodata*) } > DMEM
    .data : {
        *(.data*)
        *(.sdata*)
    } > DMEM

    /* BSS -- uninitialized data, cleared by start.s */
    .bss : {
        __bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        __bss_end = .;
    } > DMEM

    /* Stack grows down from top of dmem */
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
}
