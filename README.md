# Speculative GHR Forwarding (SGF) — eliminating stale branch-predictor state in deep FPGA pipelines

Code, RTL, and data artifact for the paper

> **Speculative GHR Forwarding: Eliminating Stale Branch-Predictor State in Deep FPGA Pipelines**
> Devansh Joshi and Shafin Ula, The University of Texas at Austin
> Targeting *ACM Transactions on Reconfigurable Technology and Systems* (TRETS).

The paper is in ACM `acmart` format, split into the main paper
[`paper/main.tex`](paper/main.tex) and a companion
[`paper/supplement.tex`](paper/supplement.tex) of corroborating figures and tables.

---

## What this is about

When an in-order FPGA soft core is pipelined deeper to raise its clock, the
branch predictor's **global history register (GHR) goes stale**: the latency
between a branch resolving and the next prediction grows, so closely-spaced
branches are predicted from history that does not yet reflect the previous
branch's outcome. The *predictor hardware is unchanged* — depth alone inflates
mispredictions on branch-dense, data-dependent workloads.

This work does two things:

1. **Measures and isolates that effect under controlled conditions.** Five RV32IM
   pipelines (4–8 stages) are built from *identical* functional-unit RTL — only
   the staging changes — and synthesized on a Xilinx Artix-7. The depth-dependent
   CPI cost is decomposed into two mechanisms, and the stale-GHR component is
   isolated *causally* with two controls.
2. **Fixes the correctable part with Speculative GHR Forwarding (SGF)** — a
   dual-GHR scheme that keeps a speculative history fresh at prediction time and
   recovers it on misprediction from a per-branch checkpoint forwarded through
   the pipeline's **existing** registers. No reorder buffer, no branch stack.

> **SGF cuts 7-stage CoreMark mispredictions by 31.4 % and statemate by 22.7 %,
> at +49 LUTs / +57 FFs (≈0.7 % area) and no frequency loss**, pushing
> deep-pipeline accuracy *below* the shallow-pipeline baseline. The benefit
> reproduces (measured) on tournament and downscaled-TAGE predictors.

SGF is a **favorable cost–benefit tradeoff, not a large speedup** (the 31 %
misprediction cut is ≈3 % CPI). Its value appears when depth is *already forced*
by a timing constraint, such as a registered-BRAM fetch that mandates the
IF1/IF2 split — there the stale-GHR penalty is otherwise unavoidable, and SGF
removes it almost for free.

### The two mechanisms

| | Mechanism A — flush penalty | Mechanism B — stale-GHR penalty |
|---|---|---|
| Cause | More stages to drain per misprediction | GHR not yet updated when the next branch is predicted |
| Scope | **All** workloads | Only branch-dense, data-dependent workloads (2 of our 7) |
| Correctable? | No (inherent to depth) | **Yes — this is what SGF removes** |
| Predictable from structure? | Yes | No (needs cycle-accurate simulation) |

---

## Headline results (Artix-7 XC7A35T, Vivado 2025.2)

**Baseline, 10-directive synthesis mean + RTL-simulation CPI:**

| Metric | 4-stg | 5-stg | **6-stg** | 7-stg | 8-stg |
|---|---|---|---|---|---|
| F_max (MHz) | 70.4 | 74.0 | **117.3** | 115.0 | 117.5 |
| Slice LUTs | 7,219 | 7,429 | 7,631 | 7,766 | 7,841 |
| Slice Regs (FF) | 8,040 | 8,190 | 8,501 | 8,550 | 8,678 |
| CoreMark CPI | 1.54 | 1.63 | 1.83 | 2.02 | 2.18 |
| CoreMark MIPS | 45.7 | 45.4 | **64.1** | 56.9 | 53.9 |

