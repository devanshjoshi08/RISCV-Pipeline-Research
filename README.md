# Speculative GHR Forwarding & a Controlled Pipeline-Depth Study on FPGA

This repository is the code-and-data supplement for the paper **"Speculative GHR
Forwarding: Eliminating Stale Branch-Predictor State in Deep FPGA Pipelines"**
(targeting IEEE Transactions on Computers). The full write-up is in
[`paper/main.tex`](paper/main.tex).

The research asks a question prior work leaves open: **how does pipeline depth
alone affect performance on an FPGA, and what does it cost the branch
predictor?** We build five pipeline variants (4–8 stages) from *identical* RTL
for every functional unit, vary only the staging, synthesize all of them on a
Xilinx Artix-7 (Vivado 2025.2, 10 placement seeds), and then propose and measure
a fix for the one correctable predictor effect the study isolates:

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
**the gshare predictor family**, and **`-O1`** compilation — not
fabric- or predictor-independent laws. Absolute frequency/area/power do not
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

## Reproducing the paper evidence

Drive the experiments from the **Vivado Tcl console** (`source <script>`). Each
script writes a result log under [`vivado/`](vivado/); the comments below name
the log that backs the corresponding paper section.

```tcl
# --- Synthesis: F_max + area, 10 placement seeds, all five depths ---
source vivado/synth_seeds.tcl          ;# -> vivado/seed_results.log   (two-tier F_max)
source vivado/synth_all.tcl            ;# -> vivado/synth_results.log  (area, DSP)
source vivado/synth_bram.tcl           ;# BRAM instr-memory variants -> vivado/bram_synth_results.log

# --- Baseline CPI / misprediction measurements (Mechanism A vs B) ---
source vivado/run_coremark.tcl         ;# -> vivado/coremark_official_results.log
source vivado/run_dhrystone.tcl        ;# -> vivado/dhrystone_results.log
source vivado/run_diagnostic.tcl       ;# -> vivado/diagnostic_results.log
source vivado/run_embench_official.tcl ;# -> vivado/embench_official_results.log

# --- Causal isolation of Mechanism B (the two controls) ---
source vivado/run_bimodal.tcl          ;# no-GHR control -> vivado/bimodal_results.log
source vivado/run_predictor_sweep.tcl  ;# 32..1024 PHT sweep -> vivado/predictor_sweep_results.log

# --- SGF and orthogonal techniques ---
source vivado/run_sgf_eval.tcl         ;# SGF 7/8-stage bench + synth
                                       ;#   -> vivado/sgf_benchmark_results.log, vivado/sgf_synth_results.log
source scripts/run_sgf_6stage.tcl      ;# SGF on the 6-stage (recommended depth)
source scripts/run_nlp_7stage.tcl      ;# baseline vs next-line predictor (IF2-bubble recovery)
source scripts/run_sgf_nlp.tcl         ;# SGF / NLP / SGF+NLP orthogonality

# --- Power ---
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
| Two-tier F_max (70–74 vs 115–118 MHz, *p* < 0.001, *d* = 18.5); execute-stage split is the only knee | `vivado/synth_seeds.tcl`, `vivado/synth_all.tcl` → `vivado/seed_results.log`, `vivado/synth_results.log`; fig `scripts/regen_throughput_published.py` |
| 6-stage is throughput- and energy-optimal on this fabric (64.1 MIPS, lowest EDP) | CPI from `vivado/coremark_official_results.log` × F_max above; fig `scripts/regen_throughput_published.py` |
| Depth splits into Mechanism A (all workloads) + Mechanism B (CoreMark +5.7%, statemate +10%) | `vivado/coremark_official_results.log`, `vivado/embench_official_results.log`, `vivado/dhrystone_results.log`, `vivado/diagnostic_results.log` |
| Mechanism B **requires** a GHR (bimodal control: zero depth inflation) | `rtl/branch_predictor_bimodal.sv`, `vivado/run_bimodal.tcl` → `vivado/bimodal_results.log` |
| Mechanism B is **not** PHT aliasing (32→1024 sweep, inflation persists) | `vivado/run_predictor_sweep.tcl` → `vivado/predictor_sweep_results.log` |
| SGF: −31.4% CoreMark / −22.7% statemate, +0.7% area, no F_max loss | `rtl/branch_predictor_sgf.sv`, `rtl_7stage/rv32i_pipeline_7stage_sgf_top.sv`, `vivado/run_sgf_eval.tcl` → `vivado/sgf_benchmark_results.log`, `vivado/sgf_synth_results.log` |
| SGF on the 6-stage (−23.9% CoreMark) | `rtl/rv32i_pipeline_sgf_top.sv`, `scripts/run_sgf_6stage.tcl` |
| Analytical CPI model R² = 0.977, R²_CV = 0.941 (LOWO) | `scripts/generate_plots_5depth.py` (fit + `cpi_vs_depth`); inputs are the benchmark logs above |
| Workload-SAIF power *falls* with depth (opposite to uniform-toggle) | `scripts/run_saif_workload.tcl` → `vivado/supplementary_4s8s_results.log`; fig `scripts/regen_power_figs.py` |
| NLP recovers part of the IF2 bubble; **SGF+NLP super-additive** (CPI 1.89) | `rtl_7stage/rv32i_pipeline_7stage_nlp_top.sv`, `rtl_7stage/rv32i_pipeline_7stage_sgf_nlp_top.sv`, `scripts/run_nlp_7stage.tcl`, `scripts/run_sgf_nlp.tcl` |
| BRAM instr-memory lets 7/8-stage near-match 6-stage F_max | `rtl/rv32i_pipeline_bram_top.sv`, `rtl_7stage/rv32i_pipeline_7stage_bram_top.sv`, `vivado/synth_bram.tcl` → `vivado/bram_synth_results.log`; fig `scripts/regen_bram_fig.py` |
| Determinism: identical instruction/branch counts + memory checksums across all depths | every benchmark log above; `tb/rv32i_benchmark_tb.sv`, `tb/rv32i_riscv_tests_tb.sv` |
| Functional correctness (37 riscv-tests + 24-point bench) | `tb/rv32i_riscv_tests_tb.sv`, `tb/rv32i_comprehensive_tb.sv`, `scripts/run_all_tests.tcl` → `vivado/test_results.log` |

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

Variant tops with the contribution applied: **SGF** (`*_sgf_top.sv`), **NLP**
(`*_nlp_top.sv`), and the combined **SGF+NLP** (`*_sgf_nlp_top.sv`).

## Synthesis results (Artix-7 XC7A35T, 10-seed mean)

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
benefit, so it is off by default and retained only as a build option (paper §V-G).

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
  main.tex                 the paper (SGF + pipeline-depth study)
  references.bib           bibliography
  figures/                 all figures (.png + .pdf)
  REQUIRED_EXPERIMENTS.md  experiment tracker
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
vivado/                    experiment driver TCL scripts + committed *_results.log
scripts/                   SGF/NLP/6-stage/SAIF driver TCL + regen_*.py figure scripts
results/                   curated copy of headline result logs
constraints/               Basys 3 XDC
tools/                     hex disassembler, riscv-tests runner
```

## References

- McFarling, *Combining Branch Predictors*, WRL TN-36, 1993 (gshare)
- Yeh & Patt, *Two-Level Adaptive Training Branch Prediction*, MICRO 1991
- Smith, *A Study of Branch Prediction Strategies*, ISCA 1981
- Jiménez & Lin, *Dynamic Branch Prediction with Perceptrons*, HPCA 2001
- Hartstein & Puzak, *The Optimum Pipeline Depth for a Microprocessor*, ISCA 2002
- Karkhanis & Smith, *A First-Order Superscalar Processor Model*, ISCA 2004
- Kuon & Rose, *Measuring the Gap Between FPGAs and ASICs*, 2007
- Patterson & Hennessy, *Computer Organization and Design: RISC-V Edition*
- [RISC-V ISA](https://riscv.org/specifications/) · [riscv-tests](https://github.com/riscv-software-src/riscv-tests)

## License

MIT
