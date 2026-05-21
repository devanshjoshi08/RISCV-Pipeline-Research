// bench_sort.c - Insertion sort + binary search benchmark (Embench-IoT inspired).
// Real-world pattern: sorting and searching in embedded data processing.
// Insertion sort has highly data-dependent branch behavior.
// Results stored to dmem[0..4].

#define RESULT_CYCLES     (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS     (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES   (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED    (*(volatile unsigned int *)0x0000000C)
#define RESULT_CHECKSUM   (*(volatile unsigned int *)0x00000010)

static unsigned int csr_mcycle(void)   { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void) { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void) { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)  { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

static void insertion_sort(volatile int *arr, int n) {
    for (int i = 1; i < n; i++) {
        int key = arr[i];
        int j = i - 1;
        while (j >= 0 && arr[j] > key) {
            arr[j + 1] = arr[j];
            j--;
        }
        arr[j + 1] = key;
    }
}

static int binary_search(volatile int *arr, int n, int target) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (arr[mid] == target) return mid;
        if (arr[mid] < target) lo = mid + 1;
        else hi = mid - 1;
    }
    return -1;
}

int main(void) {
    volatile int arr[64];

    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    volatile int checksum = 0;
    unsigned int seed = 0xDEADBEEFu;

    // Repeat: fill array with pseudo-random data, sort, search
    for (int rep = 0; rep < 20; rep++) {
        // Fill with pseudo-random values
        for (int i = 0; i < 64; i++) {
            seed = seed * 1664525u + 1013904223u;
            arr[i] = (int)(seed >> 8) & 0x3FF; // 0-1023
        }

        // Sort
        insertion_sort(arr, 64);

        // Verify sorted + accumulate checksum
        for (int i = 0; i < 63; i++) {
            if (arr[i] > arr[i + 1])
                checksum -= 1000; // penalty for unsorted
        }
        checksum += arr[0] + arr[63];

        // Binary search for several values
        for (int q = 0; q < 10; q++) {
            seed = seed * 1664525u + 1013904223u;
            int target = (int)(seed >> 8) & 0x3FF;
            int idx = binary_search(arr, 64, target);
            checksum += idx;
        }
    }

    asm volatile("" ::: "memory");
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
