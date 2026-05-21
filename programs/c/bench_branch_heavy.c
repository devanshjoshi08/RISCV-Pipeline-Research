// bench_branch_heavy.c
// Branch-heavy workload. Results stored to dmem[0..4].

// Store results to fixed memory addresses
#define RESULT_CYCLES    (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS    (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES  (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED   (*(volatile unsigned int *)0x0000000C)
#define RESULT_CHECKSUM  (*(volatile unsigned int *)0x00000010)

static unsigned int csr_mcycle(void)    { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void)  { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void)  { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)   { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

// Prevent compiler from optimizing away computations
static void use_value(int x) { asm volatile("" :: "r"(x)); }

// Binary search - unpredictable branches
static int bsearch_arr(volatile int *arr, int n, int target) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (arr[mid] == target) return mid;
        if (arr[mid] < target) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}

// Collatz - unpredictable even/odd
static int collatz(int n) {
    int steps = 0;
    while (n > 1) {
        if (n & 1) n = 3 * n + 1;
        else n = n >> 1;
        steps++;
    }
    return steps;
}

int main(void) {
    // Initialize array on stack
    volatile int arr[32];
    for (int i = 0; i < 32; i++)
        arr[i] = i * 3 + 1;

    // Snapshot BEFORE
    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    volatile int checksum = 0;

    // Phase 1: Binary search (unpredictable branches)
    for (int t = 0; t < 50; t++) {
        int target = (t * 7 + 3) % 100;
        int idx = bsearch_arr(arr, 32, target);
        checksum += idx;
    }

    // Phase 2: Collatz (unpredictable even/odd)
    for (int n = 2; n < 30; n++) {
        int s = collatz(n);
        checksum += s;
        use_value(s);
    }

    // Phase 3: Conditional chain
    for (int i = 0; i < 100; i++) {
        if (i % 2 == 0) checksum += 1;
        if (i % 3 == 0) checksum += 2;
        if (i % 5 == 0) checksum += 3;
        if (i % 7 == 0) checksum += 4;
    }

    asm volatile("" ::: "memory");
    // Snapshot AFTER
    unsigned int c1 = csr_mcycle();
    unsigned int i1 = csr_minstret();
    unsigned int b1 = csr_branches();
    unsigned int m1 = csr_mispred();

    // Store deltas to memory
    RESULT_CYCLES   = c1 - c0;
    RESULT_INSTRS   = i1 - i0;
    RESULT_BRANCHES = b1 - b0;
    RESULT_MISPRED  = m1 - m0;
    RESULT_CHECKSUM = checksum;

    return 0;
}
