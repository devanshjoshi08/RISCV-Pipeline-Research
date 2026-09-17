# Speculative GHR characterization

Backend: verilator. All instrumented runs match the five uninstrumented `results.csv` fields exactly.

## Measurement contract

A prediction is captured when an actual conditional-branch instruction is accepted into IF/ID (IF2/ID at stages 7/8), not for repeated stalled lookups or NOP bubbles. Metadata follows the real stall/flush precedence through ID, EX1 and EX2. PC and actual prediction are asserted at resolution; observed SGF misses and resolved branches are asserted against the total CSR counters.

The shadow reads the **same SGF-trained PHT and BTB**, at `PC[7:2] XOR committed_ghr`, with the same BTB gating/type rules. It has no independent training, history updates, or writes to DUT state. Both PHT counters and GHR equality are sampled **before** the prediction edge's training updates. BTB misses are included (both effective predictions are not-taken).

Depth is the number of older accepted conditional branches in ID/EX1/EX2 immediately before the capture edge, including a branch resolving on that edge. It excludes JAL/JALR and squashed branches. The DUT's actual committed GHR is used unchanged, including its existing JAL updates.

Correctness is available only for resolved branches; accepted wrong-path branches discarded by flushes are counted as squashed, not classified as wrong. All counts cover the **whole program** including startup and termination, not just the benchmark's CSR-delta timing region. Consequently totals need not equal `results.csv` benchmark-region branch/miss counts.

Reproduce with `python3 scripts/characterize_sgf.py` (Verilator default). Use `--backend icarus`, `--benchmarks NAME ...`, or `--output-dir PATH` for isolated smoke tests. No ordinary evaluation output is rewritten.

## Main findings

| Stage | Resolved prediction changes | Helps | Hurts | Net correctness gain vs shadow | Oracle additional miss reduction vs SGF |
|---:|---:|---:|---:|---:|---:|
| 6 | 9.486% | 300537 | 73242 | 227295 branches | 12.976% |
| 7 | 8.161% | 250802 | 70763 | 180039 branches | 12.604% |
| 8 | 11.494% | 368894 | 84000 | 284894 branches | 14.739% |

Higher unresolved depth often accompanies more prediction changes, but a correlation with disagreement is not the same as predicting which source is correct. Compare the help/hurt rates below and the fixed-bin selector bounds: a depth-only selector may have no net benefit even where it strongly predicts disagreement. SGF PHT confidence must likewise be evaluated by state and direction, rather than treating all weak or saturated counters alike.

## Per-workload comparison

