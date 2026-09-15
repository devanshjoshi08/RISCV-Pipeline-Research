#!/usr/bin/env python3
"""Run the 6/7/8-stage baseline-vs-SGF benchmark matrix with Icarus."""

from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import html
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "results_new"
WORK = OUTPUT / "work"
LOGS = OUTPUT / "logs"
TB = ROOT / "tb" / "sgf_evaluation_tb.sv"
RESULT_RE = re.compile(
    r"^RESULT cycles=(\d+) instructions=(\d+) branches=(\d+) "
    r"mispredictions=(\d+) checksum=([0-9a-fA-F]{8})$",
    re.MULTILINE,
)


class EvaluationError(RuntimeError):
    pass


@dataclass(frozen=True)
class Benchmark:
    name: str
    program: Path
    data: Path | None = None


@dataclass(frozen=True)
class Variant:
    stage: int
    design: str
    top: str
    sources: tuple[Path, ...]

    @property
    def key(self) -> str:
        return f"{self.stage}_{self.design}"


SHARED = tuple(
    ROOT / "rtl" / name
    for name in (
        "pkg_riscv.sv", "alu.sv", "mdu.sv", "control.sv", "branch_unit.sv",
        "csr_unit.sv", "regfile.sv", "imm_gen.sv", "pc.sv", "icache.sv",
        "imem.sv", "dmem.sv", "pipe_if_id.sv", "pipe_id_ex.sv",
        "pipe_ex_mem.sv", "pipe_mem_wb.sv", "pipe_ex1_ex2.sv",
    )
)


def variant(stage: int, design: str) -> Variant:
    predictor = ROOT / "rtl" / (
        "branch_predictor_sgf.sv" if design == "sgf" else "branch_predictor.sv"
    )
    if stage == 6:
        top = "rv32i_pipeline_sgf_top" if design == "sgf" else "rv32i_pipeline_top"
        extra = (
            ROOT / "rtl" / "forwarding_unit.sv",
            ROOT / "rtl" / "hazard_unit.sv",
            ROOT / "rtl" / f"{top}.sv",
        )
    elif stage == 7:
        top = f"rv32i_pipeline_7stage{'_sgf' if design == 'sgf' else ''}_top"
        extra = (
            ROOT / "rtl_7stage" / "forwarding_unit.sv",
            ROOT / "rtl_7stage" / "hazard_unit.sv",
            ROOT / "rtl_7stage" / "pipe_if1_if2.sv",
            ROOT / "rtl_7stage" / f"{top}.sv",
        )
    elif stage == 8:
        top = f"rv32i_pipeline_8stage{'_sgf' if design == 'sgf' else ''}_top"
        extra = (
            ROOT / "rtl_8stage" / "forwarding_unit.sv",
            ROOT / "rtl_8stage" / "hazard_unit.sv",
            ROOT / "rtl_8stage" / "pipe_if1_if2.sv",
            ROOT / "rtl_8stage" / "pipe_mem1_mem2.sv",
            ROOT / "rtl_8stage" / f"{top}.sv",
        )
    else:
        raise ValueError(stage)
    return Variant(stage, design, top, SHARED + (predictor,) + extra)


def benchmarks() -> list[Benchmark]:
    asm = ROOT / "programs" / "asm"
    found = [
        Benchmark("bench_branch_heavy", asm / "bench_branch_heavy.hex"),
        Benchmark("coremark", asm / "coremark_official.hex", ROOT / "programs/coremark/data.hex"),
    ]
    for program in sorted(asm.glob("embench_*.hex")):
        stem = program.stem
        if stem.endswith("_data") or stem.endswith("_o2"):
            continue
        name = stem.removeprefix("embench_")
        data = program.with_name(f"{stem}_data.hex")
        found.append(Benchmark(name, program, data if data.exists() else None))
    # A few prebuilt Embench images live only in programs/embench. Prefer the
    # canonical programs/asm copy above when both locations contain a kernel.
    known = {bench.name for bench in found}
    embench = ROOT / "programs" / "embench"
    for program in sorted(embench.glob("*.hex")):
        stem = program.stem
        if stem.endswith(("_data", "_full")) or stem in known:
            continue
        data = program.with_name(f"{stem}_data.hex")
        found.append(Benchmark(stem, program, data if data.exists() and data.stat().st_size else None))
    missing = [str(path) for bench in found for path in (bench.program,) if not path.is_file()]
    if missing:
        raise EvaluationError("missing prebuilt benchmark image(s): " + ", ".join(missing))
    return found


