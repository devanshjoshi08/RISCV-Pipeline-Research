# SGF Vivado hardware-cost run

This directory is a clean, current-source experiment package for the six designs described in `vivado_handoff.md`. It does not alter RTL and does not use historical checkpoints or measurements.

## Current status

Completed successfully on Windows with Vivado 2024.2: all 18 matched runs (3 stages x 2 designs x 3 directives) routed and passed the automated evidence checks. See `findings_report.md`, `paired_overhead.csv`, and `validation_summary.txt`.

The selected branch HEAD is `dabefb19ef967db84bb55bc925f5499afc982643`. Its only changes after the handoff's inspected RTL commit `af884ea7d6fc40150687ce83386e2e5871454a8e` are evaluation artifacts, reports, README content, and testbench/characterization files; the synthesis RTL and clock constraint are unchanged.

## Reproduce

Vivado 2024.2 is used consistently because it is the installed version. Open PowerShell and run:

```powershell
& '.\results_new\vivado_hardware_run_2026-09-17\run_vivado.ps1' -Mode Smoke -VivadoBat 'C:\Xilinx\Vivado\2024.2\bin\vivado.bat'
```

Inspect the 6-stage baseline/default reports, especially `route_status.rpt`, `drc.rpt`, `check_timing.rpt`, `timing_summary.rpt`, and the Vivado log. If the smoke test is valid, run:

```powershell
& '.\results_new\vivado_hardware_run_2026-09-17\run_vivado.ps1' -Mode All -VivadoBat 'C:\Xilinx\Vivado\2024.2\bin\vivado.bat'
```

`All` reuses only the synthesis checkpoint created by this package, skips the already completed smoke implementation, and accounts for the other matched runs. Raw reports and checkpoints stay under this directory. `hardware_cost_runs.csv` is created only from successfully routed, constrained internal `clk`-to-`clk` paths.

Regenerate and validate the summaries with:

```powershell
& '.\summarize_results.ps1'
```

The Git-hosted evidence package omits `.dcp` checkpoints because they total approximately 228 MB. Local checkpoints are retained and can be transferred separately.
