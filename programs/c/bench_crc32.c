// bench_crc32.c - CRC-32 computation benchmark (Embench-IoT inspired).
// Real-world pattern: byte-level table-lookup CRC used in networking,
// storage, and communication protocols.
// Results stored to dmem[0..5].

#define RESULT_CYCLES     (*(volatile unsigned int *)0x00000000)
#define RESULT_INSTRS     (*(volatile unsigned int *)0x00000004)
#define RESULT_BRANCHES   (*(volatile unsigned int *)0x00000008)
#define RESULT_MISPRED    (*(volatile unsigned int *)0x0000000C)
#define RESULT_CHECKSUM   (*(volatile unsigned int *)0x00000010)

static unsigned int csr_mcycle(void)   { unsigned int v; asm volatile("csrr %0, mcycle"   : "=r"(v)); return v; }
static unsigned int csr_minstret(void) { unsigned int v; asm volatile("csrr %0, minstret" : "=r"(v)); return v; }
static unsigned int csr_branches(void) { unsigned int v; asm volatile("csrr %0, 0xB04"    : "=r"(v)); return v; }
static unsigned int csr_mispred(void)  { unsigned int v; asm volatile("csrr %0, 0xB03"    : "=r"(v)); return v; }

// CRC-32 (IEEE 802.3 polynomial) without lookup table to save ROM space
static unsigned int crc32_byte(unsigned int crc, unsigned char byte) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
        if (crc & 1)
            crc = (crc >> 1) ^ 0xEDB88320u;
        else
            crc = crc >> 1;
    }
    return crc;
}

static unsigned int crc32_buf(const unsigned char *buf, int len) {
    unsigned int crc = 0xFFFFFFFFu;
    for (int i = 0; i < len; i++)
        crc = crc32_byte(crc, buf[i]);
    return crc ^ 0xFFFFFFFFu;
}

int main(void) {
    // Generate test data (pseudo-random bytes)
    unsigned char data[128];
    unsigned int seed = 0x12345678u;
    for (int i = 0; i < 128; i++) {
        seed = seed * 1103515245u + 12345u;
        data[i] = (unsigned char)(seed >> 16);
    }

    unsigned int c0 = csr_mcycle();
    unsigned int i0 = csr_minstret();
    unsigned int b0 = csr_branches();
    unsigned int m0 = csr_mispred();
    asm volatile("" ::: "memory");

    volatile unsigned int result = 0;
    // Run CRC 50 times over the buffer
    for (int rep = 0; rep < 50; rep++) {
        result = crc32_buf(data, 128);
        // Modify one byte to change the CRC each iteration
        data[rep % 128] ^= (unsigned char)(rep + 1);
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
    RESULT_CHECKSUM = result;

    return 0;
}
