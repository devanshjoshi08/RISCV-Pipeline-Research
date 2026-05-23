# Required Experiments for IEEE Transactions on Computers Submission

This document lists experiments that must be completed before this paper is
ready for IEEE TC. Items are ordered by criticality.

---

## CRITICAL (will cause rejection if missing)

### 1. PHT Sweep on CoreMark and statemate (not just Dhrystone)

**Current problem:** The predictor configuration sweep (Section VI-A) runs
only Dhrystone---a workload that exhibits ZERO Mechanism B. The sweep
"proves" that misprediction counts are invariant to PHT size, but this is
trivially true on a workload where mispredictions never vary with depth
regardless of configuration.

**What to run:** Sweep PHT from 32 to 1024 entries on CoreMark and statemate
across all 5 pipeline depths (at minimum 6-stage and 7-stage, where
Mechanism B is measurable). This answers the reviewer question: "Is the 5.7%
misprediction inflation on CoreMark caused by PHT aliasing in a 64-entry
table, or is it genuinely a pipeline latency effect?"

**Expected outcome:** If Mechanism B is a real pipeline effect (as claimed),
misprediction inflation should persist across all PHT sizes. If it disappears
at larger PHT sizes, the paper's central claim is invalidated.

**Effort:** ~30 simulation runs (6 PHT sizes x 5 depths, or focused on 2-3
key depths). Each CoreMark run takes ~60s in XSim.

### 2. SGF Synthesis with 10 Seeds (currently only 3)

**Current problem:** The baseline synthesis uses 10 seeds (correctly), but
SGF synthesis (`sgf_synth_results.log`, `vivado_sgf_synth/`) has only 3 seeds.
The table caption was fixed to say "3 seeds" but for IEEE TC, the SGF
synthesis should match the baseline methodology (10 seeds) for fair
comparison and proper statistical reporting.

**What to run:** 7 additional synthesis runs for 7-stage SGF and 7 additional
for 8-stage SGF, using the same directive pairings as the baseline 10-seed
methodology.

**Effort:** ~14 Vivado runs. Each takes 10-30 minutes depending on machine.

### 3. Bimodal Comparison on CoreMark/statemate (not just Dhrystone)

