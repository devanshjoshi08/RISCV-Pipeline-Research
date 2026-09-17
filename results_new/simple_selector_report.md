# Simple selector disagreement analysis

Only resolved conditional branches where SGF and committed-history shadow predictions disagree are included. Counts are whole-program counts, including setup and termination, rather than benchmark-region counters. Wrong-path predictions without a resolved outcome are excluded. No RTL, predictor decisions, existing result files, or ML models were changed.

The shadow reads the same SGF-trained PHT/BTB using committed GHR; it is not an independently trained baseline. Counter state is recorded at prediction time. Both SGF and shadow counter breakdowns are supplied to avoid ambiguity. Stages are separate in the tables and also pooled by case count; stage runs are not independent workload samples.

## Missing history-distance information

The existing characterization.csv stores only ghr_diff (history equality), not the GHR bit patterns or Hamming distance. All resolved disagreements have ghr_diff=1. Therefore distance zero has zero cases, but positive distances and one-bit versus multiple-bit differences cannot be recovered. These are explicitly unavailable in the CSV (blank counts and percentages, not zeros). No simulation was rerun and no instrumentation was modified.

## Overall winner tables

### Stage ALL

All disagreement cases

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| all | 1148238 | 920233 | 228005 | 80.14 | 19.86 |

SGF PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 545837 | 470646 | 75191 | 86.22 | 13.78 |
| 01 | 108769 | 68437 | 40332 | 62.92 | 37.08 |
| 10 | 97201 | 46942 | 50259 | 48.29 | 51.71 |
| 11 | 396431 | 334208 | 62223 | 84.30 | 15.70 |

Committed-history shadow PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 278351 | 209089 | 69262 | 75.12 | 24.88 |
| 01 | 215281 | 172061 | 43220 | 79.92 | 20.08 |
| 10 | 122718 | 97247 | 25471 | 79.24 | 20.76 |
| 11 | 531888 | 441836 | 90052 | 83.07 | 16.93 |

Unresolved branch depth

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 0 | 226378 | 156004 | 70374 | 68.91 | 31.09 |
| 1 | 789461 | 650028 | 139433 | 82.34 | 17.66 |
| 2 | 132397 | 114199 | 18198 | 86.25 | 13.75 |
| 3 | 2 | 2 | 0 | 100.00 | 0.00 |

### Stage 6

All disagreement cases

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| all | 373779 | 300537 | 73242 | 80.40 | 19.60 |

SGF PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 191291 | 169078 | 22213 | 88.39 | 11.61 |
| 01 | 35330 | 21060 | 14270 | 59.61 | 40.39 |
| 10 | 29850 | 13657 | 16193 | 45.75 | 54.25 |
| 11 | 117308 | 96742 | 20566 | 82.47 | 17.53 |

Committed-history shadow PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 89861 | 67387 | 22474 | 74.99 | 25.01 |
| 01 | 57297 | 43012 | 14285 | 75.07 | 24.93 |
| 10 | 40524 | 32609 | 7915 | 80.47 | 19.53 |
| 11 | 186097 | 157529 | 28568 | 84.65 | 15.35 |

Unresolved branch depth

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 0 | 58928 | 40315 | 18613 | 68.41 | 31.59 |
| 1 | 270403 | 221879 | 48524 | 82.05 | 17.95 |
| 2 | 44446 | 38341 | 6105 | 86.26 | 13.74 |
| 3 | 2 | 2 | 0 | 100.00 | 0.00 |

### Stage 7

All disagreement cases

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| all | 321565 | 250802 | 70763 | 77.99 | 22.01 |

SGF PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 142685 | 119498 | 23187 | 83.75 | 16.25 |
| 01 | 33958 | 21583 | 12375 | 63.56 | 36.44 |
| 10 | 32690 | 16325 | 16365 | 49.94 | 50.06 |
| 11 | 112232 | 93396 | 18836 | 83.22 | 16.78 |

Committed-history shadow PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 87979 | 65771 | 22208 | 74.76 | 25.24 |
| 01 | 56943 | 43950 | 12993 | 77.18 | 22.82 |
| 10 | 39892 | 31668 | 8224 | 79.38 | 20.62 |
| 11 | 136751 | 109413 | 27338 | 80.01 | 19.99 |

Unresolved branch depth

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 0 | 74707 | 51194 | 23513 | 68.53 | 31.47 |
| 1 | 202549 | 161404 | 41145 | 79.69 | 20.31 |
| 2 | 44309 | 38204 | 6105 | 86.22 | 13.78 |
| 3 | 0 | 0 | 0 | — | — |

### Stage 8

All disagreement cases

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| all | 452894 | 368894 | 84000 | 81.45 | 18.55 |

SGF PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 211861 | 182070 | 29791 | 85.94 | 14.06 |
| 01 | 39481 | 25794 | 13687 | 65.33 | 34.67 |
| 10 | 34661 | 16960 | 17701 | 48.93 | 51.07 |
| 11 | 166891 | 144070 | 22821 | 86.33 | 13.67 |

Committed-history shadow PHT counter

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 00 | 100511 | 75931 | 24580 | 75.54 | 24.46 |
| 01 | 101041 | 85099 | 15942 | 84.22 | 15.78 |
| 10 | 42302 | 32970 | 9332 | 77.94 | 22.06 |
| 11 | 209040 | 174894 | 34146 | 83.67 | 16.33 |

