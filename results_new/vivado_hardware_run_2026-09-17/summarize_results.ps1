param(
    [string]$OutputDir = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$csvPath = Join-Path $OutputDir 'hardware_cost_runs.csv'
$rows = @(Import-Csv -LiteralPath $csvPath)

function Number([object]$Value) {
    return [double]::Parse([string]$Value, $culture)
}

function Fmt([double]$Value, [int]$Digits = 2) {
    return $Value.ToString("F$Digits", $culture)
}

if ($rows.Count -ne 18) {
    throw "Expected 18 completed runs; found $($rows.Count)."
}

$expectedKeys = foreach ($stage in 6, 7, 8) {
    foreach ($design in 'baseline', 'sgf') {
        foreach ($run in 'default', 'explore', 'wlblock') {
            "$stage|$design|$run"
        }
    }
}
$actualKeys = @($rows | ForEach-Object { "$($_.stage)|$($_.design)|$($_.run_label)" })
$missing = @($expectedKeys | Where-Object { $_ -notin $actualKeys })
$duplicates = @($actualKeys | Group-Object | Where-Object Count -ne 1)
if ($missing.Count -or $duplicates.Count) {
    throw "Run matrix is incomplete or contains duplicates."
}

$pairs = foreach ($stage in 6, 7, 8) {
    foreach ($run in 'default', 'explore', 'wlblock') {
        $baseline = $rows | Where-Object { $_.stage -eq $stage -and $_.design -eq 'baseline' -and $_.run_label -eq $run }
        $sgf = $rows | Where-Object { $_.stage -eq $stage -and $_.design -eq 'sgf' -and $_.run_label -eq $run }
        $lutDelta = (Number $sgf.luts) - (Number $baseline.luts)
        $ffDelta = (Number $sgf.ffs) - (Number $baseline.ffs)
        $dspDelta = (Number $sgf.dsps) - (Number $baseline.dsps)
        $bramDelta = (Number $sgf.bram_tiles) - (Number $baseline.bram_tiles)
        $fmaxDelta = (Number $sgf.fmax_estimated_mhz) - (Number $baseline.fmax_estimated_mhz)
        [pscustomobject][ordered]@{
            stage = $stage
            run_label = $run
            baseline_luts = [int]$baseline.luts
            sgf_luts = [int]$sgf.luts
            lut_delta = [int]$lutDelta
            lut_delta_pct = Fmt (100 * $lutDelta / (Number $baseline.luts)) 3
            baseline_ffs = [int]$baseline.ffs
            sgf_ffs = [int]$sgf.ffs
            ff_delta = [int]$ffDelta
            ff_delta_pct = Fmt (100 * $ffDelta / (Number $baseline.ffs)) 3
            dsp_delta = [int]$dspDelta
            bram_delta = [int]$bramDelta
            baseline_fmax_mhz = Fmt (Number $baseline.fmax_estimated_mhz) 3
            sgf_fmax_mhz = Fmt (Number $sgf.fmax_estimated_mhz) 3
            fmax_delta_mhz = Fmt $fmaxDelta 3
            fmax_delta_pct = Fmt (100 * $fmaxDelta / (Number $baseline.fmax_estimated_mhz)) 3
        }
    }
}
$pairs | Export-Csv -LiteralPath (Join-Path $OutputDir 'paired_overhead.csv') -NoTypeInformation

$stats = foreach ($stage in 6, 7, 8) {
    foreach ($design in 'baseline', 'sgf') {
        $group = @($rows | Where-Object { $_.stage -eq $stage -and $_.design -eq $design })
        [pscustomobject][ordered]@{
            stage = $stage
            design = $design
            lut_mean = Fmt (($group.luts | Measure-Object -Average).Average)
            lut_min = ($group.luts | Measure-Object -Minimum).Minimum
            lut_max = ($group.luts | Measure-Object -Maximum).Maximum
            ff_mean = Fmt (($group.ffs | Measure-Object -Average).Average)
            ff_min = ($group.ffs | Measure-Object -Minimum).Minimum
            ff_max = ($group.ffs | Measure-Object -Maximum).Maximum
            wns_mean_ns = Fmt (($group.wns_ns | Measure-Object -Average).Average) 3
            wns_min_ns = Fmt (($group.wns_ns | Measure-Object -Minimum).Minimum) 3
            wns_max_ns = Fmt (($group.wns_ns | Measure-Object -Maximum).Maximum) 3
            fmax_mean_mhz = Fmt (($group.fmax_estimated_mhz | Measure-Object -Average).Average) 3
            fmax_min_mhz = Fmt (($group.fmax_estimated_mhz | Measure-Object -Minimum).Minimum) 3
            fmax_max_mhz = Fmt (($group.fmax_estimated_mhz | Measure-Object -Maximum).Maximum) 3
        }
    }
}
$stats | Export-Csv -LiteralPath (Join-Path $OutputDir 'summary_statistics.csv') -NoTypeInformation

$validationErrors = [System.Collections.Generic.List[string]]::new()
foreach ($row in $rows) {
    $label = "stage$($row.stage)_$($row.design)/$($row.run_label)"
    if ($row.status -ne 'success') { $validationErrors.Add("$label status=$($row.status)") }
    if ($row.route_complete -ne 'true') { $validationErrors.Add("$label route_complete=$($row.route_complete)") }
    if ((Number $row.hold_wns_ns) -lt 0) { $validationErrors.Add("$label hold WNS is negative") }

    $runDir = Join-Path $OutputDir $label
    $check = Get-Content -LiteralPath (Join-Path $runDir 'check_timing.rpt') -Raw
    foreach ($test in 'no_clock', 'constant_clock', 'unconstrained_internal_endpoints', 'multiple_clock', 'loops', 'latch_loops') {
        if ($check -notmatch [regex]::Escape("checking $test (0)")) {
            $validationErrors.Add("$label check_timing $test is not zero")
        }
    }
    if ($check -notmatch 'checking no_input_delay \(1\)' -or $check -notmatch 'checking no_output_delay \(96\)') {
        $validationErrors.Add("$label external I/O delay counts differ from expected reset/debug ports")
    }

    $route = Get-Content -LiteralPath (Join-Path $runDir 'route_status.rpt') -Raw
    $routable = [regex]::Match($route, '# of routable nets\.+\s*:\s*(\d+)').Groups[1].Value
    $routed = [regex]::Match($route, '# of fully routed nets\.+\s*:\s*(\d+)').Groups[1].Value
    $routeErrors = [regex]::Match($route, '# of nets with routing errors\.+\s*:\s*(\d+)').Groups[1].Value
    if (-not $routable -or $routable -ne $routed -or $routeErrors -ne '0') {
        $validationErrors.Add("$label route status is not fully routed without errors")
    }

    $drc = Get-Content -LiteralPath (Join-Path $runDir 'drc.rpt') -Raw
    if ($drc -match '\|\s*[^|]+\|\s*(Error|Critical Warning)\s*\|') {
        $validationErrors.Add("$label DRC contains an error or critical warning")
    }
}

$validationLines = @(
    'Vivado result validation summary'
    '================================'
    "Rows checked: $($rows.Count)"
    "Expected matrix entries present exactly once: $($missing.Count -eq 0 -and $duplicates.Count -eq 0)"
    "All status=success: $(-not ($rows | Where-Object status -ne 'success'))"
    "All route_complete=true: $(-not ($rows | Where-Object route_complete -ne 'true'))"
    "All hold WNS >= 0 ns: $(-not ($rows | Where-Object { (Number $_.hold_wns_ns) -lt 0 }))"
    'Expected timing exclusions: rst_n has no input delay; 96 debug outputs have no output delay.'
    'DRC warnings allowed: CFGBVS-1, DSP pipelining recommendations, and DSP asynchronous-load checks.'
    "Validation error count: $($validationErrors.Count)"
)
if ($validationErrors.Count) {
    $validationLines += $validationErrors | ForEach-Object { "ERROR: $_" }
}
$validationLines | Set-Content -LiteralPath (Join-Path $OutputDir 'validation_summary.txt') -Encoding utf8
if ($validationErrors.Count) {
    throw "Validation failed; see validation_summary.txt."
}

$stageLines = foreach ($stage in 6, 7, 8) {
    $stagePairs = @($pairs | Where-Object stage -eq $stage)
    $lutMean = ($stagePairs.lut_delta_pct | Measure-Object -Average).Average
    $ffMean = ($stagePairs.ff_delta_pct | Measure-Object -Average).Average
    $fmaxMean = ($stagePairs.fmax_delta_pct | Measure-Object -Average).Average
    "| $stage | $(Fmt $lutMean 2)% | $(Fmt $ffMean 2)% | $(Fmt $fmaxMean 2)% | 0 | 0 |"
}

$report = @"
# Vivado 2024.2 SGF hardware-cost findings

## Outcome

All 18 matched implementation runs completed successfully: 3 pipeline depths x 2 designs x 3 directive settings. All designs were fully routed with zero routing errors and nonnegative hold WNS. Setup timing did not meet the aggressive 5.000 ns target; Fmax below is therefore the requested estimate 1000 / (5.000 - WNS) rather than a timing-closed operating guarantee.

| Stages | Mean LUT overhead | Mean FF overhead | Mean estimated-Fmax change | DSP delta | BRAM delta |
|---:|---:|---:|---:|---:|---:|
$($stageLines -join "`n")

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
"@
$report | Set-Content -LiteralPath (Join-Path $OutputDir 'findings_report.md') -Encoding utf8

Write-Host "Generated paired_overhead.csv, summary_statistics.csv, validation_summary.txt, and findings_report.md"