**Current problem:** The gshare vs. bimodal comparison (Section VI-B) only
runs Dhrystone---again, a no-Mechanism-B workload. The comparison shows
that both predictors have the same CPI trend, but doesn't test whether
bimodal predictors are immune to Mechanism B (which they should be, since
they don't use a GHR).

**What to run:** Run bimodal predictor on CoreMark and statemate across all 5
depths. If bimodal shows NO Mechanism B while gshare shows Mechanism B on
the same workloads, this is powerful evidence that Mechanism B is specifically
a GHR staleness effect.

**Expected outcome:** Bimodal should show constant misprediction counts
across all depths on CoreMark/statemate (no GHR to become stale). This would
be one of the strongest pieces of evidence in the paper.

**Effort:** ~10 simulation runs.

---

## HIGH PRIORITY (strengthens the paper significantly)

### 4. Workload-Specific SAIF Power Analysis

**Current problem:** Power numbers use a uniform 12.5% toggle rate, not
workload-specific switching activity. IEEE TC reviewers in the FPGA/VLSI
space will flag this immediately.

**What to run:** Generate SAIF files from post-synthesis simulation of each
pipeline variant running CoreMark (at minimum), then re-run
`report_power -saif` with the workload-specific SAIF.

**Effort:** 5 simulation + 5 power analysis runs. May require longer
simulation times to generate useful SAIF.

### 5. SGF on 6-Stage Pipeline

**Current problem:** SGF is only evaluated on 7-stage and 8-stage pipelines.
Since the 6-stage shows the highest Mechanism B misprediction inflation on
CoreMark (154,077 vs. 145,735 baseline = +5.7%), evaluating SGF on the
6-stage would (a) show SGF works at multiple depths, and (b) the 6-stage is
the recommended design point, so showing SGF benefits it is practical.

**What to run:** Implement SGF on 6-stage variant, run CoreMark + statemate,
synthesize.

**Effort:** RTL adaptation + ~7 simulation runs + 3-10 synthesis runs.

### 6. Additional Embench Benchmarks (matmult-int and nettle-aes already compiled)

**Current problem:** Only 4 Embench-IoT benchmarks are used, and only 2 of 7
total workloads show Mechanism B. Adding more benchmarks with high branch
density would strengthen the evaluation.

**Already available:** `programs/embench/` contains compiled hex files for
matmult-int and nettle-aes that are NOT in the paper. These just need
testbenches and simulation runs.

**What to run:** Run matmult-int and nettle-aes across all 5 depths (10 runs).
If they fit in 4KB IMEM, this is trivial. If not, use imem_16k.sv.

**Effort:** Write testbenches + 10 simulation runs. Most of the work is done.

---

## NICE TO HAVE (for R1 revision or strengthening)

### 7. Cross-FPGA Validation (Intel Cyclone V or similar)

An IEEE TC reviewer will likely request this in R1. Porting to Intel FPGA
would validate whether:
- The two-tier Fmax structure is Artix-7 specific or general
- SGF's area/frequency overhead is comparable on Intel fabric
- The CPI model transfers

**Effort:** Significant (weeks). Consider for R1 response.

### 8. -O2 Compilation Level

The paper acknowledges -O1 only. Running CoreMark at -O2 would test whether
higher optimization levels (which alter branch patterns) change Mechanism B
susceptibility.

**Effort:** Recompile benchmarks + 5-10 simulation runs.

### 9. Tournament Predictor with SGF

Extending SGF to a tournament (bimodal + gshare) predictor would demonstrate
generality beyond single-table gshare.

**Effort:** RTL design + simulation + synthesis. Moderate.

---

## Summary of Priority Order

1. PHT sweep on CoreMark/statemate (CRITICAL - easiest, highest impact)
2. SGF synthesis 10 seeds (CRITICAL - easy, data integrity)
3. Bimodal on CoreMark/statemate (CRITICAL - easy, very strong evidence)
4. Workload-specific SAIF power (HIGH - moderate effort)
5. SGF on 6-stage (HIGH - moderate effort)
6. More Embench benchmarks (HIGH - moderate effort)
7. Cross-FPGA (NICE TO HAVE - high effort)
8. -O2 compilation (NICE TO HAVE - low effort)
9. Tournament predictor (NICE TO HAVE - high effort)

Items 1-3 are ~50 simulation runs total and should take a day or two. They
will make or break the paper at IEEE TC review.

---

## Incomplete Experiments Found on D Drive

The following experiments were STARTED but have EMPTY data:

- `D:/riscv-vivado/kintex_results.log` — header only, no synthesis data
- `D:/riscv-vivado/ultrascale_results.log` — header only, no synthesis data
- `D:/riscv-vivado/pht_ghr_sweep_results.log` — header only, PHT/GHR sweep
  on CoreMark+statemate was started but produced no results

These should be re-run. The PHT/GHR sweep on CoreMark is item #1 above.

---

## Directory Cleanup Needed (D:/riscv-vivado/)

The D drive project is disorganized:
- 30 TCL scripts at root level (should be in scripts/)
- 25 log files at root level (should be in results/)
- 24 vivado_* experiment directories cluttering root
- programs/asm/ has 8 hex files with no source (.s or .c)
- tb_8stage/ is missing rv32i_8stage_riscv_tests_tb.sv
- Two .xdc files at root should be in constraints/
- vivado/ contains a full duplicate of rtl/ 
- No rtl_6stage/ directory exists (6-stage uses rtl/ as baseline)
- fibonacci.elf and matmult-int.elf are compiled binaries in git
- main_backup_v13.tex in paper/ — use git history instead

Recommended structure:
```
D:/riscv-vivado/
  rtl/           (shared modules)
  rtl_4stage/    (stage-specific overrides)
  rtl_5stage/
  rtl_7stage/
  rtl_8stage/
  tb/            (shared testbenches)
  tb_4stage/
  ...
  programs/      (source + hex)
  scripts/       (all TCL scripts)
  constraints/   (all XDC files)
  results/       (all log files)
  tools/         (Python utilities)
  paper/         (LaTeX + figures)
  vivado_projects/  (all vivado_* dirs)
```