Unresolved branch depth

| Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- |
| 0 | 92743 | 64495 | 28248 | 69.54 | 30.46 |
| 1 | 316509 | 266745 | 49764 | 84.28 | 15.72 |
| 2 | 43642 | 37654 | 5988 | 86.28 | 13.72 |
| 3 | 0 | 0 | 0 | — | — |

## Hamming-distance and bit-count availability

This availability applies to every benchmark and stage. The CSV includes each scope separately. Unknown-distance aggregate rows must not be counted as additional cases.

| Group | Cases / winner counts |
| --- | --- |
| Hamming distance 0 / same history | 0 / 0 / 0; percentages undefined |
| Hamming distances 1, 2, 3, 4, 5, 6 | Unavailable |
| One-bit difference | Unavailable |
| Multiple-bit difference | Unavailable |
| Nonzero distance, exact distance unknown | All measured disagreement cases |

## Per-benchmark tables

Pooled per-benchmark counter/depth tables are also in the CSV with stage=ALL. Below, each stage is retained.

### aha-mont64

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 239106 | 207354 | 31752 | 86.72 | 13.28 |
| 6 | all | 79388 | 68961 | 10427 | 86.87 | 13.13 |
| 7 | all | 79388 | 68961 | 10427 | 86.87 | 13.13 |
| 8 | all | 80330 | 69432 | 10898 | 86.43 | 13.57 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 28840 | 26472 | 2368 | 91.79 | 8.21 |
| 6 | 01 | 5679 | 3313 | 2366 | 58.34 | 41.66 |
| 6 | 10 | 4273 | 1900 | 2373 | 44.47 | 55.53 |
| 6 | 11 | 40596 | 37276 | 3320 | 91.82 | 8.18 |
| 7 | 00 | 28840 | 26472 | 2368 | 91.79 | 8.21 |
| 7 | 01 | 5679 | 3313 | 2366 | 58.34 | 41.66 |
| 7 | 10 | 4273 | 1900 | 2373 | 44.47 | 55.53 |
| 7 | 11 | 40596 | 37276 | 3320 | 91.82 | 8.18 |
| 8 | 00 | 28840 | 26472 | 2368 | 91.79 | 8.21 |
| 8 | 01 | 5206 | 2840 | 2366 | 54.55 | 45.45 |
| 8 | 10 | 4743 | 1899 | 2844 | 40.04 | 59.96 |
| 8 | 11 | 41541 | 38221 | 3320 | 92.01 | 7.99 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 38213 | 33004 | 5209 | 86.37 | 13.63 |
| 6 | 01 | 6656 | 6172 | 484 | 92.73 | 7.27 |
| 6 | 10 | 8071 | 7122 | 949 | 88.24 | 11.76 |
| 6 | 11 | 26448 | 22663 | 3785 | 85.69 | 14.31 |
| 7 | 00 | 38213 | 33004 | 5209 | 86.37 | 13.63 |
| 7 | 01 | 6656 | 6172 | 484 | 92.73 | 7.27 |
| 7 | 10 | 8071 | 7122 | 949 | 88.24 | 11.76 |
| 7 | 11 | 26448 | 22663 | 3785 | 85.69 | 14.31 |
| 8 | 00 | 39628 | 33948 | 5680 | 85.67 | 14.33 |
| 8 | 01 | 6656 | 6172 | 484 | 92.73 | 7.27 |
| 8 | 10 | 8070 | 7121 | 949 | 88.24 | 11.76 |
| 8 | 11 | 25976 | 22191 | 3785 | 85.43 | 14.57 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 15165 | 6632 | 8533 | 43.73 | 56.27 |
| 6 | 1 | 64223 | 62329 | 1894 | 97.05 | 2.95 |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 15165 | 6632 | 8533 | 43.73 | 56.27 |
| 7 | 1 | 64223 | 62329 | 1894 | 97.05 | 2.95 |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 15165 | 6632 | 8533 | 43.73 | 56.27 |
| 8 | 1 | 65165 | 62800 | 2365 | 96.37 | 3.63 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### bench_branch_heavy

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 1392 | 805 | 587 | 57.83 | 42.17 |
| 6 | all | 555 | 357 | 198 | 64.32 | 35.68 |
| 7 | all | 420 | 226 | 194 | 53.81 | 46.19 |
| 8 | all | 417 | 222 | 195 | 53.24 | 46.76 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 186 | 162 | 24 | 87.10 | 12.90 |
| 6 | 01 | 72 | 43 | 29 | 59.72 | 40.28 |
| 6 | 10 | 115 | 68 | 47 | 59.13 | 40.87 |
| 6 | 11 | 182 | 84 | 98 | 46.15 | 53.85 |
| 7 | 00 | 58 | 30 | 28 | 51.72 | 48.28 |
| 7 | 01 | 66 | 35 | 31 | 53.03 | 46.97 |
| 7 | 10 | 125 | 79 | 46 | 63.20 | 36.80 |
| 7 | 11 | 171 | 82 | 89 | 47.95 | 52.05 |
| 8 | 00 | 73 | 32 | 41 | 43.84 | 56.16 |
| 8 | 01 | 77 | 37 | 40 | 48.05 | 51.95 |
| 8 | 10 | 105 | 67 | 38 | 63.81 | 36.19 |
| 8 | 11 | 162 | 86 | 76 | 53.09 | 46.91 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 180 | 88 | 92 | 48.89 | 51.11 |
| 6 | 01 | 117 | 64 | 53 | 54.70 | 45.30 |
| 6 | 10 | 80 | 65 | 15 | 81.25 | 18.75 |
| 6 | 11 | 178 | 140 | 38 | 78.65 | 21.35 |
| 7 | 00 | 166 | 92 | 74 | 55.42 | 44.58 |
| 7 | 01 | 130 | 69 | 61 | 53.08 | 46.92 |
| 7 | 10 | 21 | 10 | 11 | 47.62 | 52.38 |
| 7 | 11 | 103 | 55 | 48 | 53.40 | 46.60 |
| 8 | 00 | 176 | 100 | 76 | 56.82 | 43.18 |
| 8 | 01 | 91 | 53 | 38 | 58.24 | 41.76 |
| 8 | 10 | 43 | 22 | 21 | 51.16 | 48.84 |
| 8 | 11 | 107 | 47 | 60 | 43.93 | 56.07 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 69 | 22 | 47 | 31.88 | 68.12 |
| 6 | 1 | 486 | 335 | 151 | 68.93 | 31.07 |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 82 | 34 | 48 | 41.46 | 58.54 |
| 7 | 1 | 338 | 192 | 146 | 56.80 | 43.20 |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 82 | 33 | 49 | 40.24 | 59.76 |
| 8 | 1 | 335 | 189 | 146 | 56.42 | 43.58 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### coremark

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 223659 | 194893 | 28766 | 87.14 | 12.86 |
| 6 | all | 95922 | 86911 | 9011 | 90.61 | 9.39 |
| 7 | all | 45845 | 36877 | 8968 | 80.44 | 19.56 |
| 8 | all | 81892 | 71105 | 10787 | 86.83 | 13.17 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 79957 | 74171 | 5786 | 92.76 | 7.24 |
| 6 | 01 | 6985 | 6281 | 704 | 89.92 | 10.08 |
| 6 | 10 | 2662 | 1807 | 855 | 67.88 | 32.12 |
| 6 | 11 | 6318 | 4652 | 1666 | 73.63 | 26.37 |
| 7 | 00 | 30012 | 24324 | 5688 | 81.05 | 18.95 |
| 7 | 01 | 6788 | 6084 | 704 | 89.63 | 10.37 |
| 7 | 10 | 2670 | 1798 | 872 | 67.34 | 32.66 |
| 7 | 11 | 6375 | 4671 | 1704 | 73.27 | 26.73 |
| 8 | 00 | 28335 | 22467 | 5868 | 79.29 | 20.71 |
| 8 | 01 | 7386 | 6588 | 798 | 89.20 | 10.80 |
| 8 | 10 | 2143 | 1159 | 984 | 54.08 | 45.92 |
| 8 | 11 | 44028 | 40891 | 3137 | 92.87 | 7.13 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 6114 | 4355 | 1759 | 71.23 | 28.77 |
| 6 | 01 | 2866 | 2104 | 762 | 73.41 | 26.59 |
| 6 | 10 | 8575 | 7794 | 781 | 90.89 | 9.11 |
| 6 | 11 | 78367 | 72658 | 5709 | 92.72 | 7.28 |
| 7 | 00 | 6162 | 4357 | 1805 | 70.71 | 29.29 |
| 7 | 01 | 2883 | 2112 | 771 | 73.26 | 26.74 |
| 7 | 10 | 6185 | 5444 | 741 | 88.02 | 11.98 |
| 7 | 11 | 30615 | 24964 | 5651 | 81.54 | 18.46 |
| 8 | 00 | 7824 | 5804 | 2020 | 74.18 | 25.82 |
| 8 | 01 | 38347 | 36246 | 2101 | 94.52 | 5.48 |
| 8 | 10 | 6196 | 5325 | 871 | 85.94 | 14.06 |
| 8 | 11 | 29525 | 23730 | 5795 | 80.37 | 19.63 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 3230 | 2042 | 1188 | 63.22 | 36.78 |
| 6 | 1 | 64738 | 62221 | 2517 | 96.11 | 3.89 |
| 6 | 2 | 27952 | 22646 | 5306 | 81.02 | 18.98 |
| 6 | 3 | 2 | 2 | 0 | 100.00 | 0.00 |
| 7 | 0 | 5771 | 4493 | 1278 | 77.85 | 22.15 |
| 7 | 1 | 12259 | 9875 | 2384 | 80.55 | 19.45 |
| 7 | 2 | 27815 | 22509 | 5306 | 80.92 | 19.08 |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 4593 | 2999 | 1594 | 65.30 | 34.70 |
| 8 | 1 | 49456 | 45547 | 3909 | 92.10 | 7.90 |
| 8 | 2 | 27843 | 22559 | 5284 | 81.02 | 18.98 |
| 8 | 3 | 0 | 0 | 0 | — | — |


