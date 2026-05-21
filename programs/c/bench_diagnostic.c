// bench_diagnostic.c
// Minimal diagnostic benchmark. Simple loops, no function calls.
// If instruction counts differ between pipeline variants, there's a bug.
// Expected: all variants must produce identical checksum and instruction count.

#define RESULT_CYCLES    (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS    (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES  (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED   (*(volatile unsigned int *)0x0000000C)
#define RESULT_CHECKSUM  (*(volatile unsigned int *)0x00000010)

static unsigned int csr_mcycle(void)    { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void)  { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void)  { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)   { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

int main(void) {
    // Snapshot BEFORE
    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    // Simple sum: 1 + 2 + ... + 200 = 20100
    volatile int sum = 0;
    for (int i = 1; i <= 200; i++) {
        sum += i;
    }

    // Simple multiply chain
    volatile int prod = 1;
    for (int i = 1; i <= 10; i++) {
        prod = prod * i + 1;
    }

    // Simple alternating branch pattern
    volatile int alt = 0;
    for (int i = 0; i < 100; i++) {
        if (i & 1)
            alt += 1;
        else
            alt += 2;
    }

    int checksum = sum + prod + alt;

    asm volatile("" ::: "memory");
    // Snapshot AFTER
    unsigned int c1 = csr_mcycle();
    unsigned int i1 = csr_minstret();
    unsigned int b1 = csr_branches();
    unsigned int m1 = csr_mispred();

    RESULT_CYCLES   = c1 - c0;
    RESULT_INSTRS   = i1 - i0;
    RESULT_BRANCHES = b1 - b0;
    RESULT_MISPRED  = m1 - m0;
    RESULT_CHECKSUM = (unsigned int)checksum;

    return 0;
}
