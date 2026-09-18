[CmdletBinding()]
param(
    [ValidateSet('PrepareOnly', 'Smoke', 'All')]
    [string]$Mode = 'Smoke',
    [string]$Repo = '',
    [string]$VivadoBat = ''
)

$ErrorActionPreference = 'Stop'
$OutRoot = $PSScriptRoot

if (-not $Repo) {
    $packagedRepo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $executedRepo = 'C:\Users\shafi\Documents\Codex\2026-09-17\can-x20\work\github_sgf_evaluation_automation'
    if (Test-Path -LiteralPath (Join-Path $packagedRepo '.git')) {
        $Repo = $packagedRepo
    } elseif (Test-Path -LiteralPath (Join-Path $executedRepo '.git')) {
        $Repo = $executedRepo
    } else {
        throw 'Repository not found. Pass -Repo with the RISCV-Pipeline-Research checkout path.'
    }
}

function Add-SourceSet {
    param(
        [System.Collections.Generic.List[object]]$Rows,
        [int]$Stage,
        [string]$Design,
        [string]$Top,
        [string]$Predictor,
        [string[]]$Extras
    )

    $common = @(
        'rtl/pkg_riscv.sv', 'rtl/alu.sv', 'rtl/mdu.sv', 'rtl/control.sv',
        'rtl/branch_unit.sv', 'rtl/csr_unit.sv', 'rtl/regfile.sv',
        'rtl/imm_gen.sv', 'rtl/pc.sv', 'rtl/icache.sv', 'rtl/imem.sv',
        'rtl/dmem.sv', 'rtl/pipe_if_id.sv', 'rtl/pipe_id_ex.sv',
        'rtl/pipe_ex_mem.sv', 'rtl/pipe_mem_wb.sv', 'rtl/pipe_ex1_ex2.sv'
    )
    $ordered = @($common) + @("rtl/$Predictor") + @($Extras)
    for ($i = 0; $i -lt $ordered.Count; $i++) {
        $Rows.Add([pscustomobject]@{
            stage = $Stage
            design = $Design
            top = $Top
            ordinal = $i + 1
            relative_path = $ordered[$i]
        })
    }
}

$rows = [System.Collections.Generic.List[object]]::new()
Add-SourceSet $rows 6 baseline rv32i_pipeline_top branch_predictor.sv @(
    'rtl/forwarding_unit.sv', 'rtl/hazard_unit.sv', 'rtl/rv32i_pipeline_top.sv'
)
Add-SourceSet $rows 6 sgf rv32i_pipeline_sgf_top branch_predictor_sgf.sv @(
    'rtl/forwarding_unit.sv', 'rtl/hazard_unit.sv', 'rtl/rv32i_pipeline_sgf_top.sv'
)
Add-SourceSet $rows 7 baseline rv32i_pipeline_7stage_top branch_predictor.sv @(
    'rtl_7stage/forwarding_unit.sv', 'rtl_7stage/hazard_unit.sv',
    'rtl_7stage/pipe_if1_if2.sv', 'rtl_7stage/rv32i_pipeline_7stage_top.sv'
)
Add-SourceSet $rows 7 sgf rv32i_pipeline_7stage_sgf_top branch_predictor_sgf.sv @(
    'rtl_7stage/forwarding_unit.sv', 'rtl_7stage/hazard_unit.sv',
    'rtl_7stage/pipe_if1_if2.sv', 'rtl_7stage/rv32i_pipeline_7stage_sgf_top.sv'
)
Add-SourceSet $rows 8 baseline rv32i_pipeline_8stage_top branch_predictor.sv @(
    'rtl_8stage/forwarding_unit.sv', 'rtl_8stage/hazard_unit.sv',
    'rtl_8stage/pipe_if1_if2.sv', 'rtl_8stage/pipe_mem1_mem2.sv',
    'rtl_8stage/rv32i_pipeline_8stage_top.sv'
)
Add-SourceSet $rows 8 sgf rv32i_pipeline_8stage_sgf_top branch_predictor_sgf.sv @(
    'rtl_8stage/forwarding_unit.sv', 'rtl_8stage/hazard_unit.sv',
    'rtl_8stage/pipe_if1_if2.sv', 'rtl_8stage/pipe_mem1_mem2.sv',
    'rtl_8stage/rv32i_pipeline_8stage_sgf_top.sv'
)

