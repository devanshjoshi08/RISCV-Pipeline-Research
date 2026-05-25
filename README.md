# Speculative GHR Forwarding & a Controlled Pipeline-Depth Study on FPGA

This repository is the code-and-data supplement for the paper **"Speculative GHR
Forwarding: Eliminating Stale Branch-Predictor State in Deep FPGA Pipelines"**
(targeting **ACM Transactions on Reconfigurable Technology and Systems, TRETS**).
The write-up is in the ACM `acmart` format and split into the main paper
[`paper/main.tex`](paper/main.tex) and a companion
[`paper/supplement.tex`](paper/supplement.tex) holding the corroborating figures
and tables (area, power/efficiency, BRAM, published-cores, CoreMark detail, CPI
ablation, the inter-branch-distance and hazard tables, etc.). Both build against
the same [`paper/figures/`](paper/figures/) and [`paper/references.bib`](paper/references.bib).

The research asks a question prior work leaves open: **how does pipeline depth
alone affect performance on an FPGA, and what does it cost the branch
predictor?** We build five pipeline variants (4–8 stages) from *identical* RTL
for every functional unit, vary only the staging, synthesize all of them on a
Xilinx Artix-7 (Vivado 2025.2, 10 synthesis directive combinations = 50
post-place-and-route runs), and then propose and measure a fix for the one
correctable predictor effect the study isolates:

> **Speculative GHR Forwarding (SGF)** — a ROB-free realization of speculative
> branch history for an in-order FPGA soft core. SGF cuts 7-stage CoreMark
> mispredictions **31.4%** at **0.7% area** and **no frequency loss**.

This README is organized so a reviewer can **verify each code-backed claim from
the committed source, scripts, and result logs** without re-running the full
Vivado flow. Every number in the paper traces to a committed result log; the
[Claim-to-Code Map](#claim-to-code-map) below is the index.

**Authors:** Devansh Joshi and Shafin Ula (The University of Texas at Austin)

---

## Scope (what these results are bounded to)

The paper's claims are measured outcomes under **one FPGA family** (Artix-7
XC7A35T), **one toolchain** (Vivado 2025.2), **one in-order microarchitecture**,
the **gshare** predictor (with measured generalization to tournament and TAGE),
and **`-O1`** compilation — not fabric- or predictor-independent laws. Absolute frequency/area/power do not
transfer without re-synthesis; what transfers is the Mechanism-A/B decomposition
and the ROB-free dual-GHR construction. See `paper/main.tex` §Limitations.

## Requirements

- **Xilinx Vivado 2025.2** (XSim for cycle-accurate simulation; post-place-and-route
  for F_max/area). The simulations are deterministic and single-clock-domain.
- **riscv-none-elf-gcc 15.2.0** (xPack) — only needed to rebuild benchmark hex;
  prebuilt hex is committed under [`programs/`](programs/).
- **Python 3** with `matplotlib` (+ `numpy`) — only for regenerating figures.

CPU-only machines cannot re-run the Vivado flow, but **all result logs and the
figure-regeneration scripts are committed**, so every numeric claim stays
inspectable offline.

> **Portability / scratch directory.** No absolute machine paths are baked into
> the repo — every driver script resolves the repo root from its own location
> (`[info script]`) and writes Vivado projects and temporaries to a git-ignored
> `./.vivado_work/` by default. Set the **`RISCV_WORK`** environment variable to
> redirect that scratch to a faster or larger disk. Committed result logs record
> only the testbench filename (no drive letters), so they reproduce identically
> on any machine.

## Reproducing the paper evidence

Drive the experiments from the **Vivado Tcl console** (`source <script>`). All
driver scripts live in [`scripts/`](scripts/); the **committed result log that
backs each paper section lives in [`results/`](results/)**, named in the comments
below.