### crc32

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 1360 | 1356 | 4 | 99.71 | 0.29 |
| 6 | all | 0 | 0 | 0 | — | — |
| 7 | all | 0 | 0 | 0 | — | — |
| 8 | all | 1360 | 1356 | 4 | 99.71 | 0.29 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 0 | 0 | 0 | — | — |
| 6 | 10 | 0 | 0 | 0 | — | — |
| 6 | 11 | 0 | 0 | 0 | — | — |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 0 | 0 | 0 | — | — |
| 7 | 10 | 0 | 0 | 0 | — | — |
| 7 | 11 | 0 | 0 | 0 | — | — |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 3 | 0 | 3 | 0.00 | 100.00 |
| 8 | 10 | 3 | 3 | 0 | 100.00 | 0.00 |
| 8 | 11 | 1354 | 1353 | 1 | 99.93 | 0.07 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 0 | 0 | 0 | — | — |
| 6 | 10 | 0 | 0 | 0 | — | — |
| 6 | 11 | 0 | 0 | 0 | — | — |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 0 | 0 | 0 | — | — |
| 7 | 10 | 0 | 0 | 0 | — | — |
| 7 | 11 | 0 | 0 | 0 | — | — |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 1357 | 1356 | 1 | 99.93 | 0.07 |
| 8 | 10 | 3 | 0 | 3 | 0.00 | 100.00 |
| 8 | 11 | 0 | 0 | 0 | — | — |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 0 | 0 | 0 | — | — |
| 6 | 1 | 0 | 0 | 0 | — | — |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 0 | 0 | 0 | — | — |
| 7 | 1 | 0 | 0 | 0 | — | — |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 1360 | 1356 | 4 | 99.71 | 0.29 |
| 8 | 1 | 0 | 0 | 0 | — | — |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### edn

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 15 | 0 | 15 | 0.00 | 100.00 |
| 6 | all | 5 | 0 | 5 | 0.00 | 100.00 |
| 7 | all | 5 | 0 | 5 | 0.00 | 100.00 |
| 8 | all | 5 | 0 | 5 | 0.00 | 100.00 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 5 | 0 | 5 | 0.00 | 100.00 |
| 6 | 10 | 0 | 0 | 0 | — | — |
| 6 | 11 | 0 | 0 | 0 | — | — |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 5 | 0 | 5 | 0.00 | 100.00 |
| 7 | 10 | 0 | 0 | 0 | — | — |
| 7 | 11 | 0 | 0 | 0 | — | — |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 5 | 0 | 5 | 0.00 | 100.00 |
| 8 | 10 | 0 | 0 | 0 | — | — |
| 8 | 11 | 0 | 0 | 0 | — | — |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 0 | 0 | 0 | — | — |
| 6 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 6 | 11 | 4 | 0 | 4 | 0.00 | 100.00 |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 0 | 0 | 0 | — | — |
| 7 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 7 | 11 | 4 | 0 | 4 | 0.00 | 100.00 |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 0 | 0 | 0 | — | — |
| 8 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 8 | 11 | 4 | 0 | 4 | 0.00 | 100.00 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 2 | 0 | 2 | 0.00 | 100.00 |
| 6 | 1 | 3 | 0 | 3 | 0.00 | 100.00 |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 2 | 0 | 2 | 0.00 | 100.00 |
| 7 | 1 | 3 | 0 | 3 | 0.00 | 100.00 |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 2 | 0 | 2 | 0.00 | 100.00 |
| 8 | 1 | 3 | 0 | 3 | 0.00 | 100.00 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### huffbench

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 263361 | 198848 | 64513 | 75.50 | 24.50 |
| 6 | all | 64518 | 44229 | 20289 | 68.55 | 31.45 |
| 7 | all | 64515 | 44272 | 20243 | 68.62 | 31.38 |
| 8 | all | 134328 | 110347 | 23981 | 82.15 | 17.85 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 38610 | 34007 | 4603 | 88.08 | 11.92 |
| 6 | 01 | 4794 | 3699 | 1095 | 77.16 | 22.84 |
| 6 | 10 | 9552 | 1932 | 7620 | 20.23 | 79.77 |
| 6 | 11 | 11562 | 4591 | 6971 | 39.71 | 60.29 |
| 7 | 00 | 38575 | 34007 | 4568 | 88.16 | 11.84 |
| 7 | 01 | 4783 | 3699 | 1084 | 77.34 | 22.66 |
| 7 | 10 | 9551 | 1931 | 7620 | 20.22 | 79.78 |
| 7 | 11 | 11606 | 4635 | 6971 | 39.94 | 60.06 |
| 8 | 00 | 104589 | 96937 | 7652 | 92.68 | 7.32 |
| 8 | 01 | 8382 | 7401 | 981 | 88.30 | 11.70 |
| 8 | 10 | 9981 | 1962 | 8019 | 19.66 | 80.34 |
| 8 | 11 | 11376 | 4047 | 7329 | 35.57 | 64.43 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 9860 | 2873 | 6987 | 29.14 | 70.86 |
| 6 | 01 | 11254 | 3650 | 7604 | 32.43 | 67.57 |
| 6 | 10 | 8763 | 7203 | 1560 | 82.20 | 17.80 |
| 6 | 11 | 34641 | 30503 | 4138 | 88.05 | 11.95 |
| 7 | 00 | 9896 | 2909 | 6987 | 29.40 | 70.60 |
| 7 | 01 | 11261 | 3657 | 7604 | 32.47 | 67.53 |
| 7 | 10 | 8755 | 7203 | 1552 | 82.27 | 17.73 |
| 7 | 11 | 34603 | 30503 | 4100 | 88.15 | 11.85 |
| 8 | 00 | 10566 | 2982 | 7584 | 28.22 | 71.78 |
| 8 | 01 | 10791 | 3027 | 7764 | 28.05 | 71.95 |
| 8 | 10 | 10599 | 9100 | 1499 | 85.86 | 14.14 |
| 8 | 11 | 102372 | 95238 | 7134 | 93.03 | 6.97 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 1135 | 892 | 243 | 78.59 | 21.41 |
| 6 | 1 | 46921 | 27642 | 19279 | 58.91 | 41.09 |
| 6 | 2 | 16462 | 15695 | 767 | 95.34 | 4.66 |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 1196 | 946 | 250 | 79.10 | 20.90 |
| 7 | 1 | 46857 | 27631 | 19226 | 58.97 | 41.03 |
| 7 | 2 | 16462 | 15695 | 767 | 95.34 | 4.66 |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 1023 | 680 | 343 | 66.47 | 33.53 |
| 8 | 1 | 117506 | 94572 | 22934 | 80.48 | 19.52 |
| 8 | 2 | 15799 | 15095 | 704 | 95.54 | 4.46 |
| 8 | 3 | 0 | 0 | 0 | — | — |