$xdcRelative = 'scripts/synth_clk_ooc.xdc'
$required = @($rows.relative_path | Sort-Object -Unique) + $xdcRelative
$missing = foreach ($relative in $required) {
    $native = $relative.Replace('/', [IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath (Join-Path $Repo $native) -PathType Leaf)) { $relative }
}
if ($missing) {
    throw "Candidate snapshot is incomplete. Missing:`n$($missing -join "`n")"
}

$membershipPath = Join-Path $OutRoot 'source_membership.tsv'
$membershipLines = @('stage' + "`t" + 'design' + "`t" + 'top' + "`t" + 'ordinal' + "`t" + 'relative_path')
$membershipLines += $rows | ForEach-Object {
    "{0}`t{1}`t{2}`t{3}`t{4}" -f $_.stage, $_.design, $_.top, $_.ordinal, $_.relative_path
}
[IO.File]::WriteAllLines($membershipPath, $membershipLines, [Text.UTF8Encoding]::new($false))

$hashRows = foreach ($relative in $required | Sort-Object -Unique) {
    $native = $relative.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $full = Join-Path $Repo $native
    [pscustomobject]@{
        relative_path = $relative
        sha256 = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant()
        bytes = (Get-Item -LiteralPath $full).Length
    }
}
$hashRows | Export-Csv -LiteralPath (Join-Path $OutRoot 'source_hashes.csv') -NoTypeInformation -Encoding utf8

$gitCommit = 'unavailable_archive_without_git_metadata'
$gitStatus = 'unavailable_archive_without_git_metadata'
if (Test-Path -LiteralPath (Join-Path $Repo '.git')) {
    $gitCommit = (& git -C $Repo rev-parse HEAD).Trim()
    $gitStatus = ((& git -C $Repo status --short) -join [Environment]::NewLine)
    if (-not $gitStatus) { $gitStatus = 'clean' }
}
$osDescription = [Runtime.InteropServices.RuntimeInformation]::OSDescription
$provenance = @(
    "prepared_utc=$([DateTime]::UtcNow.ToString('o'))"
    "repo=$Repo"
    "git_commit=$gitCommit"
    "git_status=$gitStatus"
    "os=$osDescription"
    'part=xc7a35tcpg236-1'
    'clock_period_ns=5.000'
    'snapshot_note=GitHub branch sgf-evaluation-automation supplied by the user; RTL matches the handoff revision because HEAD only adds evaluation artifacts after af884ea.'
)
[IO.File]::WriteAllLines((Join-Path $OutRoot 'provenance.txt'), $provenance, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $OutRoot 'git_commit.txt'), $gitCommit, [Text.UTF8Encoding]::new($false))

Write-Host "Prepared source membership, hashes, and provenance in $OutRoot"
if ($Mode -eq 'PrepareOnly') { return }

if (-not $VivadoBat) {
    $command = Get-Command vivado.bat -ErrorAction SilentlyContinue
    if (-not $command) { $command = Get-Command vivado -ErrorAction SilentlyContinue }
    if ($command) { $VivadoBat = $command.Source }
}
if (-not $VivadoBat -or -not (Test-Path -LiteralPath $VivadoBat -PathType Leaf)) {
    throw 'Vivado was not found. Install a compatible Vivado release with Artix-7/7-series device support, then pass -VivadoBat C:\path\to\vivado.bat.'
}

$tcl = Join-Path $OutRoot 'run_experiment.tcl'
$log = Join-Path $OutRoot ("vivado_{0}.log" -f $Mode.ToLowerInvariant())
$journal = Join-Path $OutRoot ("vivado_{0}.jou" -f $Mode.ToLowerInvariant())
$outDrive = 'V:'
$repoDrive = 'R:'
if ((Test-Path "$outDrive\") -or (Test-Path "$repoDrive\")) {
    throw "Temporary drive letters $outDrive and/or $repoDrive are already in use."
}
& subst.exe $outDrive $OutRoot
if ($LASTEXITCODE -ne 0) { throw "Could not map $outDrive to $OutRoot" }
& subst.exe $repoDrive $Repo
if ($LASTEXITCODE -ne 0) {
    & subst.exe $outDrive /D
    throw "Could not map $repoDrive to $Repo"
}
Push-Location "$outDrive\"
try {
    & $VivadoBat -mode batch -source "$outDrive/run_experiment.tcl" -log "$outDrive/vivado_$($Mode.ToLowerInvariant()).log" -journal "$outDrive/vivado_$($Mode.ToLowerInvariant()).jou" -tclargs "$repoDrive/" "$outDrive/" $Mode
    if ($LASTEXITCODE -ne 0) { throw "Vivado exited with code $LASTEXITCODE. See $log" }

    $expectedRuns = if ($Mode -eq 'Smoke') { 1 } else { 18 }
    $resultCsv = Join-Path $OutRoot 'hardware_cost_runs.csv'
    $actualRuns = if (Test-Path -LiteralPath $resultCsv) { @(Import-Csv -LiteralPath $resultCsv | Where-Object status -eq 'success').Count } else { 0 }
    if ($actualRuns -lt $expectedRuns) {
        throw "Vivado did not produce all expected successful rows ($actualRuns/$expectedRuns). See $log"
    }
}
finally {
    Pop-Location
    & subst.exe $repoDrive /D | Out-Null
    & subst.exe $outDrive /D | Out-Null
}
