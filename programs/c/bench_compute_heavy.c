// bench_compute_heavy.c
// Compute-heavy workload (minimal branching). Results stored to dmem[0..4].

#define RESULT_CYCLES    (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS    (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES  (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED   (*(volatile unsigned int *)0x0000000C)
#define RESULT_CHECKSUM  (*(volatile unsigned int *)0x00000010)

static unsigned int csr_mcycle(void)    { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void)  { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void)  { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)   { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

static void use_value(int x) { asm volatile("" :: "r"(x)); }

// 4x4 matrix multiply
static void mat_mul(volatile int A[4][4], volatile int B[4][4], volatile int C[4][4]) {
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            int sum = 0;
            for (int k = 0; k < 4; k++)
                sum += A[i][k] * B[k][j];
            C[i][j] = sum;
        }
}

int main(void) {
    volatile int A[4][4], B[4][4], C[4][4];

    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            A[i][j] = i * 4 + j + 1;
            B[i][j] = 16 - (i * 4 + j);
        }

    // Snapshot BEFORE
    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    volatile int checksum = 0;

    // Phase 1: Matrix multiply x10
    for (int rep = 0; rep < 10; rep++) {
        mat_mul(A, B, C);
        for (int i = 0; i < 4; i++)
            checksum += C[i][i];
        for (int i = 0; i < 4; i++)
            for (int j = 0; j < 4; j++)
                A[i][j] = C[i][j];
    }

    // Phase 2: Multiply-accumulate
    for (int rep = 0; rep < 50; rep++) {
        int sum = 0;
        for (int i = 1; i <= 8; i++)
            sum += i * (i + rep);
        checksum += sum;
        use_value(sum);
    }

    // Phase 3: Division chain
    volatile int val = 1000000;
    for (int d = 2; d < 20; d++) {
        val = val / d;
        checksum += val;
        val = val * d + 1000000;
    }

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
    RESULT_CHECKSUM = checksum;

    return 0;
}