| Benchmark | Stage | Resolved | Resolved changes | Resolved changes % | Accepted changes % | SGF-only correct (helps) | Committed-only correct (hurts) | Both correct | Both wrong | Squashed | Oracle saved vs SGF |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| aha-mont64 | 6 | 513691 | 79388 | 15.454% | 23.621% | 68961 | 10427 | 328821 | 105482 | 112136 | 10427 (8.996% of SGF misses) |
| aha-mont64 | 7 | 513691 | 79388 | 15.454% | 22.128% | 68961 | 10427 | 328821 | 105482 | 49700 | 10427 (8.996% of SGF misses) |
| aha-mont64 | 8 | 513691 | 80330 | 15.638% | 22.360% | 69432 | 10898 | 328350 | 105011 | 50173 | 10898 (9.402% of SGF misses) |
| bench_branch_heavy | 6 | 2045 | 555 | 27.139% | 26.316% | 357 | 198 | 1138 | 352 | 330 | 198 (36.000% of SGF misses) |
| bench_branch_heavy | 7 | 2045 | 420 | 20.538% | 20.432% | 226 | 194 | 1299 | 326 | 133 | 194 (37.308% of SGF misses) |
| bench_branch_heavy | 8 | 2045 | 417 | 20.391% | 20.340% | 222 | 195 | 1313 | 315 | 133 | 195 (38.235% of SGF misses) |
| coremark | 6 | 720323 | 95922 | 13.317% | 13.778% | 86911 | 9011 | 531993 | 92408 | 61225 | 9011 (8.885% of SGF misses) |
| coremark | 7 | 720323 | 45845 | 6.365% | 7.432% | 36877 | 8968 | 582027 | 92451 | 47317 | 8968 (8.843% of SGF misses) |
| coremark | 8 | 720323 | 81892 | 11.369% | 12.120% | 71105 | 10787 | 547164 | 91267 | 47408 | 10787 (10.570% of SGF misses) |
| crc32 | 6 | 175628 | 0 | 0.000% | 0.001% | 0 | 0 | 175108 | 520 | 181 | 0 (0.000% of SGF misses) |
| crc32 | 7 | 175628 | 0 | 0.000% | 0.000% | 0 | 0 | 175108 | 520 | 180 | 0 (0.000% of SGF misses) |
| crc32 | 8 | 175628 | 1360 | 0.774% | 0.774% | 1356 | 4 | 173751 | 517 | 180 | 4 (0.768% of SGF misses) |
| edn | 6 | 345234 | 5 | 0.001% | 0.001% | 0 | 5 | 334610 | 10619 | 490 | 5 (0.047% of SGF misses) |
| edn | 7 | 345234 | 5 | 0.001% | 0.001% | 0 | 5 | 334610 | 10619 | 490 | 5 (0.047% of SGF misses) |
| edn | 8 | 345234 | 5 | 0.001% | 0.001% | 0 | 5 | 334610 | 10619 | 490 | 5 (0.047% of SGF misses) |
| huffbench | 6 | 638861 | 64518 | 10.099% | 13.786% | 44229 | 20289 | 484728 | 89615 | 76640 | 20289 (18.461% of SGF misses) |
| huffbench | 7 | 638861 | 64515 | 10.098% | 13.618% | 44272 | 20243 | 484685 | 89661 | 68509 | 20243 (18.419% of SGF misses) |
| huffbench | 8 | 638861 | 134328 | 21.026% | 23.431% | 110347 | 23981 | 418321 | 86212 | 65624 | 23981 (21.763% of SGF misses) |
| matmult-int | 6 | 467950 | 44 | 0.009% | 0.018% | 40 | 4 | 450818 | 17088 | 2200 | 4 (0.023% of SGF misses) |
| matmult-int | 7 | 467950 | 44 | 0.009% | 0.018% | 40 | 4 | 450818 | 17088 | 2199 | 4 (0.023% of SGF misses) |
| matmult-int | 8 | 467950 | 44 | 0.009% | 0.018% | 40 | 4 | 450818 | 17088 | 2199 | 4 (0.023% of SGF misses) |
| nettle-aes | 6 | 70968 | 11272 | 15.883% | 16.774% | 10078 | 1194 | 53699 | 5997 | 2215 | 1194 (16.604% of SGF misses) |
| nettle-aes | 7 | 70968 | 13118 | 18.484% | 18.346% | 12097 | 1021 | 51505 | 6345 | 1425 | 1021 (13.861% of SGF misses) |
| nettle-aes | 8 | 70968 | 22750 | 32.057% | 31.686% | 20516 | 2234 | 43089 | 5129 | 1350 | 2234 (30.341% of SGF misses) |
| sglib-combined | 6 | 629211 | 102094 | 16.226% | 15.100% | 73321 | 28773 | 411327 | 115790 | 160902 | 28773 (19.903% of SGF misses) |
| sglib-combined | 7 | 629211 | 104911 | 16.673% | 16.188% | 75015 | 29896 | 412800 | 111500 | 118279 | 29896 (21.143% of SGF misses) |
| sglib-combined | 8 | 629211 | 118449 | 18.825% | 18.353% | 82562 | 35887 | 397659 | 113103 | 122661 | 35887 (24.087% of SGF misses) |
| statemate | 6 | 376473 | 19981 | 5.307% | 5.081% | 16640 | 3341 | 303171 | 53321 | 16744 | 3341 (5.896% of SGF misses) |
| statemate | 7 | 376473 | 13319 | 3.538% | 3.387% | 13314 | 5 | 306497 | 56657 | 16743 | 5 (0.009% of SGF misses) |
| statemate | 8 | 376473 | 13319 | 3.538% | 3.387% | 13314 | 5 | 306497 | 56657 | 16743 | 5 (0.009% of SGF misses) |

