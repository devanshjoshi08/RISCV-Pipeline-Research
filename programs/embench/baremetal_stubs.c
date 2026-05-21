/*
 * Bare-metal stubs for Embench-IoT benchmarks on RV32IM.
 * Provides minimal implementations of libc functions used by benchmarks.
 */

#include <stddef.h>

/* ---- assert stub ---- */
void __assert_func(const char *file, int line, const char *func, const char *expr) {
    (void)file; (void)line; (void)func; (void)expr;
    while(1); /* halt on assertion failure */
}

/* ---- string.h functions ---- */
void *memcpy(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

void *memset(void *dst, int c, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    while (n--) *d++ = (unsigned char)c;
    return dst;
}

void *memmove(void *dst, const void *src, size_t n) {
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    if (d < s) {
        while (n--) *d++ = *s++;
    } else {
        d += n; s += n;
        while (n--) *--d = *--s;
    }
    return dst;
}

int memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *a = (const unsigned char *)s1;
    const unsigned char *b = (const unsigned char *)s2;
    while (n--) {
        if (*a != *b) return *a - *b;
        a++; b++;
    }
    return 0;
}

size_t strlen(const char *s) {
    size_t n = 0;
    while (*s++) n++;
    return n;
}

char *strcpy(char *dst, const char *src) {
    char *d = dst;
    while ((*d++ = *src++));
    return dst;
}

int strcmp(const char *s1, const char *s2) {
    while (*s1 && (*s1 == *s2)) { s1++; s2++; }
    return *(unsigned char *)s1 - *(unsigned char *)s2;
}

/* ---- stdlib.h functions ---- */
int abs(int x) { return x < 0 ? -x : x; }

/* Simple LCG random number generator (used by crc32 benchmark) */
static unsigned int rand_state = 12345;
int rand(void) {
    rand_state = rand_state * 1103515245 + 12345;
    return (int)((rand_state >> 16) & 0x7FFF);
}
void srand(unsigned int seed) { rand_state = seed; }

/* ---- stdio.h functions ---- */
int printf(const char *fmt, ...) { (void)fmt; return 0; }
int fprintf(void *stream, const char *fmt, ...) { (void)stream; (void)fmt; return 0; }
int puts(const char *s) { (void)s; return 0; }
int putchar(int c) { (void)c; return c; }