### matmult-int

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 132 | 120 | 12 | 90.91 | 9.09 |
| 6 | all | 44 | 40 | 4 | 90.91 | 9.09 |
| 7 | all | 44 | 40 | 4 | 90.91 | 9.09 |
| 8 | all | 44 | 40 | 4 | 90.91 | 9.09 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 4 | 0 | 4 | 0.00 | 100.00 |
| 6 | 10 | 0 | 0 | 0 | — | — |
| 6 | 11 | 40 | 40 | 0 | 100.00 | 0.00 |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 4 | 0 | 4 | 0.00 | 100.00 |
| 7 | 10 | 0 | 0 | 0 | — | — |
| 7 | 11 | 40 | 40 | 0 | 100.00 | 0.00 |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 4 | 0 | 4 | 0.00 | 100.00 |
| 8 | 10 | 0 | 0 | 0 | — | — |
| 8 | 11 | 40 | 40 | 0 | 100.00 | 0.00 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 0 | 0 | 0 | — | — |
| 6 | 01 | 40 | 40 | 0 | 100.00 | 0.00 |
| 6 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 6 | 11 | 3 | 0 | 3 | 0.00 | 100.00 |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 40 | 40 | 0 | 100.00 | 0.00 |
| 7 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 7 | 11 | 3 | 0 | 3 | 0.00 | 100.00 |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 40 | 40 | 0 | 100.00 | 0.00 |
| 8 | 10 | 1 | 0 | 1 | 0.00 | 100.00 |
| 8 | 11 | 3 | 0 | 3 | 0.00 | 100.00 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 44 | 40 | 4 | 90.91 | 9.09 |
| 6 | 1 | 0 | 0 | 0 | — | — |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 44 | 40 | 4 | 90.91 | 9.09 |
| 7 | 1 | 0 | 0 | 0 | — | — |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 44 | 40 | 4 | 90.91 | 9.09 |
| 8 | 1 | 0 | 0 | 0 | — | — |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### nettle-aes

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 47140 | 42691 | 4449 | 90.56 | 9.44 |
| 6 | all | 11272 | 10078 | 1194 | 89.41 | 10.59 |
| 7 | all | 13118 | 12097 | 1021 | 92.22 | 7.78 |
| 8 | all | 22750 | 20516 | 2234 | 90.18 | 9.82 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 1934 | 1850 | 84 | 95.66 | 4.34 |
| 6 | 01 | 687 | 520 | 167 | 75.69 | 24.31 |
| 6 | 10 | 1135 | 1116 | 19 | 98.33 | 1.67 |
| 6 | 11 | 7516 | 6592 | 924 | 87.71 | 12.29 |
| 7 | 00 | 78 | 74 | 4 | 94.87 | 5.13 |
| 7 | 01 | 80 | 0 | 80 | 0.00 | 100.00 |
| 7 | 10 | 3894 | 3817 | 77 | 98.02 | 1.98 |
| 7 | 11 | 9066 | 8206 | 860 | 90.51 | 9.49 |
| 8 | 00 | 78 | 74 | 4 | 94.87 | 5.13 |
| 8 | 01 | 78 | 0 | 78 | 0.00 | 100.00 |
| 8 | 10 | 2935 | 2858 | 77 | 97.38 | 2.62 |
| 8 | 11 | 19659 | 17584 | 2075 | 89.45 | 10.55 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 3232 | 3221 | 11 | 99.66 | 0.34 |
| 6 | 01 | 5419 | 4487 | 932 | 82.80 | 17.20 |
| 6 | 10 | 163 | 75 | 88 | 46.01 | 53.99 |
| 6 | 11 | 2458 | 2295 | 163 | 93.37 | 6.63 |
| 7 | 00 | 3292 | 3292 | 0 | 100.00 | 0.00 |
| 7 | 01 | 9668 | 8731 | 937 | 90.31 | 9.69 |
| 7 | 10 | 2 | 0 | 2 | 0.00 | 100.00 |
| 7 | 11 | 156 | 74 | 82 | 47.44 | 52.56 |
| 8 | 00 | 3277 | 3277 | 0 | 100.00 | 0.00 |
| 8 | 01 | 19317 | 17165 | 2152 | 88.86 | 11.14 |
| 8 | 10 | 0 | 0 | 0 | — | — |
| 8 | 11 | 156 | 74 | 82 | 47.44 | 52.56 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 5498 | 5231 | 267 | 95.14 | 4.86 |
| 6 | 1 | 5774 | 4847 | 927 | 83.95 | 16.05 |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 6598 | 6493 | 105 | 98.41 | 1.59 |
| 7 | 1 | 6520 | 5604 | 916 | 85.95 | 14.05 |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 16233 | 14914 | 1319 | 91.87 | 8.13 |
| 8 | 1 | 6517 | 5602 | 915 | 85.96 | 14.04 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### sglib-combined

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 325454 | 230898 | 94556 | 70.95 | 29.05 |
| 6 | all | 102094 | 73321 | 28773 | 71.82 | 28.18 |
| 7 | all | 104911 | 75015 | 29896 | 71.50 | 28.50 |
| 8 | all | 118449 | 82562 | 35887 | 69.70 | 30.30 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 41762 | 32416 | 9346 | 77.62 | 22.38 |
| 6 | 01 | 13765 | 7204 | 6561 | 52.34 | 47.66 |
| 6 | 10 | 12107 | 6828 | 5279 | 56.40 | 43.60 |
| 6 | 11 | 34460 | 26873 | 7587 | 77.98 | 22.02 |
| 7 | 00 | 45122 | 34591 | 10531 | 76.66 | 23.34 |
| 7 | 01 | 16548 | 8452 | 8096 | 51.08 | 48.92 |
| 7 | 10 | 12172 | 6795 | 5377 | 55.82 | 44.18 |
| 7 | 11 | 31069 | 25177 | 5892 | 81.04 | 18.96 |
| 8 | 00 | 49946 | 36088 | 13858 | 72.25 | 27.75 |
| 8 | 01 | 18335 | 8928 | 9407 | 48.69 | 51.31 |
| 8 | 10 | 14746 | 9007 | 5739 | 61.08 | 38.92 |
| 8 | 11 | 35422 | 28539 | 6883 | 80.57 | 19.43 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 28937 | 20521 | 8416 | 70.92 | 29.08 |
| 6 | 01 | 17630 | 13180 | 4450 | 74.76 | 25.24 |
| 6 | 10 | 14868 | 10350 | 4518 | 69.61 | 30.39 |
| 6 | 11 | 40659 | 29270 | 11389 | 71.99 | 28.01 |
| 7 | 00 | 26924 | 18791 | 8133 | 69.79 | 30.21 |
| 7 | 01 | 16317 | 13181 | 3136 | 80.78 | 19.22 |
| 7 | 10 | 16856 | 11889 | 4967 | 70.53 | 29.47 |
| 7 | 11 | 44814 | 31154 | 13660 | 69.52 | 30.48 |
| 8 | 00 | 35714 | 26494 | 9220 | 74.18 | 25.82 |
| 8 | 01 | 14454 | 11052 | 3402 | 76.46 | 23.54 |
| 8 | 10 | 17389 | 11402 | 5987 | 65.57 | 34.43 |
| 8 | 11 | 50892 | 33614 | 17278 | 66.05 | 33.95 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 27126 | 18798 | 8328 | 69.30 | 30.70 |
| 6 | 1 | 74936 | 54523 | 20413 | 72.76 | 27.24 |
| 6 | 2 | 32 | 0 | 32 | 0.00 | 100.00 |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 35860 | 22572 | 13288 | 62.94 | 37.06 |
| 7 | 1 | 69019 | 52443 | 16576 | 75.98 | 24.02 |
| 7 | 2 | 32 | 0 | 32 | 0.00 | 100.00 |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 44252 | 27857 | 16395 | 62.95 | 37.05 |
| 8 | 1 | 74197 | 54705 | 19492 | 73.73 | 26.27 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |


