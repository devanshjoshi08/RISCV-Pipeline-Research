# Speculative GHR Forwarding & a Controlled Pipeline-Depth Study on FPGA

A research project around an RV32IM RISC-V soft core, asking a question prior work
leaves open: **how does pipeline depth alone affect performance on an FPGA, and
what does it cost the branch predictor?** We build five pipeline variants (4–8
stages) from *identical* RTL for every functional unit, vary only the depth, and
synthesize all of them on a Xilinx Artix-7 (Vivado 2025.2, 10 placement seeds, 50
post-place-and-route runs).

The study isolates a correctable predictor effect and proposes a fix for it:

> **Speculative GHR Forwarding (SGF)** — a ROB-free way to give an in-order FPGA
> soft core the speculative branch history that, until now, only out-of-order ASIC
> cores (with reorder buffers) could afford. SGF cuts 7-stage CoreMark
> mispredictions **31.4%** at **0.7% area** and **no frequency loss**.

The full write-up is in [`paper/main.tex`](paper/main.tex) (targeting IEEE
Transactions on Computers). This README summarizes the findings and how to
reproduce them; every number below traces to a committed result log and is
reproducible from the RTL and TCL scripts in this repo.

**Authors:** Devansh Joshi and Shafin Ula (The University of Texas at Austin)

---

## Key findings

| Finding | Result |
|---|---|
| **Two-tier F_max** on Artix-7 | 4/5-stage cluster at **70–74 MHz**, 6/7/8-stage at **115–118 MHz** (*p* < 0.001, Cohen's *d* = 18.5). The *only* knee is the execute-stage (EX1/EX2) split. |
| **Throughput-optimal depth** | **6-stage** (64.1 MIPS CoreMark, lowest energy 7.0 mJ, best efficiency 286 MIPS/W) — deeper pipelines don't pay off on this fabric. |
| **Two depth costs, separated** | *Mechanism A* (inherent flush-penalty scaling, all workloads) vs *Mechanism B* (stale-GHR misprediction inflation, +5.7% CoreMark / +10% statemate — only the 2 of 7 workloads with short inter-branch distance + data-dependent branches). |
| **Causal isolation** | A bimodal predictor (no GHR) shows **zero** depth inflation; a 32× PHT capacity sweep (32→1024) shows the inflation is **not** aliasing. So Mechanism B is GHR-staleness, full stop. |
| **SGF (the fix)** | 7-stage CoreMark mispredictions **147,760 → 101,418 (−31.4%)**, statemate −22.7%; pushes deep-pipeline accuracy *below* the shallow-pipeline baseline; +49 LUT/+57 FF (0.7%), no F_max loss. Also helps the 6-stage (−23.9%). |
| **Analytical CPI model** | First-principles, 4 interpretable terms, **R² = 0.977** (R²_CV = 0.941, leave-one-workload-out). |
| **Workload-SAIF power** | With per-workload switching activity, on-chip power *falls* with depth (deeper → lower IPC → less switching) — opposite to a uniform-toggle estimate. |
| **Next-line predictor (NLP)** | A measured IF1 next-fetch predictor recovers part of the 7-stage IF2 bubble (CPI 2.02→1.97); **SGF+NLP is super-additive** (CPI 1.89) because SGF absorbs the NLP's misprediction side-effect. |

All five pipeline variants execute **identical instruction counts, branch counts,
and memory checksums** for every workload (determinism check), so depth is the
only independent variable.

## The processor (research vehicle)

A pipelined **RV32IM** core in SystemVerilog: all 40 RV32I + 8 RV32M instructions,
M-mode CSRs / trap handling / MRET, a **gshare** predictor (64-entry PHT, 6-bit
GHR) with a 32-entry BTB and 4-entry RAS, a direct-mapped I-cache, 3-source
forwarding, and 64-bit performance counters (cycles, retired instr, branches,
mispredictions). Validated against the 37-test **riscv-tests** suite and a
24-point comprehensive testbench; the 6-stage variant has been deployed on a
Basys 3 at 100 MHz. Predictor and all functional units are held constant across
depths — only the pipeline staging changes.

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

SGF on the 7-stage: +49 LUT (+0.6%), +57 FF (+0.7%), F_max 117.5 vs 115.0 MHz (no
degradation). SGF ships **without** a confidence filter — we measured one that
fixes a zero-CPI crc32 edge case but costs ~11 points of the CoreMark benefit, so
we reject it (see §V-G of the paper).

## Benchmarks

Seven workloads, all `-O1`, bare-metal: **CoreMark** (EEMBC), **Dhrystone 2.1**, a
mixed **Diagnostic** program, and four **Embench-IoT** kernels (aha-mont64, crc32,
statemate, edn). Each reads the hardware counters before/after and stores results
to data memory for testbench readout.

## Reproducing the experiments

All experiments run in Vivado (XSim for cycle-accurate simulation, post-PnR for
F_max/area). Simulations are deterministic and cycle-accurate vs. silicon
(single clock domain). Drive them from the Vivado Tcl console:

```tcl
source scripts/run_pht_sweep_coremark.tcl   ; # PHT capacity sweep (Mechanism B isolation)
source scripts/run_sgf_eval.tcl             ; # SGF 7/8-stage benchmarks + synthesis
source scripts/run_sgf_6stage.tcl           ; # SGF on the 6-stage variant
source scripts/run_nlp_7stage.tcl           ; # baseline vs NLP (IF2-bubble recovery)
source scripts/run_sgf_nlp.tcl              ; # SGF / NLP / SGF+NLP orthogonality
source scripts/run_saif_workload.tcl        ; # workload-specific SAIF power, all depths
```

> **Note:** long benchmark simulations generate large XSim waveform temporaries.
> The scripts delete each project directory after scraping its result log so the
> disk doesn't fill; keep waveform logging off for multi-million-cycle runs.

Figures are regenerated from the consolidated data with the `scripts/regen_*.py`
matplotlib scripts (power, efficiency, BRAM, throughput, published-cores), and the
remaining figures with `scripts/generate_plots_5depth.py`.

## Repository layout

```
paper/
  main.tex                 the paper (SGF + pipeline-depth study)
  references.bib           bibliography
  figures/                 all figures (.png + .pdf)
  REQUIRED_EXPERIMENTS.md  experiment tracker
rtl/                       shared functional units + 6-stage baseline + SGF tops
  branch_predictor.sv          gshare + BTB + RAS (baseline)
  branch_predictor_sgf.sv      dual-GHR speculative-forwarding predictor (SGF)
  rv32i_pipeline_top.sv        6-stage baseline
  rv32i_pipeline_sgf_top.sv    6-stage SGF
  alu / mdu / csr_unit / regfile / imm_gen / control / icache / imem / dmem / ...
rtl_4stage/ rtl_5stage/    depth-specific tops + forwarding/hazard units
rtl_7stage/                7-stage baseline, SGF, NLP, and SGF+NLP tops + pipe_if1_if2
rtl_8stage/                8-stage tops (incl. pipe_mem1_mem2)
tb/                        single-cycle, pipeline, comprehensive, riscv-tests benches
programs/                  asm/ , c/ , coremark/ , embench/  (sources + hex)
scripts/                   run_*.tcl experiment drivers + regen_*.py figure scripts
constraints/               Basys 3 XDC
tools/                     hex disassembler, riscv-tests runner
*_results.log              committed result logs for every experiment
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
