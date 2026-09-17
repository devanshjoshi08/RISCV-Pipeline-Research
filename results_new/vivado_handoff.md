# Vivado handoff: measure current SGF hardware cost

## What to do

Run an apples-to-apples FPGA synthesis and routed implementation comparison for baseline and SGF at 6, 7, and 8 stages. Return LUT, FF, DSP, BRAM, setup WNS, estimated Fmax, critical paths, and matched-run overhead. **Do not change RTL, predictor behavior, pipeline behavior, or CONF_FILTER.** No physical FPGA board is needed.

This experiment has not run yet: the original laptop is a Mac without Vivado. The current hardware_cost.csv contains blocked placeholders, not measurements. Historical results must not be used to fill them.

## Before starting

1. Use a Windows or Linux laptop with working Vivado and Artix-7 device support. Prefer the repository's documented Vivado 2025.2 if available; otherwise record your version and use it for every design.
2. Get the shared repository snapshot from Satya. At handoff creation, the inspected RTL revision was af884ea7d6fc40150687ce83386e2e5871454a8e. Some handoff/results files were uncommitted locally, so cloning GitHub alone may not include this document. Confirm which snapshot was transferred.
3. Record git commit, git status, Vivado version, operating system, and SHA-256 hashes of all used RTL and constraints. Both members of every pair must use the same frozen snapshot. Do not pull or edit sources between runs.
4. Use a new build directory, for example results_new/vivado_hardware_run_01/. Never reuse historical checkpoints. Keep logs, reports, projects, CSVs, and checkpoints inside it.
5. Do not run existing synthesis scripts unchanged. Some use scripts/_synth_rtl historical copies, obsolete paths, or write to old result locations. Use current rtl/, rtl_7stage/, and rtl_8stage/ sources only.

## Fixed configuration

| Setting | Required value |
| --- | --- |
| FPGA part | xc7a35tcpg236-1 |
| Clock | clk, 5.000 ns / 200 MHz target |
| Constraint file | scripts/synth_clk_ooc.xdc |
| Flow | Out-of-context core synthesis, then optimization, placement, routing |
| IO | No board wrapper, pin constraints, or IO buffers |
| PHT / BTB / RAS | 64 / 32 / 4 entries |
| SGF filter | CONF_FILTER=0; currently the default, with no top-level overrides |
| Memory initialization | Current repository RTL defaults, identical within each pair |
| Simulation files | None: do not include testbenches or characterization instrumentation |

The clock-only setup measures internal core paths, not external IO timing or full board performance. Unconstrained IO paths must be documented, not silently treated as timed. Do not substitute BRAM pipeline variants or load benchmark images into only one pair member.

## Six designs and exact source membership

| Stage | Design | Top | Extra source directory |
| --- | --- | --- | --- |
| 6 | baseline | rv32i_pipeline_top | rtl |
| 6 | sgf | rv32i_pipeline_sgf_top | rtl |
| 7 | baseline | rv32i_pipeline_7stage_top | rtl_7stage |
| 7 | sgf | rv32i_pipeline_7stage_sgf_top | rtl_7stage |
| 8 | baseline | rv32i_pipeline_8stage_top | rtl_8stage |
| 8 | sgf | rv32i_pipeline_8stage_sgf_top | rtl_8stage |

For every design, read these shared files from rtl/ in this order:

```text
pkg_riscv.sv alu.sv mdu.sv control.sv branch_unit.sv
csr_unit.sv regfile.sv imm_gen.sv pc.sv icache.sv
imem.sv dmem.sv pipe_if_id.sv pipe_id_ex.sv
pipe_ex_mem.sv pipe_mem_wb.sv pipe_ex1_ex2.sv
```

Then add exactly one predictor from rtl/: branch_predictor.sv for baseline, branch_predictor_sgf.sv for SGF. Add forwarding_unit.sv and hazard_unit.sv from the stage-specific extra directory, then that directory's top file. For stage 7 also add rtl_7stage/pipe_if1_if2.sv; for stage 8 also add rtl_8stage/pipe_if1_if2.sv and rtl_8stage/pipe_mem1_mem2.sv. Do not glob whole RTL directories: duplicated module names and alternative predictors can produce a different experiment.