### statemate

Total disagreements by stage

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | all | 46619 | 43268 | 3351 | 92.81 | 7.19 |
| 6 | all | 19981 | 16640 | 3341 | 83.28 | 16.72 |
| 7 | all | 13319 | 13314 | 5 | 99.96 | 0.04 |
| 8 | all | 13319 | 13314 | 5 | 99.96 | 0.04 |

SGF PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 2 | 0 | 2 | 0.00 | 100.00 |
| 6 | 01 | 3339 | 0 | 3339 | 0.00 | 100.00 |
| 6 | 10 | 6 | 6 | 0 | 100.00 | 0.00 |
| 6 | 11 | 16634 | 16634 | 0 | 100.00 | 0.00 |
| 7 | 00 | 0 | 0 | 0 | — | — |
| 7 | 01 | 5 | 0 | 5 | 0.00 | 100.00 |
| 7 | 10 | 5 | 5 | 0 | 100.00 | 0.00 |
| 7 | 11 | 13309 | 13309 | 0 | 100.00 | 0.00 |
| 8 | 00 | 0 | 0 | 0 | — | — |
| 8 | 01 | 5 | 0 | 5 | 0.00 | 100.00 |
| 8 | 10 | 5 | 5 | 0 | 100.00 | 0.00 |
| 8 | 11 | 13309 | 13309 | 0 | 100.00 | 0.00 |

