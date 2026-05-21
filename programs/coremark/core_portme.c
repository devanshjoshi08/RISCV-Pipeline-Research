/*
 * CoreMark porting layer for bare-metal RV32IM processor.
 *
 * Timer:  mcycle CSR (clock cycle counter).
 * Output: performance counters written to dmem for testbench readout.
 * Seeds:  initialized in portable_init() since our processor has
 *         separate imem/dmem and cannot copy .data from imem to dmem.
 *         BSS starts zeroed (dmem initializes to 0).
 */

#include "coremark.h"

/* ================================================================
 * Seed variables (SEED_VOLATILE)
 *
 * Declared without initializers so they go to BSS (= 0 in dmem).
 * portable_init() sets seed3 and seed4 before CoreMark reads them.
 *
 * Actually, CoreMark's core_main.c auto-detects seeds=(0,0,0) as
 * a PERFORMANCE_RUN and overrides to seed3=0x66. So we only MUST
 * set seed4 (iterations). But we set seed3 too for clarity.
 * ================================================================ */
volatile ee_s32 seed1_volatile;   /* BSS = 0 */
volatile ee_s32 seed2_volatile;   /* BSS = 0 */
volatile ee_s32 seed3_volatile;   /* BSS = 0, set to 0x66 in portable_init */
volatile ee_s32 seed4_volatile;   /* BSS = 0, set to ITERATIONS in portable_init */
volatile ee_s32 seed5_volatile;   /* BSS = 0 */

/* ================================================================
 * dmem-mapped result registers (testbench reads these)
 * These overlap with the seed variables in address space since
 * results are written AFTER seeds are consumed.
 * Use higher addresses to avoid conflicts.
 * ================================================================ */
/* Result addresses: store at dmem[0..5].
 * These overlap with BSS (seed variables) but results are written
 * in portable_fini() AFTER the benchmark completes, so seeds are
 * no longer needed. Testbench reads dmem[0..5] after halt.
 * dmem uses addr[11:2]: 0x10000 -> dmem[0], 0x10004 -> dmem[1], etc. */
#define RESULT_CYCLES     (*(volatile unsigned int *)0x00010000)
#define RESULT_INSTRS     (*(volatile unsigned int *)0x00010004)
#define RESULT_BRANCHES   (*(volatile unsigned int *)0x00010008)
#define RESULT_MISPRED    (*(volatile unsigned int *)0x0001000C)
#define RESULT_ITERATIONS (*(volatile unsigned int *)0x00010010)
#define RESULT_CRC        (*(volatile unsigned int *)0x00010014)

/* ================================================================
 * CSR read helpers
 * ================================================================ */
unsigned int read_mcycle_port(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, mcycle" : "=r"(v));
    return v;
}

static inline unsigned int read_minstret(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, minstret" : "=r"(v));
    return v;
}

static inline unsigned int read_branches(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, 0xB04" : "=r"(v));
    return v;
}

static inline unsigned int read_mispred(void) {
    unsigned int v;
    __asm__ volatile("csrr %0, 0xB03" : "=r"(v));
    return v;
}

/* ================================================================
 * Timing
 * ================================================================ */
static CORETIMETYPE start_time_val, stop_time_val;

void start_time(void) {
    GETMYTIME(&start_time_val);
}

void stop_time(void) {
    GETMYTIME(&stop_time_val);
}

CORE_TICKS get_time(void) {
    return (CORE_TICKS)(MYTIMEDIFF(stop_time_val, start_time_val));
}

secs_ret time_in_secs(CORE_TICKS ticks) {
    secs_ret retval = ((secs_ret)ticks) / (secs_ret)EE_TICKS_PER_SEC;
    return retval;
}

/* ================================================================
 * Portable init / fini
 * ================================================================ */
ee_u32 default_num_contexts;  /* BSS=0, set to 1 in portable_init */

static unsigned int bench_start_cycles, bench_start_instrs;
static unsigned int bench_start_branches, bench_start_mispred;

void portable_init(core_portable *p, int *argc, char *argv[]) {
    (void)argc;
    (void)argv;

    /* Initialize seed variables.
     * Must happen here because our processor cannot copy .data
     * from imem to dmem at startup. BSS starts at 0.
     * CoreMark reads these AFTER portable_init() returns. */
    default_num_contexts = 1;
    seed3_volatile = 0x66;
    seed4_volatile = ITERATIONS;
    /* seed1=0, seed2=0 -> CoreMark auto-detects PERFORMANCE_RUN */

    /* Snapshot performance counters at benchmark start */
    bench_start_cycles   = read_mcycle_port();
    bench_start_instrs   = read_minstret();
    bench_start_branches = read_branches();
    bench_start_mispred  = read_mispred();

    if (sizeof(ee_ptr_int) != sizeof(ee_u8 *)) {
        /* pointer size mismatch -- halt */
        while(1);
    }

    p->portable_id = 1;
}

void portable_fini(core_portable *p) {
    /* Write performance counter deltas to dmem for testbench readout */
    RESULT_CYCLES     = read_mcycle_port()  - bench_start_cycles;
    RESULT_INSTRS     = read_minstret()     - bench_start_instrs;
    RESULT_BRANCHES   = read_branches()     - bench_start_branches;
    RESULT_MISPRED    = read_mispred()      - bench_start_mispred;
    RESULT_ITERATIONS = ITERATIONS;

    p->portable_id = 0;
}

/* ================================================================
 * ee_printf: no-op (no UART / stdio available)
 * Must be a real function, not a macro, because CoreMark
 * declares it as `int ee_printf(const char *fmt, ...)`.
 * ================================================================ */
int ee_printf(const char *fmt, ...) {
    (void)fmt;
    return 0;
}

/* ================================================================
 * memcpy / memset / memmove / memcmp
 * Bare-metal: no libc, so provide minimal implementations.
 * CoreMark needs these for MEM_STATIC data initialization.
 * ================================================================ */
void *memcpy(void *dst, const void *src, ee_size_t n) {
    ee_u8 *d = (ee_u8 *)dst;
    const ee_u8 *s = (const ee_u8 *)src;
    while (n--) *d++ = *s++;
    return dst;
}

void *memset(void *dst, int c, ee_size_t n) {
    ee_u8 *d = (ee_u8 *)dst;
    while (n--) *d++ = (ee_u8)c;
    return dst;
}

void *memmove(void *dst, const void *src, ee_size_t n) {
    ee_u8 *d = (ee_u8 *)dst;
    const ee_u8 *s = (const ee_u8 *)src;
    if (d < s) {
        while (n--) *d++ = *s++;
    } else {
        d += n; s += n;
        while (n--) *--d = *--s;
    }
    return dst;
}

int memcmp(const void *s1, const void *s2, ee_size_t n) {
    const ee_u8 *a = (const ee_u8 *)s1;
    const ee_u8 *b = (const ee_u8 *)s2;
    while (n--) {
        if (*a != *b) return *a - *b;
        a++; b++;
    }
    return 0;
}