## Confidence, depth and history strata

Each row aggregates resolved branches across workloads at one stage. Helps/hurts are the two disagreement categories. The last column estimates how often choosing the committed-GHR shadow would help **given a disagreement** in that stratum. This is descriptive in-sample evidence, not a fitted or out-of-sample selector.

### SGF PHT counter

| Stage | State | Resolved | Changes % | Helps | Hurts | Shadow-correct given disagreement |
|---:|---|---:|---:|---:|---:|---:|
| 6 | 00 | 1186845 | 16.118% | 169078 | 22213 | 11.612% |
| 6 | 01 | 276951 | 12.757% | 21060 | 14270 | 40.391% |
| 6 | 10 | 288054 | 10.363% | 13657 | 16193 | 54.248% |
| 6 | 11 | 2188534 | 5.360% | 96742 | 20566 | 17.532% |
| 7 | 00 | 1188737 | 12.003% | 119498 | 23187 | 16.250% |
| 7 | 01 | 275974 | 12.305% | 21583 | 12375 | 36.442% |
| 7 | 10 | 282443 | 11.574% | 16325 | 16365 | 50.061% |
| 7 | 11 | 2193230 | 5.117% | 93396 | 18836 | 16.783% |
| 8 | 00 | 1182113 | 17.922% | 182070 | 29791 | 14.062% |
| 8 | 01 | 277340 | 14.236% | 25794 | 13687 | 34.667% |
| 8 | 10 | 288624 | 12.009% | 16960 | 17701 | 51.069% |
| 8 | 11 | 2192307 | 7.613% | 144070 | 22821 | 13.674% |

### Shadow PHT counter

| Stage | State | Resolved | Changes % | Helps | Hurts | Shadow-correct given disagreement |
|---:|---|---:|---:|---:|---:|---:|
| 6 | 00 | 945535 | 9.504% | 67387 | 22474 | 25.010% |
| 6 | 01 | 379729 | 15.089% | 43012 | 14285 | 24.931% |
| 6 | 10 | 298416 | 13.580% | 32609 | 7915 | 19.532% |
| 6 | 11 | 2316704 | 8.033% | 157529 | 28568 | 15.351% |
| 7 | 00 | 997428 | 8.821% | 65771 | 22208 | 25.242% |
| 7 | 01 | 371494 | 15.328% | 43950 | 12993 | 22.818% |
| 7 | 10 | 292620 | 13.633% | 31668 | 8224 | 20.616% |
| 7 | 11 | 2278842 | 6.001% | 109413 | 27338 | 19.991% |
| 8 | 00 | 995197 | 10.100% | 75931 | 24580 | 24.455% |
| 8 | 01 | 351192 | 28.771% | 85099 | 15942 | 15.778% |
| 8 | 10 | 306976 | 13.780% | 32970 | 9332 | 22.060% |
| 8 | 11 | 2287019 | 9.140% | 174894 | 34146 | 16.335% |

### Unresolved depth

