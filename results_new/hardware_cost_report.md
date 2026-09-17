# Current SGF hardware cost: blocked measurement

No synthesis or place-and-route run was completed. Area, WNS, Fmax, critical paths, and overhead are **unmeasured**, not zero. The CSV records all six intended designs with blank measurements and zero completed runs. Its FPGA target and clock fields describe the intended setup, not an executed experiment.

## Environment blocker

The current host is Darwin arm64. Executable lookup found no Vivado, Yosys, nextpnr-xilinx, or Quartus; inspected common installation locations also did not contain Vivado. No usable remote synthesis runner was identified in the inspected repository instructions/scripts. The existing Artix-7 implementation flow requires Vivado on a supported host with the device installed and a usable license. This cannot be replaced by Icarus or Verilator simulation.

Historical synthesis numbers were deliberately not imported: they do not prove current-source, same-configuration equivalence. No software was installed and no external runner was invoked.

## Source and pair verification

Inspected revision: af884ea7d6fc40150687ce83386e2e5871454a8e. The current RTL directories rtl/, rtl_7stage/, and rtl_8stage/ have no tracked modifications relative to that revision. Existing README/testbench and characterization changes were preserved and are not synthesis sources.

Source membership was taken from scripts/run_sgf_evaluation.py:variant(), which uses current repository RTL, not scripts/_synth_rtl or other historical local copies. Pair members share exactly the same supporting files: 19 shared files for stage 6, 20 for stage 7, and 21 for stage 8. Only the predictor module and pipeline top differ within each pair.

| Stage | Baseline top | SGF top | Corresponding topology |
| --- | --- | --- | --- |
| 6 | rv32i_pipeline_top | rv32i_pipeline_sgf_top | IF / ID / EX1 / EX2 / MEM / WB |
| 7 | rv32i_pipeline_7stage_top | rv32i_pipeline_7stage_sgf_top | IF1 / IF2 / ID / EX1 / EX2 / MEM / WB |
| 8 | rv32i_pipeline_8stage_top | rv32i_pipeline_8stage_sgf_top | IF1 / IF2 / ID / EX1 / EX2 / MEM1 / MEM2 / WB |

A normalization check removed only comments, top/predictor names, SGF checkpoint declarations and register blocks, and added SGF predictor ports. The remaining top-level RTL was identical within every pair. Thus no unrelated top-level pipeline/configuration difference was found. The differences inside the predictor are the treatment being measured; this check is not post-synthesis equivalence or a proof that SGF and baseline make identical predictions.

Both predictors have PHT_DEPTH=64, BTB_DEPTH=32, and RAS_DEPTH=4. The current SGF predictor defaults CONF_FILTER=0; all three SGF tops instantiate it without parameter overrides. The corresponding baseline and SGF designs use the same memory sources and initialization. No characterization monitor or simulation testbench belongs in the synthesis source list.

At the RTL level, SGF adds three 6-bit checkpoint registers and a second 6-bit history register relative to the baseline's single history register: 24 additional declared history/checkpoint state bits. This is **not a measured FF delta**: mapping, optimization, replication, and extra combinational update/recovery logic can change the actual implementation cost.

## Matched implementation setup required to finish

Reuse the current-source out-of-context pattern in scripts/synth_one.tcl, with the existing target xc7a35tcpg236-1 and the 5.000 ns clock-only constraint in scripts/synth_clk_ooc.xdc. Do not execute legacy scripts unchanged: some read historical snapshots, use stale constraint paths, cache checkpoints without revision validation, or write outside results_new/.

For every baseline/SGF pair, use the same Vivado version, source snapshot, synthesis options, target, clock/XDC, optimization sequence, implementation directives, and resource-counting convention. Keep projects, checkpoints, logs, timing/utilization reports, and new scripts under results_new/ or a new temporary build directory. Record tool version and source hashes and avoid stale checkpoint reuse.

The existing multi-run flow supports matched placement/routing directive combinations:

| Run | Placement | Routing |
| --- | --- | --- |
| 1 | Default | Default |
| 2 | Explore | Explore |
| 3 | WLDrivenBlockPlacement | NoTimingRelaxation |

These are directive sensitivity runs, **not independent random seeds**. Apply each combination to both pair members and report per-run results plus mean/min/max; do not interpret these three runs as an independent statistical estimate of placement noise. Confirm directive support in the installed Vivado version before execution. None was executed here.

Extract LUTs, FFs, DSPs, and BRAM tiles from implemented utilization reports. Preserve full timing reports and critical path endpoints. Extract WNS from the actual constrained setup paths rather than the first numeric line of a text report. With one 5 ns clock, an estimated Fmax can be reported as 1000/(5-WNS) MHz, explicitly labeled an estimate; it is not an achieved frequency from a clock-period sweep. A completed routed design passing timing at 5 ns demonstrates the 200 MHz target, not its maximum possible frequency. Report routing/timing failures as failures, never as successful zero-valued results.

For each matched run, compute resource deltas as SGF minus baseline, LUT/FF increase as 100*(SGF-baseline)/baseline, and Fmax change as 100*(SGF-baseline)/baseline. Include absolute DSP and BRAM changes as well. Aggregate only completed comparable runs; report missing/failed runs and undefined percentages for zero denominators.

## Answers to the requested questions

| Question | Current evidence |
| --- | --- |
| How much extra hardware does SGF cost? | Not measured. 24 additional declared state bits are a structural observation, not FPGA area. |
| Does SGF reduce Fmax? | Unknown without matched routed timing results. |
| Is SGF reasonably lightweight? | Cannot establish this from declaration counts or historical results alone. |
| Are any differences large enough to investigate? | No measured differences yet. Investigate mapping failures, unexpected DSP/BRAM changes, or persistent timing/resource differences when actual runs are available. |

To complete the measurement, provide a Vivado-enabled supported host/runner and its execution instructions. RTL, predictor behavior, pipeline behavior, old results/, and existing results_new/ outputs were not modified by this inspection.