Committed-history shadow PHT counter

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 00 | 3325 | 3325 | 0 | 100.00 | 0.00 |
| 6 | 01 | 13315 | 13315 | 0 | 100.00 | 0.00 |
| 6 | 10 | 2 | 0 | 2 | 0.00 | 100.00 |
| 6 | 11 | 3339 | 0 | 3339 | 0.00 | 100.00 |
| 7 | 00 | 3326 | 3326 | 0 | 100.00 | 0.00 |
| 7 | 01 | 9988 | 9988 | 0 | 100.00 | 0.00 |
| 7 | 10 | 0 | 0 | 0 | — | — |
| 7 | 11 | 5 | 0 | 5 | 0.00 | 100.00 |
| 8 | 00 | 3326 | 3326 | 0 | 100.00 | 0.00 |
| 8 | 01 | 9988 | 9988 | 0 | 100.00 | 0.00 |
| 8 | 10 | 0 | 0 | 0 | — | — |
| 8 | 11 | 5 | 0 | 5 | 0.00 | 100.00 |

Unresolved branch depth

| Stage | Group | Disagreements | SGF correct | Committed correct | SGF win % | Committed win % |
| --- | --- | --- | --- | --- | --- | --- |
| 6 | 0 | 6659 | 6658 | 1 | 99.98 | 0.02 |
| 6 | 1 | 13322 | 9982 | 3340 | 74.93 | 25.07 |
| 6 | 2 | 0 | 0 | 0 | — | — |
| 6 | 3 | 0 | 0 | 0 | — | — |
| 7 | 0 | 9989 | 9984 | 5 | 99.95 | 0.05 |
| 7 | 1 | 3330 | 3330 | 0 | 100.00 | 0.00 |
| 7 | 2 | 0 | 0 | 0 | — | — |
| 7 | 3 | 0 | 0 | 0 | — | — |
| 8 | 0 | 9989 | 9984 | 5 | 99.95 | 0.05 |
| 8 | 1 | 3330 | 3330 | 0 | 100.00 | 0.00 |
| 8 | 2 | 0 | 0 | 0 | — | — |
| 8 | 3 | 0 | 0 | 0 | — | — |