- **Two-tier F_max structure:** shallow (4/5-stage) at 70–74 MHz vs. deep
  (6/7/8-stage) at 115–118 MHz (*p* < 0.001, Cohen's *d* = 18.5). The
  **execute-stage split is the only frequency knee**, which makes the **6-stage
  the throughput optimum** (64.1 MIPS, also lowest energy/EDP, 286 MIPS/W).

**SGF on the 7-stage (RTL simulation; instruction/branch counts bit-identical to baseline):**

| Workload | Baseline mispred. | SGF mispred. | Δ |
|---|---|---|---|
| CoreMark | 147,760 | **101,418** | −31.4 % |
| statemate | 73,263 | **56,627** | −22.7 % |
| aha-mont64 | 139,739 | 115,644 | −17.2 % |
| crc32 | 344 | 511 | +48.5 % (CPI-neutral edge case) |
| Dhrystone / Diagnostic / edn | — | unchanged | 0 % |

SGF cost (7-stage, workload-independent): **+49 LUTs (+0.6 %), +57 FFs (+0.7 %),
0 DSP/BRAM, no F_max loss.** SGF also applies at the throughput-optimal 6-stage
(CoreMark −23.9 %).

**Generalization (measured, 7-stage, misprediction Δ):**

| Workload | gshare | Tournament | TAGE |
|---|---|---|---|
| CoreMark | −31.4 % | −3.1 % | −31.1 % |
| statemate | −22.7 % | −10.5 % | −11.1 % |
| aha-mont64 | −17.2 % | −2.8 % | +5.0 % |
| crc32 | +48.5 % | −48.3 % | −48.8 % |

The benefit reproduces across predictor families; the **cost** stays sub-1 % on
single-history predictors (gshare, tournament) but grows to **+21 % LUTs on
multi-table TAGE** (per-table dual hashing does not share) — measured, not
projected.

---

## How the claims are supported

Every number in the paper traces to a **committed result log in [`results/`](results/)**.
The two controls that make the stale-GHR claim *causal* rather than correlational:

- **Bimodal control** (no GHR): identical misprediction counts at *every* depth
  (CoreMark 85,493; statemate 63,272) — zero Mechanism B without a GHR.
- **32× PHT capacity sweep** (32→1024 entries): the depth inflation persists at
  every table size — it is not an aliasing artifact.

A **first-order CPI model** (R² = 0.977, leave-one-workload-out R²_CV = 0.941)
decomposes CPI into flush, load-use, IF2-bubble, and workload-base terms.

---

## Requirements

- **Xilinx Vivado 2025.2** — XSim for cycle-accurate (RTL) simulation;
  post-place-and-route for F_max/area/power. The design is single-clock-domain
  and deterministic.
- **riscv-none-elf-gcc 15.2.0** (xPack) — only to rebuild benchmark hex; prebuilt
  hex is committed under [`programs/`](programs/).
- **Python 3** + `matplotlib`, `numpy` — only to regenerate figures.

CPU-only machines cannot re-run the Vivado flow, but **all result logs and
figure scripts are committed**, so every numeric claim is inspectable offline.

> **Portability / scratch directory.** No absolute machine paths are baked in —
> every driver script resolves the repo root from its own location
> (`[info script]`). Vivado projects and temporaries are written to a scratch
> directory off the (OneDrive-synced) repo; set the **`RISCV_WORK`** environment
> variable to point it at your scratch disk. Committed result logs contain no
> drive letters, so they reproduce identically on any machine.

---

## Reproducing the evidence

Drive the experiments from the **Vivado Tcl console** (`source <script>`); all
drivers are in [`scripts/`](scripts/) and the committed log that backs each paper
section is named in the comments.

```tcl
# --- Synthesis: F_max + area, 10 directive combinations, all five depths ---
source scripts/synth_seeds.tcl            ;# -> results/seed_results.log     (two-tier F_max)
source scripts/synth_all.tcl              ;# -> results/synth_results.log    (area, DSP)
source scripts/synth_bram.tcl             ;# BRAM instr-memory variants -> results/bram_synth_results.log

# --- Baseline CPI / mispredictions (Mechanism A vs B) ---
source scripts/run_coremark.tcl           ;# 4/5/6-stage -> results/coremark_official_results.log
source scripts/run_7s8s_rerun.tcl         ;# canonical 7/8-stage -> results/7s8s_rerun_results.log
source scripts/run_dhrystone.tcl          ;# -> results/dhrystone_results.log
source scripts/run_diagnostic.tcl         ;# -> results/diagnostic_results.log
source scripts/run_embench_official.tcl   ;# -> results/embench_official_results.log

# --- Causal isolation of Mechanism B (the two controls) ---
source scripts/run_bimodal.tcl            ;# no-GHR control -> results/bimodal_coremark_results.log
source scripts/run_predictor_sweep.tcl    ;# 32..1024 PHT sweep -> results/predictor_sweep_results.log

# --- SGF ---
source scripts/run_sgf_eval.tcl           ;# 7/8-stage SGF bench + synth -> results/sgf_benchmark_results.log, results/sgf_synth_results.log
source scripts/run_sgf_6stage.tcl         ;# SGF at the throughput-optimal 6-stage -> results/sgf_6stage_results.log
source scripts/run_sgf_filter_7stage.tcl  ;# confidence-filter build option -> results/sgf_filter_7stage_results.log

# --- Generalization to other predictor families (measured) ---
source scripts/run_tournament_7stage.tcl  ;# -> results/tournament_results.log, results/tournament_synth_results.log
source scripts/run_tage_7stage.tcl        ;# -> results/tage_results.log, results/tage_synth_results.log

# --- Robustness and power ---
source scripts/run_O2_7stage.tcl          ;# -O2 recompilation -> results/o2_7stage_results.log
source scripts/run_saif_workload.tcl      ;# workload-SAIF power, all depths -> results/saif_workload_results.log
```

Regenerate every figure from the committed data (no Vivado needed):

```bash
python scripts/generate_plots_5depth.py       # fmax, area, cpi, mispred, coremark/MHz, cpi-vs-depth + model fit
python scripts/regen_throughput_published.py  # throughput, published-cores context
python scripts/regen_power_figs.py             # power, efficiency (workload-SAIF)
python scripts/regen_bram_fig.py               # LUT- vs BRAM-memory F_max
```

---

## Claim-to-Code map

| Paper claim | Code / artifact |
|---|---|
| Two-tier F_max (70–74 vs 115–118 MHz, *p* < 0.001, *d* = 18.5); execute split is the sole knee | `scripts/synth_seeds.tcl`, `scripts/synth_all.tcl` → `results/seed_results.log`, `results/synth_results.log` |
| 6-stage is throughput- and energy-optimal (64.1 MIPS, 286 MIPS/W, lowest EDP) | CPI from `results/coremark_official_results.log` (4/5/6) + `results/7s8s_rerun_results.log` (canonical 7/8) × F_max above |
| Mechanism A (all workloads) + Mechanism B (CoreMark +5.7 % @6-stg, statemate +10 % @7/8-stg) | `results/coremark_official_results.log`, `results/embench_official_results.log`, `results/7s8s_rerun_results.log` |
| Mechanism B **requires a GHR** (bimodal control: 85,493 / 63,272 at every depth) | `rtl/branch_predictor_bimodal.sv` → `results/bimodal_coremark_results.log` |
| Mechanism B is **not aliasing** (32→1024 PHT sweep, inflation persists) | `results/pht_sweep_coremark_results.log` |
| First-order CPI model R² = 0.977, R²_CV = 0.941 | `scripts/generate_plots_5depth.py` (fit), inputs are the benchmark logs above |
| **SGF**: −31.4 % CoreMark / −22.7 % statemate, +0.7 % area, no F_max loss | `rtl/branch_predictor_sgf.sv`, `rtl_7stage/rv32i_pipeline_7stage_sgf_top.sv` → `results/sgf_benchmark_results.log`, `results/sgf_synth_10seeds_results.log` |
| SGF at the 6-stage (−23.9 % CoreMark) | `rtl/rv32i_pipeline_sgf_top.sv`, `scripts/run_sgf_6stage.tcl` → `results/sgf_6stage_results.log` |
| Confidence filter (build-time option, OFF by default): CoreMark 101,418→117,207, −20.7 % | `rtl/branch_predictor_sgf.sv` (`CONF_FILTER` param), `scripts/run_sgf_filter_7stage.tcl` → `results/sgf_filter_7stage_results.log` |
| SGF generalizes — tournament (−3.1 % / −10.5 %), +0.6 % LUT, no F_max loss | `rtl/branch_predictor_tournament{,_sgf}.sv`, `scripts/run_tournament_7stage.tcl` → `results/tournament_results.log`, `results/tournament_synth_results.log` |
| SGF generalizes — TAGE (−31.1 % / −11.1 %; +21 % LUT multi-table cost; filter backfires) | `rtl/branch_predictor_tage{,_sgf}.sv`, `scripts/run_tage_7stage.tcl` → `results/tage_results.log`, `results/tage_synth_results.log`, `results/tage_filtered_results.log` |
| SGF benefit survives `-O2` (CoreMark −43.6 %, statemate −12.0 %) | `scripts/build_O2_benchmarks.sh`, `scripts/run_O2_7stage.tcl` → `results/o2_7stage_results.log` |
| Workload-SAIF power *falls* with depth (0.235→0.217 W) | `scripts/run_saif_workload.tcl` → `results/saif_workload_results.log` |
| BRAM instr-memory lifts 7/8-stage near 6-stage F_max | `scripts/synth_bram.tcl` → `results/bram_synth_results.log` |
| Determinism + functional correctness (37 riscv-tests) | every benchmark log; `scripts/run_all_tests.tcl` → `results/test_results.log` |

---

## The research vehicle

A pipelined **RV32IM** core in SystemVerilog: all 40 RV32I + 8 RV32M
instructions, M-mode CSRs / trap handling / MRET, a **gshare** predictor
(64-entry PHT, 6-bit GHR, 32-entry BTB, 4-entry RAS), a direct-mapped I-cache,
three-source forwarding, and 64-bit performance counters. Validated against the
37-test **riscv-tests** suite and a comprehensive testbench. Every functional
unit and the predictor are **held constant across depths** — only the staging
changes — so CPI differences are attributable to depth, with each split's
structural side effects (load-use stall, IF2 bubble, forwarding sources) made
explicit and decomposed by the CPI model.

### Pipeline variants

| Variant | Stages | Notes |
|---|---|---|
| 4-stage | IF, ID, EX, MEM/WB | merged MEM/WB (no load-use stall), longest critical path |
| 5-stage | IF, ID, EX, MEM, WB | classic RISC |
| **6-stage** | IF, ID, EX1, EX2, MEM, WB | execute split → +56 % F_max; **throughput-optimal** |
| 7-stage | IF1, IF2, ID, EX1, EX2, MEM, WB | fetch split (registered PC); 1-cycle IF2 bubble |
| 8-stage | IF1, IF2, ID, EX1, EX2, MEM1, MEM2, WB | memory split (same predictor update latency as 7-stage) |

Predictor update latency — the stages between prediction and resolution, the
central variable for Mechanism B — is 2, 2, 3, 4, 4 for depths 4–8. SGF variants
carry the suffix `*_sgf_top.sv`.

### How SGF works (in one paragraph)

Two histories: `spec_ghr` updates at prediction time (kept fresh for the next
prediction) and `committed_ghr` updates at resolution (ground truth). Predictions
index the PHT on `spec_ghr`; the PHT is *trained* on a 6-bit `ghr_checkpoint`
snapshotted at prediction time and forwarded through the existing pipeline
registers, so training always uses the index the prediction used. On a
misprediction the flush restores `spec_ghr` from `committed_ghr` in the same
cycle. Because an in-order single-issue pipeline resolves branches in program
order, a single checkpoint per in-flight branch is provably sufficient — **no
reorder buffer is needed.** Cost is linear in GHR width: `h × s` flip-flops plus
one `h`-bit rollback mux. A SystemVerilog assertion suite encodes the invariants.

---

## Benchmarks

Seven workloads, all `-O1`, bare-metal: **CoreMark** (EEMBC), **Dhrystone 2.1**,
a mixed **Diagnostic** program, and four **Embench-IoT** kernels (aha-mont64,
crc32, statemate, edn). Sources and prebuilt hex are under
[`programs/`](programs/). Each reads the hardware performance counters before and
after the run and stores results to data memory for testbench readout;
determinism is verified by identical instruction/branch counts and memory
checksums across all five depths.

---

## Repository layout

```
README.md  LICENSE  NOTICE  .gitignore
paper/
  main.tex                 main paper (acmart / ACM TRETS format)
  supplement.tex           supplementary material (corroborating figures + tables)
  references.bib           bibliography
  figures/                 all figures (.png / .pdf)
rtl/                       shared functional units + 6-stage baseline + SGF/bimodal/BRAM tops
  branch_predictor.sv          gshare + BTB + RAS (baseline)
  branch_predictor_sgf.sv      dual-GHR SGF predictor (CONF_FILTER build option)
  branch_predictor_bimodal.sv  no-GHR control (causal isolation)
  branch_predictor_tournament.sv / _tournament_sgf.sv
  branch_predictor_tage.sv / _tage_sgf.sv
  alu / mdu / csr_unit / regfile / icache / imem / dmem / pipe_* / ...
rtl_4stage/ rtl_5stage/     depth-specific tops + forwarding/hazard units
rtl_7stage/                7-stage baseline, SGF, BRAM tops + pipe_if1_if2
rtl_8stage/                8-stage tops (incl. pipe_mem1_mem2)
tb/  tb_4stage/ … tb_8stage/   testbenches (riscv-tests, comprehensive, per-depth)
programs/                  asm/ , c/ , coremark/ , embench/   (sources + hex)
scripts/                   ALL driver TCL (synthesis, baseline, causal, SGF,
                           tournament, TAGE, -O2, power) + regen_*.py + synth .xdc
  _synth_rtl/              flat RTL snapshot used by the synthesis/baseline harness
results/                   ALL result logs (every paper number traces to one of these)
constraints/               Basys 3 XDC
docs/  tools/              pipeline diagram; hex disassembler, riscv-tests runner
```

---

## Scope (what the results are bounded to)

Measured outcomes under **one FPGA family** (Artix-7 XC7A35T), **one toolchain**
(Vivado 2025.2), **one in-order microarchitecture**, the **gshare** predictor
(with measured generalization to tournament and TAGE), and **`-O1`** compilation
— not fabric- or predictor-independent laws. What transfers without re-measurement
is the **Mechanism-A/B decomposition** and the **ROB-free dual-GHR construction**;
the specific percentages and the F_max tier boundaries are fabric/tool-specific.
All cycle counts are RTL simulation and all timing/area/power are
post-place-and-route or Vivado estimates — no physical-board measurement is
claimed. See `paper/main.tex` §Limitations.

---

## License

The original work here — RV32IM RTL, testbenches, driver and figure scripts,
result logs, constraints, and paper sources — is released under the **MIT
License** ([`LICENSE`](LICENSE)). The bundled benchmarks under
[`programs/`](programs/) keep their upstream licenses (CoreMark — EEMBC,
Apache-2.0; Embench-IoT; Dhrystone 2.1 — public domain); only our bare-metal
porting layer and derived `.hex` are MIT. See [`NOTICE`](NOTICE).

If you use this work, please cite the paper (Joshi and Ula, *Speculative GHR
Forwarding: Eliminating Stale Branch-Predictor State in Deep FPGA Pipelines*).
