# SGF result analysis

Source: `results_new/results.csv`

Positive reductions mean SGF improved the metric. Speedup is calculated as baseline cycles divided by SGF cycles; speedup percent is `(speedup - 1) × 100`.

## Per-workload results

| Benchmark | Stage | Mispred reduction | MPKI reduction | CPI reduction | Speedup |
|---|---:|---:|---:|---:|---:|
| aha-mont64 | 6 | 17.243% | 17.243% | 1.289% | 1.306% |
| aha-mont64 | 7 | 17.243% | 17.243% | 1.232% | 1.247% |
| aha-mont64 | 8 | 17.243% | 17.243% | 1.237% | 1.253% |
| bench_branch_heavy | 6 | 20.991% | 20.991% | 3.195% | 3.301% |
| bench_branch_heavy | 7 | 11.265% | 11.265% | 1.123% | 1.136% |
| bench_branch_heavy | 8 | 12.998% | 12.998% | 1.450% | 1.471% |
| coremark | 6 | 34.177% | 34.177% | 2.975% | 3.066% |
| coremark | 7 | 31.363% | 31.363% | 2.731% | 2.807% |
| coremark | 8 | 30.933% | 30.933% | 2.494% | 2.558% |
| crc32 | 6 | -48.547% | -48.547% | -0.009% | -0.009% |
| crc32 | 7 | -48.547% | -48.547% | -0.008% | -0.008% |
| crc32 | 8 | -49.128% | -49.128% | -0.008% | -0.008% |
| edn | 6 | 0.000% | 0.000% | 0.000% | 0.000% |
| edn | 7 | 0.000% | 0.000% | 0.000% | 0.000% |
| edn | 8 | 0.000% | 0.000% | 0.000% | 0.000% |
| huffbench | 6 | 42.486% | 42.486% | 6.225% | 6.639% |
| huffbench | 7 | 42.486% | 42.486% | 7.345% | 7.927% |
| huffbench | 8 | 42.335% | 42.335% | 6.683% | 7.162% |
| matmult-int | 6 | 0.432% | 0.432% | 0.004% | 0.004% |
| matmult-int | 7 | 0.432% | 0.432% | 0.005% | 0.005% |
| matmult-int | 8 | 0.432% | 0.432% | 0.004% | 0.004% |
| nettle-aes | 6 | 22.876% | 22.876% | 0.119% | 0.119% |
| nettle-aes | 7 | 20.717% | 20.717% | 0.105% | 0.105% |
| nettle-aes | 8 | 20.761% | 20.761% | 0.094% | 0.094% |
| sglib-combined | 6 | 20.203% | 20.203% | 2.353% | 2.409% |
| sglib-combined | 7 | 21.757% | 21.757% | 2.718% | 2.794% |
| sglib-combined | 8 | 17.544% | 17.544% | 2.025% | 2.066% |
| statemate | 6 | 19.027% | 19.027% | 0.921% | 0.929% |
| statemate | 7 | 22.707% | 22.707% | 1.052% | 1.064% |
| statemate | 8 | 22.707% | 22.707% | 0.929% | 0.938% |

## Stage summaries

| Stage | Geomean speedup | Arithmetic mean MPKI reduction | Geomean MPKI improvement |
|---:|---:|---:|---:|
| 6 | 1.017565× (1.757%) | 12.889% | 18.546% |
| 7 | 1.016822× (1.682%) | 11.942% | 17.139% |
| 8 | 1.015334× (1.533%) | 11.583% | 16.614% |

## SGF regressions

| Benchmark | Stage | MPKI reduction | Speedup |
|---|---:|---:|---:|
| crc32 | 6 | -48.547% | -0.009% |
| crc32 | 7 | -48.547% | -0.008% |
| crc32 | 8 | -49.128% | -0.008% |