## Workload consistency

Only benchmark groups with at least 100 disagreement cases are included in this diagnostic. This support filter is not a significance test. A pooled majority is not a reliable selector if it reverses across workloads.

| Stage | Group | Supported benchmarks | SGF-majority | Committed-majority | Ties | SGF win % range |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | sgf_pht_counter:00 | 6 | 6 | 0 | 0 | 70.66–95.60 |
| ALL | sgf_pht_counter:01 | 7 | 6 | 1 | 0 | 0.00–89.57 |
| ALL | sgf_pht_counter:10 | 6 | 4 | 2 | 0 | 20.03–97.83 |
| ALL | sgf_pht_counter:11 | 9 | 7 | 2 | 0 | 38.42–100.00 |
| ALL | unresolved_branch_depth:0 | 9 | 7 | 2 | 0 | 38.20–99.96 |
| ALL | unresolved_branch_depth:1 | 7 | 7 | 0 | 0 | 61.78–96.82 |
| ALL | unresolved_branch_depth:2 | 2 | 2 | 0 | 0 | 80.99–95.41 |
| 6 | sgf_pht_counter:00 | 6 | 6 | 0 | 0 | 77.62–95.66 |
| 6 | sgf_pht_counter:01 | 6 | 5 | 1 | 0 | 0.00–89.92 |
| 6 | sgf_pht_counter:10 | 6 | 4 | 2 | 0 | 20.23–98.33 |
| 6 | sgf_pht_counter:11 | 7 | 5 | 2 | 0 | 39.71–100.00 |
| 6 | unresolved_branch_depth:0 | 6 | 5 | 1 | 0 | 43.73–99.98 |
| 6 | unresolved_branch_depth:1 | 7 | 7 | 0 | 0 | 58.91–97.05 |
| 6 | unresolved_branch_depth:2 | 2 | 2 | 0 | 0 | 81.02–95.34 |
| 7 | sgf_pht_counter:00 | 4 | 4 | 0 | 0 | 76.66–91.79 |
| 7 | sgf_pht_counter:01 | 4 | 4 | 0 | 0 | 51.08–89.63 |
| 7 | sgf_pht_counter:10 | 6 | 4 | 2 | 0 | 20.22–98.02 |
| 7 | sgf_pht_counter:11 | 7 | 5 | 2 | 0 | 39.94–100.00 |
| 7 | unresolved_branch_depth:0 | 6 | 5 | 1 | 0 | 43.73–99.95 |
| 7 | unresolved_branch_depth:1 | 7 | 7 | 0 | 0 | 56.80–100.00 |
| 7 | unresolved_branch_depth:2 | 2 | 2 | 0 | 0 | 80.92–95.34 |
| 8 | sgf_pht_counter:00 | 4 | 4 | 0 | 0 | 72.25–92.68 |
| 8 | sgf_pht_counter:01 | 4 | 3 | 1 | 0 | 48.69–89.20 |
| 8 | sgf_pht_counter:10 | 6 | 4 | 2 | 0 | 19.66–97.38 |
| 8 | sgf_pht_counter:11 | 8 | 7 | 1 | 0 | 35.57–100.00 |
| 8 | unresolved_branch_depth:0 | 7 | 6 | 1 | 0 | 43.73–99.95 |
| 8 | unresolved_branch_depth:1 | 7 | 7 | 0 | 0 | 56.42–100.00 |
| 8 | unresolved_branch_depth:2 | 2 | 2 | 0 | 0 | 81.02–95.54 |