```tcl
# --- Synthesis: F_max + area, 10 directive combinations, all five depths ---
source scripts/synth_seeds.tcl          ;# -> results/seed_results.log   (two-tier F_max)
source scripts/synth_all.tcl            ;# -> results/synth_results.log  (area, DSP)
source scripts/synth_bram.tcl           ;# BRAM instr-memory variants -> results/bram_synth_results.log

# --- Baseline CPI / misprediction measurements (Mechanism A vs B) ---
source scripts/run_coremark.tcl         ;# -> results/coremark_official_results.log
source scripts/run_dhrystone.tcl        ;# -> results/dhrystone_results.log
source scripts/run_diagnostic.tcl       ;# -> results/diagnostic_results.log
source scripts/run_embench_official.tcl ;# -> results/embench_official_results.log

# --- Causal isolation of Mechanism B (the two controls) ---
source scripts/run_bimodal.tcl          ;# no-GHR control -> results/bimodal_results.log
source scripts/run_predictor_sweep.tcl  ;# 32..1024 PHT sweep -> results/predictor_sweep_results.log

# --- SGF and orthogonal techniques ---
source scripts/run_sgf_eval.tcl         ;# SGF 7/8-stage bench + synth
                                       ;#   -> results/sgf_benchmark_results.log, results/sgf_synth_results.log
source scripts/run_sgf_6stage.tcl      ;# SGF on the 6-stage (recommended depth)

# --- Generalization to other predictor families (measured, 7-stage) ---
source scripts/run_tournament_7stage.tcl ;# tournament -> results/tournament_results.log, tournament_synth_results.log
source scripts/run_tage_7stage.tcl       ;# downscaled TAGE -> results/tage_results.log, tage_synth_results.log

# --- Robustness and power ---
source scripts/run_O2_7stage.tcl       ;# -O2 recompilation, 7-stage -> results/o2_7stage_results.log
source scripts/run_saif_workload.tcl   ;# workload-specific (CoreMark) SAIF power, all depths
```

> **Note:** long benchmark simulations generate large XSim waveform temporaries.
> The scripts delete each project directory after scraping its result log so the
> disk doesn't fill; keep waveform logging off for multi-million-cycle runs.

Regenerate all figures from the committed data (no Vivado needed):

```bash
python scripts/generate_plots_5depth.py       # fmax, area, cpi, mispred, coremark_mhz, cpi_vs_depth (+ CPI-model fit)
python scripts/regen_throughput_published.py  # throughput, published-cores sanity check
python scripts/regen_power_figs.py            # power, efficiency (workload-SAIF)
python scripts/regen_bram_fig.py              # LUT- vs BRAM-memory F_max
```

## Claim-to-Code Map

Every code-backed claim in the paper, mapped to the source / script / committed log that supports it.

