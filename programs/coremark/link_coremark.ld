/* Linker script for official CoreMark on RV32IM processor.
 *
 * Memory architecture:
 *   imem_16k: 4096 words = 16KB instruction ROM (PC-based fetches)
 *   dmem:     1024 words =  4KB data RAM (load/store)
 *
 * Both memories are at address 0 but routed by access type.
 * .text/.rodata go to imem (fetched via PC).
 * .data/.bss/stack go to dmem (accessed via load/store).
 *
 * IMPORTANT: Our processor has separate imem/dmem with no data-copy
 * path from imem to dmem. All initialized data (.data) MUST be set
 * by startup code or at runtime. BSS starts zeroed (dmem = 0).
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

    /* Read-only data, initialized data, and small data ALL go to DMEM.
     * Our Harvard architecture routes loads to DMEM only, so .rodata
     * MUST be in DMEM for const arrays/tables to be readable.
     * NOTE: .rodata initial values cannot be copied from IMEM, so
     * const data must be runtime-initialized or zero-tolerant. */
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