## Fixed hardware-friendly rule checks

These are hand-specified descriptive checks, not trained models or validated proposals. Select committed history when the listed condition holds; otherwise select SGF. The net change measures additional correct predictions on this recorded trace only, not simulated speedup or a counterfactual retrained predictor. Improved/harmed counts are benchmark-stage pairs.

| Stage | Select committed when | Correct | Win % | Net correct vs SGF | Improved pairs | Harmed pairs |
| --- | --- | --- | --- | --- | --- | --- |
| ALL | never (always SGF) | 920233 | 80.14 | +0 | 0 | 0 |
| ALL | SGF counter = 10 | 923550 | 80.43 | +3317 | 6 | 16 |
| ALL | SGF counter weak (01 or 10) | 895445 | 77.98 | -24788 | 10 | 15 |
| ALL | depth = 0 | 834603 | 72.69 | -85630 | 9 | 19 |
| ALL | counter = 10 and depth = 0 | 918262 | 79.97 | -1971 | 10 | 12 |
| ALL | counter = 10 and depth = 1 | 924710 | 80.53 | +4477 | 4 | 15 |
| ALL | counter = 10 and depth >= 2 | 921044 | 80.21 | +811 | 3 | 0 |
| 6 | never (always SGF) | 300537 | 80.40 | +0 | 0 | 0 |
| 6 | SGF counter = 10 | 303073 | 81.08 | +2536 | 2 | 5 |
| 6 | SGF counter weak (01 or 10) | 296283 | 79.27 | -4254 | 4 | 5 |
| 6 | depth = 0 | 278835 | 74.60 | -21702 | 3 | 6 |
| 6 | counter = 10 and depth = 0 | 301448 | 80.65 | +911 | 4 | 3 |
| 6 | counter = 10 and depth = 1 | 301886 | 80.77 | +1349 | 1 | 5 |
| 6 | counter = 10 and depth >= 2 | 300813 | 80.48 | +276 | 1 | 0 |
| 7 | never (always SGF) | 250802 | 77.99 | +0 | 0 | 0 |
| 7 | SGF counter = 10 | 250842 | 78.01 | +40 | 2 | 5 |
| 7 | SGF counter weak (01 or 10) | 241634 | 75.14 | -9168 | 3 | 5 |
| 7 | depth = 0 | 223121 | 69.39 | -27681 | 3 | 6 |
| 7 | counter = 10 and depth = 0 | 249349 | 77.54 | -1453 | 3 | 4 |
| 7 | counter = 10 and depth = 1 | 252019 | 78.37 | +1217 | 1 | 5 |
| 7 | counter = 10 and depth >= 2 | 251078 | 78.08 | +276 | 1 | 0 |
| 8 | never (always SGF) | 368894 | 81.45 | +0 | 0 | 0 |
| 8 | SGF counter = 10 | 369635 | 81.62 | +741 | 2 | 6 |
| 8 | SGF counter weak (01 or 10) | 357528 | 78.94 | -11366 | 3 | 5 |
| 8 | depth = 0 | 332647 | 73.45 | -36247 | 3 | 7 |
| 8 | counter = 10 and depth = 0 | 367465 | 81.14 | -1429 | 3 | 5 |
| 8 | counter = 10 and depth = 1 | 370805 | 81.87 | +1911 | 2 | 5 |
| 8 | counter = 10 and depth >= 2 | 369153 | 81.51 | +259 | 1 | 0 |

## Interpretation

Across 1,148,238 disagreements, SGF wins 80.14% and committed history wins 19.86%.

Strong SGF counter states (00 and 11) strongly favor SGF in the pooled data. Weak 01 also favors SGF. Weak 10 marginally favors committed history overall, but the winner reverses across benchmarks and stages: huffbench favors committed history while CoreMark and nettle-aes favor SGF. A universal weak-counter fallback is therefore not justified.

Depth 0, 1, and 2 favor SGF overall; depth 3 has only two disagreements, too few for a reliable conclusion. The consistency and fixed-rule tables expose workload reversals and potential losses rather than treating pooled gains as proof of a reliable selector.

No Hamming-distance or one-bit selector can be assessed from this dataset. Confidence/depth predicates can be cheaply implemented in hardware in principle, but none is established here as a robust general selector. Independent workload validation and recorded history distances would be needed before proposing behavioral changes.

For disagreement cases an ideal outcome-aware selector is correct 100% of the time; its trace-only upper bound gains one correct prediction for every committed-history-only win relative to always SGF. This is not a realizable prediction-time rule and does not quantify a cycle-speedup bound.

CSV percentages use six decimals; Markdown percentages use two. Zero-case percentages are undefined. Existing characterization and evaluation outputs are unchanged.