| Paper claim | Code / artifact |
|---|---|
| Two-tier F_max (70–74 vs 115–118 MHz, *p* < 0.001, *d* = 18.5); execute-stage split is the only knee | `scripts/synth_seeds.tcl`, `scripts/synth_all.tcl` → `results/seed_results.log`, `results/synth_results.log`; fig `scripts/regen_throughput_published.py` |
| 6-stage is throughput- and energy-optimal on this fabric (64.1 MIPS, lowest EDP) | CPI from `results/coremark_official_results.log` (4/5/6-stage) and `results/7s8s_rerun_results.log` (canonical 7/8-stage, fixed-hex) × F_max above; fig `scripts/regen_throughput_published.py` |
| Depth splits into Mechanism A (all workloads) + Mechanism B (CoreMark +5.7%, statemate +10%) | 4/5/6-stage: `results/coremark_official_results.log`, `results/embench_official_results.log`, `results/dhrystone_results.log`, `results/diagnostic_results.log`; **7/8-stage baseline: `results/7s8s_rerun_results.log`** (canonical 2,893,145-instr CoreMark; the 7/8-stage rows in `*_official_results.log` are a superseded pre-fixed-hex run) |
| Mechanism B **requires** a GHR (bimodal control: zero depth inflation, 85,493/63,272 at every depth) | `rtl/branch_predictor_bimodal.sv` → `results/bimodal_coremark_results.log` |
| Mechanism B is **not** PHT aliasing (32→1024 sweep, inflation persists) | `results/pht_sweep_coremark_results.log` |
| SGF: −31.4% CoreMark / −22.7% statemate, +0.7% area, no F_max loss | `rtl/branch_predictor_sgf.sv`, `rtl_7stage/rv32i_pipeline_7stage_sgf_top.sv` → `results/sgf_benchmark_results.log`, `results/sgf_synth_10seeds_results.log` (10-directive F_max) |
| SGF on the 6-stage (−23.9% CoreMark) | `rtl/rv32i_pipeline_sgf_top.sv`, `scripts/run_sgf_6stage.tcl` → `results/sgf_6stage_results.log` |
| Analytical CPI model R² = 0.977, R²_CV = 0.941 (LOWO) | `scripts/generate_plots_5depth.py` (fit + `cpi_vs_depth`); inputs are the benchmark logs above |
| Workload-SAIF power *falls* with depth (0.235→0.217 W, opposite to uniform-toggle) | `scripts/run_saif_workload.tcl` → `results/saif_workload_results.log`; fig `scripts/regen_power_figs.py` |
| SGF benefit survives `-O2` (CoreMark −43.6%, statemate −12.0%; IBD stays < 10) | `scripts/build_O2_benchmarks.sh`, `scripts/run_O2_7stage.tcl` → `results/o2_7stage_results.log` |
| SGF generalizes to a 2nd predictor family: tournament (CoreMark −3.1%, statemate −10.5%, every workload down), +0.6% LUT / +0.5% FF, no F_max loss | `rtl/branch_predictor_tournament.sv`, `rtl/branch_predictor_tournament_sgf.sv`, `rtl_7stage/rv32i_pipeline_7stage_tournament{,_sgf}_top.sv`, `scripts/run_tournament_7stage.tcl` → `results/tournament_results.log`, `results/tournament_synth_results.log` |
| SGF on a 3rd family: TAGE (CoreMark −31.1%, statemate −11.1%; aha-mont64 +5.0% CPI-neutral edge case) — benefit generalizes but cost is +21% LUTs (multi-table), and the gshare confidence filter backfires here | `rtl/branch_predictor_tage.sv`, `rtl/branch_predictor_tage_sgf.sv`, `rtl_7stage/rv32i_pipeline_7stage_tage{,_sgf}_top.sv`, `scripts/run_tage_7stage.tcl` → `results/tage_results.log`, `results/tage_synth_results.log`, `results/tage_filtered_results.log` (confidence-filter variant) |
| BRAM instr-memory lets 7/8-stage near-match 6-stage F_max | `rtl/rv32i_pipeline_bram_top.sv`, `rtl_7stage/rv32i_pipeline_7stage_bram_top.sv`, `scripts/synth_bram.tcl` → `results/bram_synth_results.log`; fig `scripts/regen_bram_fig.py` |
| Determinism: identical instruction/branch counts + memory checksums across all depths | every benchmark log above; `tb/rv32i_benchmark_tb.sv`, `tb/rv32i_riscv_tests_tb.sv` |
| Functional correctness (37 riscv-tests + 24-point bench) | `tb/rv32i_riscv_tests_tb.sv`, `tb/rv32i_comprehensive_tb.sv`, `scripts/run_all_tests.tcl` → `results/test_results.log` |

## The processor (research vehicle)

A pipelined **RV32IM** core in SystemVerilog: all 40 RV32I + 8 RV32M
instructions, M-mode CSRs / trap handling / MRET, a **gshare** predictor
(64-entry PHT, 6-bit GHR) with a 32-entry BTB and 4-entry RAS, a direct-mapped
I-cache, 3-source forwarding, and 64-bit performance counters. Validated against
the 37-test **riscv-tests** suite and a 24-point comprehensive testbench; the
6-stage variant has been deployed on a Basys 3 at 100 MHz. Predictor and all
functional units are held constant across depths — only the pipeline staging
changes. Each split carries structural side effects (load-use stall, IF2 bubble,
forwarding-source count); the paper makes these explicit and decomposes them in
the CPI model rather than claiming depth varies in complete isolation.

### Pipeline variants

| Variant | Stages | Notes |
|---|---|---|
| 4-stage | IF, ID, EX, MEM/WB | merged MEM/WB (no load-use stall), longest critical path |
| 5-stage | IF, ID, EX, MEM, WB | classic RISC |
| **6-stage** | IF, ID, EX1, EX2, MEM, WB | execute split → +56% F_max; **throughput-optimal** |
| 7-stage | IF1, IF2, ID, EX1, EX2, MEM, WB | fetch split (registered PC); 1-cycle IF2 bubble |
| 8-stage | IF1, IF2, ID, EX1, EX2, MEM1, MEM2, WB | memory split |