def run_checked(command: list[str], *, cwd: Path, timeout: int | None = None) -> str:
    try:
        completed = subprocess.run(
            command, cwd=cwd, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise EvaluationError(f"host timeout running {' '.join(command[:2])}") from exc
    if completed.returncode:
        raise EvaluationError(
            f"command failed ({completed.returncode}): {' '.join(command)}\n{completed.stdout}"
        )
    return completed.stdout


def compile_variant(item: Variant) -> Path:
    build_dir = WORK / "build"
    build_dir.mkdir(parents=True, exist_ok=True)
    executable = build_dir / f"{item.key}.vvp"
    command = [
        "iverilog", "-g2012", "-Wall", "-s", "sgf_evaluation_tb",
        f"-DDUT_MODULE={item.top}", "-o", str(executable),
        *(str(path) for path in item.sources), str(TB),
    ]
    output = run_checked(command, cwd=ROOT)
    (LOGS / f"compile_{item.key}.log").write_text(output, encoding="utf-8")
    return executable


def simulate(bench: Benchmark, item: Variant, executable: Path, args: argparse.Namespace) -> dict[str, object]:
    run_dir = WORK / "runs" / bench.name / item.key
    run_dir.mkdir(parents=True, exist_ok=True)
    log_path = LOGS / f"{bench.name}_{item.key}.log"
    if args.resume and log_path.is_file() and RESULT_RE.search(log_path.read_text(encoding="utf-8")):
        output = log_path.read_text(encoding="utf-8")
    else:
        shutil.copy2(bench.program, run_dir / "program.hex")
        command = ["vvp", str(executable), f"+MAX_CYCLES={args.max_cycles}"]
        if bench.data:
            command.append(f"+DATA_HEX={bench.data.resolve()}")
        output = run_checked(command, cwd=run_dir, timeout=args.timeout)
        log_path.write_text(output, encoding="utf-8")
    match = RESULT_RE.search(output)
    if not match:
        raise EvaluationError(f"no parseable RESULT line for {bench.name} {item.key}; see {log_path}")
    cycles, instructions, branches, misses = (int(value) for value in match.groups()[:4])
    checksum = int(match.group(5), 16)
    if not instructions or not branches:
        raise EvaluationError(f"invalid zero counter for {bench.name} {item.key}; see {log_path}")
    return {
        "benchmark": bench.name,
        "stage": item.stage,
        "design": item.design,
        "cycles": cycles,
        "instructions": instructions,
        "branches": branches,
        "mispredictions": misses,
        "cpi": cycles / instructions,
        "mpki": misses * 1000.0 / instructions,
        "mispredict_rate": misses * 100.0 / branches,
        "checksum": checksum,
    }


def validate_pairs(rows: list[dict[str, object]]) -> None:
    grouped = {(str(r["benchmark"]), int(r["stage"]), str(r["design"])): r for r in rows}
    errors: list[str] = []
    for benchmark in sorted({str(row["benchmark"]) for row in rows}):
        for stage in (6, 7, 8):
            baseline = grouped.get((benchmark, stage, "baseline"))
            sgf = grouped.get((benchmark, stage, "sgf"))
            if baseline is None or sgf is None:
                errors.append(f"{benchmark} stage {stage}: missing baseline or SGF row")
                continue
            for field in ("instructions", "branches", "checksum"):
                if baseline[field] != sgf[field]:
                    left = f"0x{baseline[field]:08x}" if field == "checksum" else str(baseline[field])
                    right = f"0x{sgf[field]:08x}" if field == "checksum" else str(sgf[field])
                    errors.append(f"{benchmark} stage {stage}: {field} mismatch ({left} != {right})")
    if errors:
        raise EvaluationError("baseline/SGF equivalence check failed:\n  " + "\n  ".join(errors))


FIELDS = (
    "benchmark", "stage", "design", "cycles", "instructions", "branches",
    "mispredictions", "cpi", "mpki", "mispredict_rate", "checksum",
)


def write_csv(rows: list[dict[str, object]]) -> None:
    temporary = OUTPUT / ".results.csv.tmp"
    with temporary.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        for row in rows:
            rendered = dict(row)
            for field in ("cpi", "mpki", "mispredict_rate"):
                rendered[field] = f"{float(row[field]):.6f}"
            rendered["checksum"] = f"0x{int(row['checksum']):08x}"
            writer.writerow(rendered)
    os.replace(temporary, OUTPUT / "results.csv")


def write_plot(rows: list[dict[str, object]], metric: str, label: str, filename: str) -> None:
    names = list(dict.fromkeys(str(row["benchmark"]) for row in rows))
    series = [(stage, design) for stage in (6, 7, 8) for design in ("baseline", "sgf")]
    values = {(str(r["benchmark"]), int(r["stage"]), str(r["design"])): float(r[metric]) for r in rows}
    width, height = max(1050, 150 * len(names)), 620
    left, right, top, bottom = 78, 24, 65, 150
    plot_w, plot_h = width - left - right, height - top - bottom
    maximum = max(values.values()) * 1.12 or 1.0
    colors = {6: "#4472c4", 7: "#ed7d31", 8: "#70ad47"}
    group_w = plot_w / len(names)
    bar_w = min(18.0, group_w / 8.0)
    gap = 2.0
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text{font-family:Arial,sans-serif;fill:#222}.axis{stroke:#333;stroke-width:1}.grid{stroke:#ddd;stroke-width:1}</style>',
        f'<text x="{width/2}" y="28" text-anchor="middle" font-size="20">{html.escape(label)}: baseline vs SGF</text>',
    ]
    for tick in range(6):
        value = maximum * tick / 5
        y = top + plot_h - plot_h * tick / 5
        parts.append(f'<line class="grid" x1="{left}" y1="{y:.1f}" x2="{width-right}" y2="{y:.1f}"/>')
        parts.append(f'<text x="{left-8}" y="{y+4:.1f}" text-anchor="end" font-size="11">{value:.2f}</text>')
    parts.append(f'<line class="axis" x1="{left}" y1="{top}" x2="{left}" y2="{top+plot_h}"/>')
    parts.append(f'<line class="axis" x1="{left}" y1="{top+plot_h}" x2="{width-right}" y2="{top+plot_h}"/>')
    for index, name in enumerate(names):
        center = left + group_w * (index + 0.5)
        total = len(series) * bar_w + (len(series) - 1) * gap
        start = center - total / 2
        for series_index, (stage, design) in enumerate(series):
            value = values[(name, stage, design)]
            h = plot_h * value / maximum
            x = start + series_index * (bar_w + gap)
            opacity = "1" if design == "baseline" else "0.55"
            parts.append(f'<rect x="{x:.1f}" y="{top+plot_h-h:.1f}" width="{bar_w:.1f}" height="{h:.1f}" fill="{colors[stage]}" fill-opacity="{opacity}"/>')
        parts.append(f'<text x="{center:.1f}" y="{top+plot_h+18}" text-anchor="end" font-size="11" transform="rotate(-35 {center:.1f} {top+plot_h+18})">{html.escape(name)}</text>')
    legend_y = height - 28
    for i, (stage, design) in enumerate(series):
        x = left + i * 145
        opacity = "1" if design == "baseline" else "0.55"
        parts.append(f'<rect x="{x}" y="{legend_y-12}" width="16" height="12" fill="{colors[stage]}" fill-opacity="{opacity}"/>')
        parts.append(f'<text x="{x+22}" y="{legend_y-1}" font-size="12">{stage}-stage {design}</text>')
    parts.append('</svg>')
    (OUTPUT / filename).write_text("\n".join(parts) + "\n", encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmarks", nargs="+", metavar="NAME", help="run only named benchmarks")
    parser.add_argument("--max-cycles", type=int, default=50_000_000, help="simulated-cycle timeout per run")
    parser.add_argument("--timeout", type=int, default=900, help="host timeout in seconds per run")
    parser.add_argument("--jobs", type=int, default=1, help="simulations to run concurrently")
    parser.add_argument("--resume", action="store_true", help="reuse existing successful per-run logs")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        raise EvaluationError("Icarus Verilog is required (missing iverilog or vvp in PATH)")
    selected = benchmarks()
    if args.benchmarks:
        requested = set(args.benchmarks)
        selected = [bench for bench in selected if bench.name in requested]
        unknown = requested - {bench.name for bench in selected}
        if unknown:
            raise EvaluationError("unknown benchmark(s): " + ", ".join(sorted(unknown)))

    OUTPUT.mkdir(exist_ok=True)
    LOGS.mkdir(exist_ok=True)
    variants = [variant(stage, design) for stage in (6, 7, 8) for design in ("baseline", "sgf")]
    print(f"Compiling {len(variants)} Icarus variants...", flush=True)
    executables = {item.key: compile_variant(item) for item in variants}

    rows: list[dict[str, object]] = []
    total = len(selected) * len(variants)
    tasks = [(bench, item) for bench in selected for item in variants]
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        pending = {
            executor.submit(simulate, bench, item, executables[item.key], args): (bench, item)
            for bench, item in tasks
        }
        for index, future in enumerate(as_completed(pending), start=1):
            bench, item = pending[future]
            rows.append(future.result())
            print(f"[{index:02d}/{total:02d}] {bench.name}: {item.stage}-stage {item.design}", flush=True)

    validate_pairs(rows)
    rows.sort(key=lambda row: (str(row["benchmark"]), int(row["stage"]), str(row["design"])))
    write_csv(rows)
    write_plot(rows, "cpi", "CPI", "cpi_comparison.svg")
    write_plot(rows, "mpki", "MPKI", "mpki_comparison.svg")
    print(f"PASS: validated {len(rows)//2} baseline/SGF pairs")
    print(f"Results: {OUTPUT / 'results.csv'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except EvaluationError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
