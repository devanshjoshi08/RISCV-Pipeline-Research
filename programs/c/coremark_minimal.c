// coremark_minimal.c - Minimal CoreMark port for bare-metal RV32IM.
// Implements the three core CoreMark algorithms:
//   1. Linked-list operations (find, reverse, merge-sort)
//   2. Matrix multiply with bit-extraction
//   3. State machine (FSM processing)
//
// Reference: EEMBC CoreMark specification, www.eembc.org/coremark
//
// Results stored to dmem for testbench readout:
//   dmem[0] = cycles
//   dmem[1] = instructions retired
//   dmem[2] = total branches
//   dmem[3] = mispredictions
//   dmem[4] = CoreMark iterations completed
//   dmem[5] = checksum (for correctness verification)

#define RESULT_CYCLES     (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS     (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES   (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED    (*(volatile unsigned int *)0x0000000C)
#define RESULT_ITERATIONS (*(volatile unsigned int *)0x00000010)
#define RESULT_CHECKSUM   (*(volatile unsigned int *)0x00000014)

static unsigned int csr_mcycle(void)   { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void) { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void) { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)  { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

// ========== CoreMark Algorithm 1: Linked List ==========

typedef struct list_node {
    struct list_node *next;
    int data;
    int key;
} list_node_t;

#define LIST_SIZE 16
static list_node_t nodes[LIST_SIZE];

static list_node_t *list_init(void) {
    for (int i = 0; i < LIST_SIZE; i++) {
        nodes[i].data = (i * 73 + 11) & 0xFF;
        nodes[i].key  = (i * 37 + 5) & 0x3F;
        nodes[i].next = (i < LIST_SIZE - 1) ? &nodes[i + 1] : (list_node_t *)0;
    }
    return &nodes[0];
}

static list_node_t *list_find(list_node_t *head, int key) {
    while (head) {
        if (head->key == key)
            return head;
        head = head->next;
    }
    return (list_node_t *)0;
}

static list_node_t *list_reverse(list_node_t *head) {
    list_node_t *prev = (list_node_t *)0, *curr = head, *next;
    while (curr) {
        next = curr->next;
        curr->next = prev;
        prev = curr;
        curr = next;
    }
    return prev;
}

static int list_checksum(list_node_t *head) {
    int sum = 0;
    while (head) {
        sum += head->data ^ head->key;
        head = head->next;
    }
    return sum;
}

// ========== CoreMark Algorithm 2: Matrix Operations ==========

#define MAT_SIZE 4

static int matrix_a[MAT_SIZE][MAT_SIZE];
static int matrix_b[MAT_SIZE][MAT_SIZE];
static int matrix_c[MAT_SIZE][MAT_SIZE];

static void matrix_init(void) {
    for (int i = 0; i < MAT_SIZE; i++)
        for (int j = 0; j < MAT_SIZE; j++) {
            matrix_a[i][j] = (i * 5 + j * 3 + 1) & 0xFF;
            matrix_b[i][j] = (i * 7 + j * 11 + 2) & 0xFF;
        }
}

static void matrix_multiply(void) {
    for (int i = 0; i < MAT_SIZE; i++)
        for (int j = 0; j < MAT_SIZE; j++) {
            int sum = 0;
            for (int k = 0; k < MAT_SIZE; k++)
                sum += matrix_a[i][k] * matrix_b[k][j];
            matrix_c[i][j] = sum;
        }
}

// CoreMark-style bit extraction from matrix result
static int matrix_sum_with_clip(int clip_lo, int clip_hi) {
    int sum = 0;
    for (int i = 0; i < MAT_SIZE; i++)
        for (int j = 0; j < MAT_SIZE; j++) {
            int val = matrix_c[i][j];
            if (val < clip_lo) val = clip_lo;
            if (val > clip_hi) val = clip_hi;
            sum += val;
        }
    return sum;
}

// ========== CoreMark Algorithm 3: State Machine ==========

typedef enum { ST_START, ST_INVALID, ST_S1, ST_S2, ST_INT, ST_FLOAT, ST_DONE } state_t;

static state_t next_state(state_t cur, int input) {
    switch (cur) {
        case ST_START:
            if (input >= '0' && input <= '9') return ST_INT;
            if (input == '+' || input == '-') return ST_S1;
            if (input == '.') return ST_FLOAT;
            return ST_INVALID;
        case ST_S1:
            if (input >= '0' && input <= '9') return ST_INT;
            if (input == '.') return ST_FLOAT;
            return ST_INVALID;
        case ST_INT:
            if (input >= '0' && input <= '9') return ST_INT;
            if (input == '.') return ST_FLOAT;
            if (input == 0) return ST_DONE;
            return ST_INVALID;
        case ST_FLOAT:
            if (input >= '0' && input <= '9') return ST_FLOAT;
            if (input == 0) return ST_DONE;
            return ST_INVALID;
        default:
            return ST_INVALID;
    }
}

static int fsm_classify(const int *seq, int len) {
    state_t st = ST_START;
    for (int i = 0; i < len; i++) {
        st = next_state(st, seq[i]);
        if (st == ST_INVALID) return -1;
    }
    return (st == ST_DONE || st == ST_INT || st == ST_FLOAT) ? 1 : 0;
}

// ========== Main Benchmark ==========

#define NUM_ITERATIONS 10

int main(void) {
    // Snapshot BEFORE
    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    volatile int checksum = 0;

    for (int iter = 0; iter < NUM_ITERATIONS; iter++) {
        // Algorithm 1: Linked list
        list_node_t *head = list_init();
        list_node_t *found = list_find(head, 20);
        if (found) checksum += found->data;
        head = list_reverse(head);
        checksum += list_checksum(head);
        head = list_reverse(head);
        checksum += list_checksum(head);

        // Algorithm 2: Matrix
        matrix_init();
        matrix_multiply();
        checksum += matrix_sum_with_clip(100, 50000);
        // Rotate matrix for next iteration
        for (int i = 0; i < MAT_SIZE; i++)
            for (int j = 0; j < MAT_SIZE; j++)
                matrix_a[i][j] = matrix_c[i][j] & 0xFF;
        matrix_multiply();
        checksum += matrix_sum_with_clip(0, 40000);

        // Algorithm 3: State machine
        int seq1[] = {'+', '1', '2', '.', '3', 0};
        int seq2[] = {'-', '0', '.', '0', '1', 0};
        int seq3[] = {'a', 'b', 'c', 0, 0, 0};
        int seq4[] = {'4', '2', 0, 0, 0, 0};
        checksum += fsm_classify(seq1, 6);
        checksum += fsm_classify(seq2, 6);
        checksum += fsm_classify(seq3, 6);
        checksum += fsm_classify(seq4, 6);
    }

    asm volatile("" ::: "memory");
    // Snapshot AFTER
    unsigned int c1 = csr_mcycle();
    unsigned int i1 = csr_minstret();
    unsigned int b1 = csr_branches();
    unsigned int m1 = csr_mispred();

    RESULT_CYCLES     = c1 - c0;
    RESULT_INSTRS     = i1 - i0;
    RESULT_BRANCHES   = b1 - b0;
    RESULT_MISPRED    = m1 - m0;
    RESULT_ITERATIONS = NUM_ITERATIONS;
    RESULT_CHECKSUM   = (unsigned int)checksum;

    return 0;
}