Variant tops with the contribution applied: **SGF** (`*_sgf_top.sv`). (The repo
also retains exploratory next-line-predictor tops, `*_nlp_top.sv`, which the paper
does not use: on this fabric the next-line predictor's IF1 redirect lowers
frequency below the deep tier, a net throughput loss.)

## Synthesis results (Artix-7 XC7A35T, 10-directive mean)

| Metric | 4-stg | 5-stg | 6-stg | 7-stg | 8-stg |
|---|---|---|---|---|---|
| F_max (MHz) | 70.4 | 74.0 | **117.3** | 115.0 | 117.5 |
| Slice LUTs | 7,219 | 7,429 | 7,631 | 7,766 | 7,841 |
| Slice Regs | 8,040 | 8,190 | 8,501 | 8,550 | 8,678 |
| CoreMark CPI | 1.54 | 1.63 | 1.83 | 2.02 | 2.18 |
| CoreMark MIPS | 45.7 | 45.4 | **64.1** | 56.9 | 53.9 |

SGF on the 7-stage: +49 LUT (+0.6%), +57 FF (+0.7%), F_max 117.5 vs 115.0 MHz
(no degradation). SGF ships **without** a confidence filter — we measured one
that fixes a zero-CPI crc32 edge case but costs ~11 points of the CoreMark
benefit, so it is off by default and retained only as a build option (see the
paper's crc32 / confidence-filter section).

## Benchmarks

Seven workloads, all `-O1`, bare-metal: **CoreMark** (EEMBC), **Dhrystone 2.1**,
a mixed **Diagnostic** program, and four **Embench-IoT** kernels (aha-mont64,
crc32, statemate, edn). Sources and prebuilt hex are under
[`programs/`](programs/) (`asm/`, `c/`, `coremark/`, `embench/`). Each reads the
hardware counters before/after and stores results to data memory for testbench
readout.

## Repository layout

```
paper/
  main.tex                 main paper (acmart / ACM TRETS format)
  supplement.tex           supplementary material (corroborating figures + tables)
  references.bib           bibliography
  figures/                 all figures (.png + .pdf)
rtl/                       shared functional units + 6-stage baseline + SGF/bimodal/BRAM tops
  branch_predictor.sv          gshare + BTB + RAS (baseline)
  branch_predictor_sgf.sv      dual-GHR speculative-forwarding predictor (SGF)
  branch_predictor_bimodal.sv  no-GHR control predictor (causal isolation)
  rv32i_pipeline_top.sv        6-stage baseline      rv32i_pipeline_sgf_top.sv  6-stage SGF
  alu / mdu / csr_unit / regfile / imm_gen / control / icache / imem / dmem / ...
rtl_4stage/ rtl_5stage/    depth-specific tops + forwarding/hazard units
rtl_7stage/                7-stage baseline, SGF, NLP, SGF+NLP, BRAM tops + pipe_if1_if2
rtl_8stage/                8-stage tops (incl. pipe_mem1_mem2)
tb/                        single-cycle, pipeline, comprehensive, riscv-tests benches
programs/                  asm/ , c/ , coremark/ , embench/  (sources + hex)
scripts/                   ALL driver TCL (synthesis, baseline, causal, SGF, tournament,
                           TAGE, -O2, power) + regen_*.py figure scripts + synth .xdc
  _synth_rtl/              flat RTL snapshot used by the synthesis/baseline harness
results/                   ALL result logs (every paper number traces to one of these)
constraints/               Basys 3 XDC
tools/                     hex disassembler, riscv-tests runner
```

## License

The original work in this repository — the RV32IM RTL, testbenches, driver and
figure scripts, result logs, constraints, and paper sources — is released under
the **MIT License** (see [`LICENSE`](LICENSE)).

The benchmark programs under [`programs/`](programs/) are **not** covered by MIT;
each retains its upstream license (CoreMark — EEMBC, Apache-2.0; Embench-IoT;
Dhrystone 2.1 — public domain). Only our bare-metal porting layer, linker
scripts, and derived `.hex` images are MIT-licensed. See [`NOTICE`](NOTICE) for
details.

If you use this work, please cite the paper (Joshi and Ula, "Speculative GHR
Forwarding: Eliminating Stale Branch-Predictor State in Deep FPGA Pipelines").

