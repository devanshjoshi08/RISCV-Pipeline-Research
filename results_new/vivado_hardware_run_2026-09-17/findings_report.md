# Vivado 2024.2 SGF hardware-cost findings

## Outcome

All 18 matched implementation runs completed successfully: 3 pipeline depths x 2 designs x 3 directive settings. All designs were fully routed with zero routing errors and nonnegative hold WNS. Setup timing did not meet the aggressive 5.000 ns target; Fmax below is therefore the requested estimate 1000 / (5.000 - WNS) rather than a timing-closed operating guarantee.

| Stages | Mean LUT overhead | Mean FF overhead | Mean estimated-Fmax change | DSP delta | BRAM delta |
|---:|---:|---:|---:|---:|---:|
| 6 | 0.37% | 2.07% | -3.55% | 0 | 0 |
| 7 | 0.77% | 0.07% | -1.81% | 0 | 0 |
| 8 | 0.65% | 0.24% | -3.13% | 0 | 0 |

The SGF area cost is small and consistent in LUTs: +23 to +62 LUTs (+0.30% to +0.80%) in all nine matched pairs. FF impact is depth-dependent: about +2.06% at 6 stages, near zero at 7 stages (-0.31% to +0.26%), and +0.19% to +0.32% at 8 stages. DSP and BRAM usage are unchanged in every pair (12 DSPs, 0 BRAM tiles).

The synthesis hierarchy localizes the intended predictor change: u_bp grows from 708 to 743 LUTs at 6 stages and from 739 to 774 LUTs at 7/8 stages; its FF count grows from 2022 to 2028. Differences in final routed totals reflect cross-hierarchy optimization and directive sensitivity.

SGF lowers the estimated Fmax in all nine matched pairs, by 1.14% to 3.83% (1.30 to 4.45 MHz). This is directionally consistent but modest. The per-stage implementation-directive Fmax spread is 0.20 to 2.83 MHz, while some paired SGF changes are larger (up to 4.45 MHz); the effect is not merely a single outlier, but it should still be treated as an OOC estimate rather than silicon frequency.

Critical setup paths are dominated by PC/control paths feeding the instruction cache, with occasional CSR counter and PC-feedback paths. No reported worst path is inside the SGF predictor itself, so the Fmax decrease appears to be an implementation-level consequence rather than a new SGF-local combinational bottleneck.

## Validity and caveats

- Exact source commit: dabefb19ef967db84bb55bc925f5499afc982643 on sgf-evaluation-automation.
- Tool/device/constraint: Vivado 2024.2, xc7a35tcpg236-1, internal clk period 5.000 ns.
- Top modules: rv32i_pipeline_top (baseline) and rv32i_pipeline_sgf_top (SGF), each with exactly one u_bp; the baseline source sets CONF_FILTER = 0.
- check_timing finds zero unclocked registers, constant clocks, unconstrained internal endpoints, multiple-clock pins, combinational loops, or latch loops. The expected OOC exceptions are one unconstrained reset input and 96 unconstrained debug outputs.
- DRC has no errors or critical warnings. Warnings are OOC board-configuration properties and DSP pipelining/asynchronous-load recommendations.
- Vivado warns that HD.CLK_SRC is unset in OOC mode, so clock insertion delay/skew is not board-accurate. Use these numbers for matched relative comparison, not a final board signoff.

## Files

- hardware_cost_runs.csv: all raw run-level metrics and critical endpoints.
- paired_overhead.csv: nine matched SGF-minus-baseline comparisons.
- summary_statistics.csv: mean/min/max by depth and design.
- validation_summary.txt: automated completeness, routing, DRC, timing-coverage, and hold checks.
- stage*/.../*.rpt: raw Vivado utilization, timing, route, clock, and DRC evidence.
- run_experiment.tcl, run_vivado.ps1, source manifests, hashes, provenance, and full Vivado logs: reproduction record.

Checkpoints are intentionally excluded from the Git commit because they total approximately 228 MB. They remain in the local output package and can be transferred separately if required.
