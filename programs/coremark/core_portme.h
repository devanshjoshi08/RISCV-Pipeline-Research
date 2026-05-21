/*
 * CoreMark porting layer for bare-metal RV32IM processor.
 * Uses mcycle CSR for timing. No OS, no stdio, no libc.
 */
#ifndef CORE_PORTME_H
#define CORE_PORTME_H

/* ---- Platform capabilities ---- */
#define HAS_FLOAT         0
#define HAS_TIME_H        0
#define USE_CLOCK         0
#define HAS_STDIO         0
#define HAS_PRINTF        0

/* ---- Data types for RV32 ---- */
typedef signed short   ee_s16;
typedef unsigned short ee_u16;
typedef signed int     ee_s32;
typedef unsigned int   ee_u32;
typedef double         ee_f32;   /* never used when HAS_FLOAT=0 */
typedef unsigned char  ee_u8;
typedef unsigned int   ee_ptr_int;
typedef unsigned int   ee_size_t;

/* ---- Compiler info strings ---- */
#ifndef COMPILER_VERSION
#ifdef __GNUC__
#define COMPILER_VERSION "GCC"__VERSION__
#else
#define COMPILER_VERSION "unknown"
#endif
#endif

#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS FLAGS_STR
#endif

#ifndef MEM_LOCATION
#define MEM_LOCATION "STATIC"
#endif

/* ---- Provide NULL (no libc) ---- */
#ifndef NULL
#define NULL ((void *)0)
#endif

/* ---- Memory alignment (required by core_matrix.c) ---- */
#define align_mem(x) (void *)(4 + (((ee_ptr_int)(x) - 1) & ~3))

/* ---- Timer ---- */
/* We use mcycle CSR (clock cycle counter) as our timer.
   CORETIMETYPE is the raw type for timestamps.
   CORE_TICKS is the elapsed-time type used by CoreMark's API. */
typedef unsigned int CORETIMETYPE;
typedef ee_u32       CORE_TICKS;

/* EE_TICKS_PER_SEC: set to a large value so CoreMark's auto-iteration
   detection doesn't interfere. We compute CoreMark/MHz externally. */
#define GETMYTIME(_t)              (*_t = read_mcycle_port())
#define MYTIMEDIFF(fin, ini)       ((fin) - (ini))
#define TIMER_RES_DIVIDER          1
#define SAMPLE_TIME_IMPLEMENTATION 1
#define EE_TICKS_PER_SEC           1000000

unsigned int read_mcycle_port(void);

/* ---- Seed / memory / execution config ---- */
#define SEED_METHOD       SEED_VOLATILE
#define MEM_METHOD        MEM_STATIC
#define MULTITHREAD       1
#define USE_PTHREAD       0
#define USE_FORK          0
#define USE_SOCKET        0

/* Bare metal: no argc/argv */
#define MAIN_HAS_NOARGC   1
#define MAIN_HAS_NORETURN 0

/* Data size and iterations */
#ifndef TOTAL_DATA_SIZE
#define TOTAL_DATA_SIZE (2 * 1000)
#endif

#ifndef ITERATIONS
#define ITERATIONS 10
#endif

/* Force PERFORMANCE_RUN */
#if !defined(PERFORMANCE_RUN) && !defined(VALIDATION_RUN) && !defined(PROFILE_RUN)
#define PERFORMANCE_RUN 1
#endif

/* ---- Porting structure ---- */
extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S {
    ee_u8 portable_id;
} core_portable;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);

/* ee_printf: declared as a real function (no-op body in core_portme.c) */
int ee_printf(const char *fmt, ...);

#endif /* CORE_PORTME_H */
