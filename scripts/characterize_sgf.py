#!/usr/bin/env python3
"""Observe speculative-vs-committed GHR lookups without changing the DUT."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
from pathlib import Path
import sys

import run_sgf_evaluation as evaluation


OUT = evaluation.OUTPUT
CATEGORIES = ("sgf_only_correct", "committed_only_correct", "both_correct", "both_wrong")
BIN_FIELDS = (
    "sgf_counter", "shadow_counter", "depth", "ghr_diff", "btb_hit", "issued", "issued_agree", "issued_differ",
    "agree", "differ", *CATEGORIES,
)


def parse_line(line: str) -> dict[str, int]:
    return {key: int(value) for key, value in (word.split("=") for word in line.split()[1:])}


def compile_observer(item: evaluation.Variant, backend: str) -> Path:
    build = evaluation.WORK / "build" / backend / item.key
    build.mkdir(parents=True, exist_ok=True)
    defines = ["-DSGF_CHARACTERIZE", f"-DDUT_MODULE={item.top}", f"-I{evaluation.ROOT / 'tb'}"]
    if item.stage == 6:
        defines.append("-DSGF_SIX_STAGE")
    sources = [*(str(path) for path in item.sources), str(evaluation.TB)]
    if backend == "verilator":
        executable = build / "sim_observer"
        command = [
            "verilator", "--binary", "--timing", "-Wno-fatal", "-j", "0",
            "--top-module", "sgf_evaluation_tb", "--Mdir", str(build),
            "-o", executable.name, *defines, *sources,
        ]
    else:
        executable = build / "observer.vvp"
        command = ["iverilog", "-g2012", "-s", "sgf_evaluation_tb", "-o", str(executable), *defines, *sources]
    log = evaluation.run_checked(command, cwd=evaluation.ROOT)
    (evaluation.LOGS / f"compile_{backend}_{item.key}.log").write_text(log, encoding="utf-8")
    return executable


def characterize(bench, item, executable, args, reference):
    result = evaluation.simulate(bench, item, executable, args.backend, args)
    key = (bench.name, str(item.stage), "sgf")
    if key not in reference:
        raise evaluation.EvaluationError(f"missing uninstrumented reference for {key}")
    for field in ("cycles", "instructions", "branches", "mispredictions", "checksum"):
        expected = reference[key][field]
        expected = int(expected, 16) if field == "checksum" else int(expected)
        if result[field] != expected:
            raise evaluation.EvaluationError(f"instrumentation changed {key} {field}: {result[field]} != {expected}")
    log = (evaluation.LOGS / f"{args.backend}_{bench.name}_{item.key}.log").read_text(encoding="utf-8")
    bins = [dict(benchmark=bench.name, stage=item.stage, **parse_line(line))
            for line in log.splitlines() if line.startswith("CHAR ")]
    totals = [parse_line(line) for line in log.splitlines() if line.startswith("CHAR_TOTAL ")]
    if len(totals) != 1 or not bins:
        raise evaluation.EvaluationError(f"missing characterization data for {key}")
    total = dict(benchmark=bench.name, stage=item.stage, **totals[0])
    for row in bins:
        resolved = sum(row[field] for field in CATEGORIES)
        if (row["agree"] != row["both_correct"] + row["both_wrong"] or
                row["differ"] != row["sgf_only_correct"] + row["committed_only_correct"] or
                row["issued"] != row["issued_agree"] + row["issued_differ"] or
                resolved > row["issued"] or
                ((not row["ghr_diff"] or not row["btb_hit"]) and
                 (row["differ"] != 0 or row["issued_differ"] != 0))):
            raise evaluation.EvaluationError(f"invalid observer bin for {key}: {row}")
    if (sum(row["issued"] for row in bins) != total["issued"] or
            total["issued"] != total["resolved"] + total["outstanding"] + total["squashed"]):
        raise evaluation.EvaluationError(f"issued/resolved/squash accounting failure for {key}")
    for field in ("issued_agree", "issued_differ", "agree", "differ", *CATEGORIES):
        total[field] = sum(row[field] for row in bins)
    if total["resolved"] != sum(total[field] for field in CATEGORIES):
        raise evaluation.EvaluationError(f"category partition failure for {key}")
    if total["sgf_wrong"] != total["both_wrong"] + total["committed_only_correct"]:
        raise evaluation.EvaluationError(f"SGF miss accounting failure for {key}")
    if total["shadow_wrong"] != total["both_wrong"] + total["sgf_only_correct"]:
        raise evaluation.EvaluationError(f"shadow miss accounting failure for {key}")
    total["oracle_wrong"] = total["both_wrong"]
    total["oracle_correct"] = total["resolved"] - total["both_wrong"]
    total["oracle_accuracy_pct"] = 100 * total["oracle_correct"] / total["resolved"]
    total["oracle_saved_vs_sgf"] = total["committed_only_correct"]
    total["prediction_change_pct"] = 100 * total["differ"] / total["resolved"]
    total["accepted_prediction_change_pct"] = 100 * total["issued_differ"] / total["issued"]
    if total["issued_agree"] + total["issued_differ"] != total["issued"]:
        raise evaluation.EvaluationError(f"issued partition failure for {key}")
    total["oracle_miss_reduction_pct"] = 100 * total["oracle_saved_vs_sgf"] / total["sgf_wrong"] if total["sgf_wrong"] else 0
    return bins, total


def write_csv(path: Path, rows, fields):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            output = dict(row)
            if "sgf_counter" in output:
                output["sgf_counter"] = f"{row['sgf_counter']:02b}"
                output["shadow_counter"] = f"{row['shadow_counter']:02b}"
            writer.writerow({field: output[field] for field in fields})


def report(bins, totals, backend):
    lines = [
        "# Speculative GHR characterization",
        "",
        f"Backend: {backend}. All instrumented runs match the five uninstrumented `results.csv` fields exactly.",
        "",
        "## Measurement contract",
        "",
        "A prediction is captured when an actual conditional-branch instruction is accepted into IF/ID "
        "(IF2/ID at stages 7/8), not for repeated stalled lookups or NOP bubbles. Metadata follows the "
        "real stall/flush precedence through ID, EX1 and EX2. PC and actual prediction are asserted at "
        "resolution; observed SGF misses and resolved branches are asserted against the total CSR counters.",
        "",
        "The shadow reads the **same SGF-trained PHT and BTB**, at `PC[7:2] XOR committed_ghr`, "
        "with the same BTB gating/type rules. It has no independent training, history updates, or writes "
        "to DUT state. Both PHT counters and GHR equality are sampled **before** the prediction edge's "
        "training updates. BTB misses are included (both effective predictions are not-taken).",
        "",
        "Depth is the number of older accepted conditional branches in ID/EX1/EX2 immediately before "
        "the capture edge, including a branch resolving on that edge. It excludes JAL/JALR and "
        "squashed branches. The DUT's actual committed GHR is used unchanged, including its existing JAL updates.",
        "",
        "Correctness is available only for resolved branches; accepted wrong-path branches discarded "
        "by flushes are counted as squashed, not classified as wrong. All counts cover the **whole program** "
        "including startup and termination, not just the benchmark's CSR-delta timing region. "
        "Consequently totals need not equal `results.csv` benchmark-region branch/miss counts.",
        "",
        "Reproduce with `python3 scripts/characterize_sgf.py` (Verilator default). "
        "Use `--backend icarus`, `--benchmarks NAME ...`, or `--output-dir PATH` for isolated smoke tests. "
        "No ordinary evaluation output is rewritten.",
        "",
        "## Main findings",
        "",
        "| Stage | Resolved prediction changes | Helps | Hurts | Net correctness gain vs shadow | Oracle additional miss reduction vs SGF |",
        "|---:|---:|---:|---:|---:|---:|",
    ]
    for stage in sorted({t["stage"] for t in totals}):
        subset = [t for t in totals if t["stage"] == stage]
        resolved = sum(t["resolved"] for t in subset)
        helps = sum(t["sgf_only_correct"] for t in subset)
        hurts = sum(t["committed_only_correct"] for t in subset)
        wrong = sum(t["sgf_wrong"] for t in subset)
        lines.append(f"| {stage} | {100 * (helps + hurts) / resolved:.3f}% | {helps} | {hurts} | "
                     f"{helps - hurts} branches | {100 * hurts / wrong if wrong else 0:.3f}% |")
    lines += [
        "",
        "Higher unresolved depth often accompanies more prediction changes, but a correlation with "
        "disagreement is not the same as predicting which source is correct. Compare the help/hurt "
        "rates below and the fixed-bin selector bounds: a depth-only selector may have no net benefit "
        "even where it strongly predicts disagreement. SGF PHT confidence must likewise be evaluated "
        "by state and direction, rather than treating all weak or saturated counters alike.",
        "",
        "## Per-workload comparison",
        "",
        "| Benchmark | Stage | Resolved | Resolved changes | Resolved changes % | Accepted changes % | SGF-only correct (helps) | Committed-only correct (hurts) | Both correct | Both wrong | Squashed | Oracle saved vs SGF |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for t in totals:
        lines.append(f"| {t['benchmark']} | {t['stage']} | {t['resolved']} | {t['differ']} | "
                     f"{t['prediction_change_pct']:.3f}% | {t['accepted_prediction_change_pct']:.3f}% | {t['sgf_only_correct']} | "
                     f"{t['committed_only_correct']} | {t['both_correct']} | {t['both_wrong']} | "
                     f"{t['squashed']} | {t['oracle_saved_vs_sgf']} ({t['oracle_miss_reduction_pct']:.3f}% of SGF misses) |")
    lines += ["", "## Confidence, depth and history strata", "",
              "Each row aggregates resolved branches across workloads at one stage. Helps/hurts are "
              "the two disagreement categories. The last column estimates how often choosing the "
              "committed-GHR shadow would help **given a disagreement** in that stratum. "
              "This is descriptive in-sample evidence, not a fitted or out-of-sample selector.", ""]
    for dimension, label in (("sgf_counter", "SGF PHT counter"), ("shadow_counter", "Shadow PHT counter"),
                             ("depth", "Unresolved depth"), ("ghr_diff", "GHR differs")):
        lines += [f"### {label}", "",
                  "| Stage | State | Resolved | Changes % | Helps | Hurts | Shadow-correct given disagreement |",
                  "|---:|---|---:|---:|---:|---:|---:|"]
        for stage in sorted({row["stage"] for row in bins}):
            for state in sorted({row[dimension] for row in bins if row["stage"] == stage}):
                subset = [row for row in bins if row["stage"] == stage and row[dimension] == state]
                count = sum(sum(row[f] for f in CATEGORIES) for row in subset)
                helps = sum(row["sgf_only_correct"] for row in subset)
                hurts = sum(row["committed_only_correct"] for row in subset)
                changes = helps + hurts
                rendered = f"{state:02b}" if "counter" in dimension else str(state)
                rate = f"{100 * hurts / changes:.3f}%" if changes else "n/a"
                lines.append(f"| {stage} | {rendered} | {count} | {100 * changes / count if count else 0:.3f}% | {helps} | {hurts} | {rate} |")
        lines.append("")
    lines += ["## Predictive signal assessment", "",
              "The following idealized **in-sample fixed-bin selectors** choose one direction source "
              "for each stratum, using the observed majority of helps vs hurts. They pool workloads "
              "within each stage and save `max(0, hurts - helps)` misses per stratum relative to always "
              "using SGF. Thus they quantify available confidence/depth signal but are optimistic "
              "training-set estimates, not proposed architectural changes or validated classifiers.", "",
              "| Stage | Selector features | Misses saved vs SGF | Per-branch oracle saves | Fraction of oracle captured |",
              "|---:|---|---:|---:|---:|"]
    for stage in sorted({r["stage"] for r in bins}):
        oracle = sum(r["committed_only_correct"] for r in bins if r["stage"] == stage)
        for features in (("sgf_counter",), ("depth",), ("sgf_counter", "depth"),
                         ("sgf_counter", "shadow_counter", "depth", "ghr_diff", "btb_hit")):
            strata = {}
            for r in bins:
                if r["stage"] != stage:
                    continue
                key = tuple(r[f] for f in features)
                helps, hurts = strata.get(key, (0, 0))
                strata[key] = (helps + r["sgf_only_correct"], hurts + r["committed_only_correct"])
            saved = sum(max(0, hurts - helps) for helps, hurts in strata.values())
            lines.append(f"| {stage} | {', '.join(features)} | {saved} | {oracle} | {100 * saved / oracle if oracle else 0:.3f}% |")
    lines += ["", "## Oracle interpretation", "",
              "An ideal direction selector on this fixed SGF execution/training stream can eliminate "
              "every committed-only-correct miss, leaving exactly `both_wrong` misses. Its correctness "
              "upper bound is `resolved - both_wrong`. This is **not** a counterfactual cycle/speedup "
              "bound: selecting a different prediction would change future fetches, histories and PHT "
              "training. The shadow is not a separately trained baseline predictor.", "",
              "In particular, zero shadow disagreements do not prove SGF has no effect versus a "
              "standalone baseline: SGF and a baseline can have different PHT training and execution "
              "trajectories. An ideal selector between the two lookups observed here cannot repair "
              "those historical training differences.", "",
              "The CSV preserves the joint SGF/shadow counter states, depth, GHR equality and BTB hit "
              "for all categories, enabling per-workload confidence/depth analysis without losing strata."]
    (OUT / "characterization_report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    global OUT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", choices=("icarus", "verilator"), default="verilator")
    parser.add_argument("--benchmarks", nargs="+")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--max-cycles", type=int, default=50_000_000)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--output-dir", type=Path, default=OUT)
    args = parser.parse_args()
    OUT = args.output_dir.resolve()
    OUT.mkdir(parents=True, exist_ok=True)
    args.resume = False
    # Reuse benchmark selection, simulation, timeout and result parsing, but
    # isolate all observer builds/logs from ordinary simulator evaluation.
    evaluation.WORK = evaluation.WORK / "characterization"
    evaluation.LOGS = evaluation.LOGS / "characterization"
    evaluation.LOGS.mkdir(parents=True, exist_ok=True)
    benches = evaluation.benchmarks()
    if args.benchmarks:
        unknown = set(args.benchmarks) - {b.name for b in benches}
        if unknown:
            raise evaluation.EvaluationError(f"unknown benchmarks: {sorted(unknown)}")
        benches = [b for b in benches if b.name in args.benchmarks]
    with (evaluation.OUTPUT / "results.csv").open(newline="", encoding="utf-8") as handle:
        reference = {(r["benchmark"], r["stage"], r["design"]): r for r in csv.DictReader(handle)}
    variants = [evaluation.variant(stage, "sgf") for stage in (6, 7, 8)]
    executables = {item.key: compile_observer(item, args.backend) for item in variants}
    bins, totals = [], []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        futures = {executor.submit(characterize, b, item, executables[item.key], args, reference): (b, item)
                   for b in benches for item in variants}
        for future in as_completed(futures):
            b, item = futures[future]
            new_bins, total = future.result()
            bins.extend(new_bins); totals.append(total)
            print(f"PASS {b.name} stage {item.stage}: {total['resolved']} resolved", flush=True)
    bins.sort(key=lambda r: (r["benchmark"], r["stage"], *(r[f] for f in BIN_FIELDS[:5])))
    totals.sort(key=lambda r: (r["benchmark"], r["stage"]))
    write_csv(OUT / "characterization.csv", bins, ("benchmark", "stage", *BIN_FIELDS))
    write_csv(OUT / "characterization_totals.csv", totals, tuple(totals[0]))
    report(bins, totals, args.backend)
    print(f"Wrote characterization CSVs and report under {OUT}")


if __name__ == "__main__":
    try:
        main()
    except (evaluation.EvaluationError, OSError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
