#!/usr/bin/env python3
"""Compute baseline-to-SGF improvements from results_new/results.csv."""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = ROOT / "results_new" / "results.csv"
DEFAULT_CSV = ROOT / "results_new" / "analysis.csv"
DEFAULT_REPORT = ROOT / "results_new" / "analysis_summary.md"
FIELDS = (
    "benchmark", "stage", "misprediction_reduction_pct", "mpki_reduction_pct",
    "cpi_reduction_pct", "speedup_pct", "speedup",
)


def reduction(baseline: float, sgf: float) -> float:
    if baseline == 0:
        if sgf == 0:
            return 0.0
        raise ValueError("cannot compute reduction from a zero baseline")
    return 100.0 * (baseline - sgf) / baseline


def geometric_mean(values: list[float]) -> float:
    if not values or any(value <= 0 for value in values):
        raise ValueError("geometric mean requires positive values")
    return math.exp(math.fsum(math.log(value) for value in values) / len(values))


def load_pairs(path: Path) -> list[dict[str, float | int | str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        source = list(csv.DictReader(handle))
    grouped = {
        (row["benchmark"], int(row["stage"]), row["design"]): row
        for row in source
    }
    rows: list[dict[str, float | int | str]] = []
    errors: list[str] = []
    for benchmark in sorted({row["benchmark"] for row in source}):
        for stage in sorted({int(row["stage"]) for row in source if row["benchmark"] == benchmark}):
            baseline = grouped.get((benchmark, stage, "baseline"))
            sgf = grouped.get((benchmark, stage, "sgf"))
            if baseline is None or sgf is None:
                errors.append(f"{benchmark} stage {stage}: incomplete baseline/SGF pair")
                continue
            for field in ("instructions", "branches", "checksum"):
                if baseline[field] != sgf[field]:
                    errors.append(f"{benchmark} stage {stage}: {field} differs")
            base_cycles, sgf_cycles = int(baseline["cycles"]), int(sgf["cycles"])
            base_misses, sgf_misses = int(baseline["mispredictions"]), int(sgf["mispredictions"])
            base_instructions = int(baseline["instructions"])
            sgf_instructions = int(sgf["instructions"])
            base_mpki = base_misses * 1000.0 / base_instructions
            sgf_mpki = sgf_misses * 1000.0 / sgf_instructions
            base_cpi = base_cycles / base_instructions
            sgf_cpi = sgf_cycles / sgf_instructions
            speedup = base_cycles / sgf_cycles
            rows.append({
                "benchmark": benchmark,
                "stage": stage,
                "misprediction_reduction_pct": reduction(base_misses, sgf_misses),
                "mpki_reduction_pct": reduction(base_mpki, sgf_mpki),
                "cpi_reduction_pct": reduction(base_cpi, sgf_cpi),
                "speedup_pct": 100.0 * (speedup - 1.0),
                "speedup": speedup,
                "mpki_ratio": base_mpki / sgf_mpki if sgf_mpki > 0 else math.inf,
            })
    if errors:
        raise ValueError("invalid input:\n  " + "\n  ".join(errors))
    return rows


def write_csv(rows: list[dict[str, float | int | str]], path: Path) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        for row in rows:
            rendered = {field: row[field] for field in FIELDS}
            for field in FIELDS[2:]:
                rendered[field] = f"{float(row[field]):.6f}"
            writer.writerow(rendered)


def write_report(rows: list[dict[str, float | int | str]], path: Path, source: Path) -> None:
    lines = [
        "# SGF result analysis",
        "",
        f"Source: `{source.relative_to(ROOT)}`",
        "",
        "Positive reductions mean SGF improved the metric. Speedup is calculated as "
        "baseline cycles divided by SGF cycles; speedup percent is `(speedup - 1) × 100`.",
        "",
        "## Per-workload results",
        "",
        "| Benchmark | Stage | Mispred reduction | MPKI reduction | CPI reduction | Speedup |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for row in rows:
        lines.append(
            f"| {row['benchmark']} | {row['stage']} | "
            f"{float(row['misprediction_reduction_pct']):.3f}% | "
            f"{float(row['mpki_reduction_pct']):.3f}% | "
            f"{float(row['cpi_reduction_pct']):.3f}% | "
            f"{float(row['speedup_pct']):.3f}% |"
        )

    lines.extend([
        "",
        "## Stage summaries",
        "",
        "| Stage | Geomean speedup | Arithmetic mean MPKI reduction | Geomean MPKI improvement |",
        "|---:|---:|---:|---:|",
    ])
    for stage in sorted({int(row["stage"]) for row in rows}):
        subset = [row for row in rows if row["stage"] == stage]
        speedup = geometric_mean([float(row["speedup"]) for row in subset])
        arithmetic_mpki = math.fsum(float(row["mpki_reduction_pct"]) for row in subset) / len(subset)
        ratios = [float(row["mpki_ratio"]) for row in subset]
        geometric_mpki = 100.0 * (geometric_mean(ratios) - 1.0)
        lines.append(
            f"| {stage} | {speedup:.6f}× ({(speedup - 1) * 100:.3f}%) | "
            f"{arithmetic_mpki:.3f}% | {geometric_mpki:.3f}% |"
        )

    regressions = [
        row for row in rows
        if float(row["speedup"]) < 1.0 or float(row["mpki_reduction_pct"]) < 0.0
    ]
    lines.extend(["", "## SGF regressions", ""])
    if not regressions:
        lines.append("None.")
    else:
        lines.extend([
            "| Benchmark | Stage | MPKI reduction | Speedup |",
            "|---|---:|---:|---:|",
        ])
        for row in regressions:
            lines.append(
                f"| {row['benchmark']} | {row['stage']} | "
                f"{float(row['mpki_reduction_pct']):.3f}% | "
                f"{float(row['speedup_pct']):.3f}% |"
            )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    args = parser.parse_args()
    rows = load_pairs(args.input.resolve())
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    write_csv(rows, args.csv)
    write_report(rows, args.report, args.input.resolve())
    print(f"Wrote {len(rows)} benchmark/stage comparisons to {args.csv}")
    print(f"Summary: {args.report}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