| Stage | State | Resolved | Changes % | Helps | Hurts | Shadow-correct given disagreement |
|---:|---|---:|---:|---:|---:|---:|
| 6 | 0 | 2807684 | 2.099% | 40315 | 18613 | 31.586% |
| 6 | 1 | 1020082 | 26.508% | 221879 | 48524 | 17.945% |
| 6 | 2 | 76564 | 58.051% | 38341 | 6105 | 13.736% |
| 6 | 3 | 36054 | 0.006% | 2 | 0 | 0.000% |
| 7 | 0 | 3199424 | 2.335% | 51194 | 23513 | 31.474% |
| 7 | 1 | 630118 | 32.145% | 161404 | 41145 | 20.314% |
| 7 | 2 | 75273 | 58.864% | 38204 | 6105 | 13.778% |
| 7 | 3 | 35569 | 0.000% | 0 | 0 | n/a |
| 8 | 0 | 3204185 | 2.894% | 64495 | 28248 | 30.458% |
| 8 | 1 | 627375 | 50.450% | 266745 | 49764 | 15.723% |
| 8 | 2 | 73256 | 59.575% | 37654 | 5988 | 13.721% |
| 8 | 3 | 35568 | 0.000% | 0 | 0 | n/a |

### GHR differs

| Stage | State | Resolved | Changes % | Helps | Hurts | Shadow-correct given disagreement |
|---:|---|---:|---:|---:|---:|---:|
| 6 | 0 | 2932083 | 0.000% | 0 | 0 | n/a |
| 6 | 1 | 1008301 | 37.070% | 300537 | 73242 | 19.595% |
| 7 | 0 | 2949344 | 0.000% | 0 | 0 | n/a |
| 7 | 1 | 991040 | 32.447% | 250802 | 70763 | 22.006% |
| 8 | 0 | 2952375 | 0.000% | 0 | 0 | n/a |
| 8 | 1 | 988009 | 45.839% | 368894 | 84000 | 18.547% |

## Predictive signal assessment

The following idealized **in-sample fixed-bin selectors** choose one direction source for each stratum, using the observed majority of helps vs hurts. They pool workloads within each stage and save `max(0, hurts - helps)` misses per stratum relative to always using SGF. Thus they quantify available confidence/depth signal but are optimistic training-set estimates, not proposed architectural changes or validated classifiers.

| Stage | Selector features | Misses saved vs SGF | Per-branch oracle saves | Fraction of oracle captured |
|---:|---|---:|---:|---:|
| 6 | sgf_counter | 2536 | 73242 | 3.462% |
| 6 | depth | 0 | 73242 | 0.000% |
| 6 | sgf_counter, depth | 3824 | 73242 | 5.221% |
| 6 | sgf_counter, shadow_counter, depth, ghr_diff, btb_hit | 4412 | 73242 | 6.024% |
| 7 | sgf_counter | 40 | 70763 | 0.057% |
| 7 | depth | 0 | 70763 | 0.000% |
| 7 | sgf_counter, depth | 3549 | 70763 | 5.015% |
| 7 | sgf_counter, shadow_counter, depth, ghr_diff, btb_hit | 5339 | 70763 | 7.545% |
| 8 | sgf_counter | 741 | 84000 | 0.882% |
| 8 | depth | 0 | 84000 | 0.000% |
| 8 | sgf_counter, depth | 3673 | 84000 | 4.373% |
| 8 | sgf_counter, shadow_counter, depth, ghr_diff, btb_hit | 3774 | 84000 | 4.493% |

## Oracle interpretation

An ideal direction selector on this fixed SGF execution/training stream can eliminate every committed-only-correct miss, leaving exactly `both_wrong` misses. Its correctness upper bound is `resolved - both_wrong`. This is **not** a counterfactual cycle/speedup bound: selecting a different prediction would change future fetches, histories and PHT training. The shadow is not a separately trained baseline predictor.

In particular, zero shadow disagreements do not prove SGF has no effect versus a standalone baseline: SGF and a baseline can have different PHT training and execution trajectories. An ideal selector between the two lookups observed here cannot repair those historical training differences.

The CSV preserves the joint SGF/shadow counter states, depth, GHR equality and BTB hit for all categories, enabling per-workload confidence/depth analysis without losing strata.
