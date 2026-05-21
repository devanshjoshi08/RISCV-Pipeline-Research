/*
 * Embench-IoT board support for bare-metal RV32IM processor.
 * Provides timing via mcycle CSR and result storage to dmem.
 */

#include "support.h"

/* CSR read helpers */
static inline unsigned int read_mcycle(void) {
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

/* Snapshots taken at start_trigger */
static unsigned int t_cycles, t_instrs, t_branches, t_mispred;

/* dmem result addresses: dmem[0..5]
 * dmem uses addr[11:2], so 0x10000 -> dmem[0] */
#define RESULT_CYCLES     (*(volatile unsigned int *)0x00010000)
#define RESULT_INSTRS     (*(volatile unsigned int *)0x00010004)
#define RESULT_BRANCHES   (*(volatile unsigned int *)0x00010008)
#define RESULT_MISPRED    (*(volatile unsigned int *)0x0001000C)
#define RESULT_CORRECT    (*(volatile unsigned int *)0x00010010)

void initialise_board(void) {
    /* nothing to do on bare metal */
}

void start_trigger(void) {
    t_cycles   = read_mcycle();
    t_instrs   = read_minstret();
    t_branches = read_branches();
    t_mispred  = read_mispred();
}

void stop_trigger(void) {
    RESULT_CYCLES   = read_mcycle()   - t_cycles;
    RESULT_INSTRS   = read_minstret() - t_instrs;
    RESULT_BRANCHES = read_branches() - t_branches;
    RESULT_MISPRED  = read_mispred()  - t_mispred;
}

/* Called from main after verify_benchmark */
void store_correct(int correct) {
    RESULT_CORRECT = correct;
}