This is the membership in scripts/run_sgf_evaluation.py:variant(). Baseline/SGF share 19 supporting files at stage 6, 20 at stage 7, and 21 at stage 8. Top-level differences were checked: after removing SGF-only checkpoint declarations/registers/ports and module-name differences, all three pairs were identical. Recheck if your source snapshot differs.

Expected topologies:

```text
6: IF  -> ID -> EX1 -> EX2 -> MEM  -> WB
7: IF1 -> IF2 -> ID -> EX1 -> EX2 -> MEM -> WB
8: IF1 -> IF2 -> ID -> EX1 -> EX2 -> MEM1 -> MEM2 -> WB
```

SGF adds three 6-bit checkpoint register banks and one additional 6-bit history register at the RTL level. The 24 declared extra bits are a sanity check, not an expected exact mapped FF delta.

## Run plan: six syntheses, eighteen implementations

Synthesize each design once using identical synthesis options. Save a fresh synthesized checkpoint for that design. Reopen that checkpoint for each of the following matched implementation runs; do not continue from another run's placed/routed checkpoint.

| Run label | place_design directive | route_design directive |
| --- | --- | --- |
| default | Default | Default |
| explore | Explore | Explore |
| wlblock | WLDrivenBlockPlacement | NoTimingRelaxation |

These combinations come from scripts/synth_one.tcl. They are **directive variation, not random seeds**. Check that your Vivado version accepts them. If one is unsupported, document it and omit it for both members of every affected pair, or agree on one matched replacement. Do not silently use different options for baseline and SGF. Three directive runs do not establish statistical significance; repeated identical runs may be deterministic.

Start with 6-stage baseline/default as a flow smoke test. Inspect errors and timing coverage before launching the remaining runs. The following is a Tcl template for one design/run, not an already validated new driver. Construct rtl_files from the exact membership above and set all variables before running it in the Vivado Tcl console or a batch Tcl file stored under the new build directory.

```tcl
# Inputs to set first:
# repo: absolute repository path (use forward slashes on Windows)
# out: fresh absolute per-design output directory
# top: one of the six top modules
# rtl_files: ordered absolute paths listed above
# label, pdir, rdir: one matched run combination
file mkdir $out
set part xc7a35tcpg236-1
set clk_period 5.000

# Once per design, in a clean Vivado session:
read_verilog -sv $rtl_files
read_xdc [file join $repo scripts synth_clk_ooc.xdc]
synth_design -top $top -part $part -mode out_of_context
report_utilization -file [file join $out synthesis_utilization.rpt]
write_checkpoint [file join $out synthesized.dcp]
close_design

# Repeat this block for each matched directive combination:
set run_dir [file join $out $label]
file mkdir $run_dir
open_checkpoint [file join $out synthesized.dcp]
opt_design
place_design -directive $pdir
route_design -directive $rdir
report_route_status -file [file join $run_dir route_status.rpt]
report_drc -file [file join $run_dir drc.rpt]
check_timing -verbose -file [file join $run_dir check_timing.rpt]
report_clocks -file [file join $run_dir clocks.rpt]
report_utilization -file [file join $run_dir utilization.rpt]
report_utilization -hierarchical -file [file join $run_dir utilization_hierarchical.rpt]
report_timing_summary -report_unconstrained -file [file join $run_dir timing_summary.rpt]
report_timing -delay_type max -max_paths 10 -file [file join $run_dir critical_setup_paths.rpt]
report_timing -delay_type min -max_paths 10 -file [file join $run_dir critical_hold_paths.rpt]
write_checkpoint [file join $run_dir routed.dcp]
close_design
```

Keep the opt_design step identical in every run and do not add phys_opt_design only to selected designs. Save the exact executed Tcl, including any tool-version compatibility changes. Vivado command errors, failed routing, or timing extraction errors must fail the run, not produce a success row.

For batch execution from a Vivado-enabled terminal, use a new script/output path, for example:

```text
vivado -mode batch -source results_new/vivado_hardware_run_01/run.tcl -log results_new/vivado_hardware_run_01/vivado.log -journal results_new/vivado_hardware_run_01/vivado.jou
```

Launch with the new build directory as the working directory where practical so auxiliary Vivado files stay there; adjust paths to absolute ones in that case. Do not create a bitstream: this is an out-of-context measurement.

