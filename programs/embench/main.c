/*
 * Embench-IoT main wrapper for bare-metal RV32IM processor.
 * Based on the official Embench main.c structure.
 */

#include "support.h"

/* Provided by board.c */
extern void store_correct(int correct);

int main(void) {
    volatile int result;
    int correct;

    initialise_board();
    initialise_benchmark();

    /* Warm caches -- run benchmark once without timing */
    warm_caches(1);

    /* Timed run */
    start_trigger();
    result = benchmark();
    stop_trigger();

    correct = verify_benchmark(result);
    store_correct(correct);

    return (!correct);
}