## Checks required before accepting measurements

- Confirm the elaborated top, predictor hierarchy u_bp, stage register instances, device part, and one 5 ns clk constraint for each design.
- Confirm CONF_FILTER=0 from source/elaboration and matching PHT/BTB/RAS parameters. Do not alter RTL to force historical numbers.
- Check inferred memories, DSPs, latches, black boxes, trimming, and warnings. If current RTL fails synthesis, save the failing logs and stop for discussion; do not switch to an old synthesis snapshot or edit architecture to make it pass.
- Confirm all intended internal clocked paths are constrained, routing is complete, and DRC/hold/setup results are retained. Missing paths/clocks or black boxes invalidate the area/timing comparison.
- Report negative setup WNS honestly: fully routed but failing the 200 MHz target is still a useful measurement. A routing failure is not a timing result. Flag hold violations separately.
- Inspect hierarchical utilization and top critical setup paths if SGF has unexpected area growth or timing loss. Note whether the worst path involves predictor/checkpoint logic or unrelated ALU/MDU/memory logic.

## Measurements and calculations

For each of the eighteen routed runs record:

```text
stage,design,run_label,commit,tool_version,part,clock_period_ns,
luts,ffs,dsps,bram_tiles,wns_ns,fmax_estimated_mhz,
critical_startpoint,critical_endpoint,critical_path_delay_ns,
route_complete,hold_wns_ns,status
```

Use Slice LUTs and Slice Registers from the utilization report consistently, DSP count, and Block RAM Tile count (which can be fractional for 18K blocks). Keep raw reports so definitions can be checked. Never substitute LUT-as-logic counts for total LUTs in one design only.

For the single 5 ns clock, compute estimated Fmax as 1000/(5-WNS) MHz using worst **internal clk-to-clk setup** WNS. Obtain it from timing-path properties or the correct timing summary field, not the first number in the text. If internal timing paths are absent or the denominator is invalid, mark unavailable and investigate. Keep sufficient numerical precision.

This formula is a routed timing estimate at one constraint, **not a measured maximum frequency**. Passing setup at 5 ns supports the 200 MHz target only if hold/routing/coverage checks are also acceptable. An optional clock-period sweep can test a higher target, but it must rerun the same matched flow for both designs and be labeled a separate experiment; do not replace the fixed-5 ns comparison with each design's separately tuned best result.

For every stage/run, calculate:

```text
absolute_resource_delta = SGF_resource - baseline_resource
LUT_increase_% = 100 * (SGF_LUT / baseline_LUT - 1)
FF_increase_% = 100 * (SGF_FF / baseline_FF - 1)
Fmax_change_% = 100 * (SGF_Fmax / baseline_Fmax - 1)
```

Include absolute DSP/BRAM deltas. Percentages with a zero baseline denominator are undefined, not zero. Summarize mean/min/max for LUTs, FFs, WNS, and estimated Fmax across comparable completed runs, plus mean/min/max of paired deltas. Do not compare the best SGF run against the worst baseline run. Show how many runs completed and explain any missing ones.

## What to send back

Send one archive containing the new build directory, executed Tcl, source/hash manifest, Vivado version, all logs, raw synthesis and routed reports, per-run CSV, and a short findings report. Checkpoints may be sent separately if too large. Do not include tool licenses or personal credentials.

Keep measured data in this new directory initially. Satya will review it before replacing the currently blocked results_new/hardware_cost.csv and hardware_cost_report.md. Never overwrite anything in results/ or existing benchmark/selector outputs.

The findings should answer:

1. How many extra LUTs/FFs/DSPs/BRAM tiles does SGF cost at each stage, in absolute and percentage terms?
2. Does estimated Fmax decrease consistently across matched directive runs? Is the change larger than the observed directive sensitivity?
3. Is calling SGF lightweight supported by measured overhead? State numbers rather than imposing an arbitrary threshold.
4. Are any resource/timing changes unexpected enough to investigate? Include the relevant hierarchy and critical paths.

Done means six current-source syntheses and all supported matched implementations are accounted for, reports are retained, configuration checks pass, paired overhead and mean/min/max are calculated, and no architectural changes were made. If blocked, send the exact command/error and logs instead of substituting historical results.
