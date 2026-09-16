# SGF simulator validation report

## Scope and outcome

The current committed RTL was evaluated with Icarus Verilog 13.0 and Verilator
5.052 using the same `tb/sgf_evaluation_tb.sv` harness, prebuilt program/data
hex files, memory depths, reset sequence, halt rule, and result parser.

The required cross-check covered these four workloads:

- `bench_branch_heavy`
- `coremark`
- `huffbench`
- `crc32`

Each workload was run on the 6-, 7-, and 8-stage baseline and SGF designs. All
24 design/workload configurations matched exactly between simulators for:

- cycles
- instructions
- branches
- mispredictions
- checksum/result word

There are no simulator-specific exceptions. The 48 raw simulator rows are in
`results_new/simulator_crosscheck.csv`. The command used was:

```bash
python3 scripts/run_sgf_evaluation.py --backend both \
  --benchmarks bench_branch_heavy coremark huffbench crc32 --resume --jobs 6
```

The runner treats any difference in any of the five fields as a fatal error.
As an additional check beyond the requested scope, the full 60-row Verilator
matrix in `results_new/results_verilator.csv` was compared with the full Icarus
`results_new/results.csv`; all 60 configurations also match in all five fields.

## 6-stage SGF CoreMark discrepancy

The current canonical evaluation reports:

| Configuration | Cycles | Instructions | Branches | Mispredictions | Result word |
|---|---:|---:|---:|---:|---:|
| Current SGF, `CONF_FILTER=0` | 5,152,395 | 2,893,145 | 719,810 | 101,418 | `0x0000000a` |
| Diagnostic SGF, `CONF_FILTER=1` | 5,199,762 | 2,893,145 | 719,810 | 117,207 | `0x0000000a` |
| Old committed 6-stage result | 5,199,762 | 2,893,145 | 719,810 | 117,207 | 10 iterations |

The diagnostic `CONF_FILTER=1` run exactly reproduces both historical values,
not just the misprediction count. Its log is retained as
`results_new/logs/coremark_6_sgf_conf_filter_1.log` (logs are intentionally
ignored build evidence).

### Exact effective RTL difference

The current predictor parameter defaults to `CONF_FILTER=0`. In this shipped
configuration every predicted conditional branch shifts its prediction into
the speculative GHR. With `CONF_FILTER=1`, the shift is suppressed when the
indexing PHT counter is saturated (`2'b00` or `2'b11`):

```systemverilog
if (is_conditional_branch && !flush && !(CONF_FILTER && pht_saturated))
  spec_ghr <= {spec_ghr[PHT_IDX-2:0], predict_taken};
```

That confidence-filter configuration is the exact behavioral/configuration
difference producing 117,207 rather than 101,418. The benchmark image, CoreMark
data image, 6-stage top, reset sequence, memory initialization, and termination
rule do not account for the discrepancy: the current harness reproduces the old
tuple by changing only this build-time parameter.

Repository history confirms that the `coremark_official.hex` and CoreMark data
blobs at the old result commit are the same blobs used now, and the versioned
6-stage SGF top has not changed since its introduction. The old testbench used a
2,048-word DMEM and XSim, whereas the current shared harness uses a 4,096-word
DMEM and was run under Icarus/Verilator; nevertheless the diagnostic run with
the current harness reproduces the old cycle and misprediction counts exactly.
Those testbench capacity and simulator differences therefore are not causal.

This mapping is independently recorded by the repository's existing
`scripts/run_sgf_filter_7stage.tcl` and
`results/sgf_filter_7stage_results.log`: they identify 101,418 as
`CONF_FILTER=0` and 117,207 as `CONF_FILTER=1` for the same canonical CoreMark
instruction/branch stream.

### Historical provenance limitation

The old result was produced by `scripts/run_sgf_6stage.tcl`. At the result
commit (`7502e28`), that script set `project_dir` to `scripts/` and selected RTL
from `scripts/rtl/`. That directory is not present in the commit tree. The
versioned canonical RTL is under repository-root `rtl/`.

Consequently, Git cannot recover the exact text of the local RTL copy used for
the old run. The committed log's exact match to the filtered diagnostic shows
that its *effective* predictor behavior was the confidence-filtered behavior,
but the old script/result pair does not contain enough provenance to determine
whether that missing local file hard-coded the filter or applied an equivalent
local edit. Later portable scripts corrected RTL selection to repository-root
`rtl/` and explicitly parameterized the filter.

The old number should therefore not be used as evidence for the current default
SGF configuration. No predictor or pipeline behavior was changed during this
investigation.

## Result analysis

`scripts/analyze_sgf_results.py` reads `results_new/results.csv` and writes:

- `results_new/analysis.csv`: misprediction, MPKI, and CPI reduction percentages,
  plus speedup percentage and ratio for every benchmark/stage pair.
- `results_new/analysis_summary.md`: per-stage geomean speedup, arithmetic mean
  MPKI reduction, geomean MPKI improvement, and SGF regressions.

For MPKI, the arithmetic summary is the arithmetic mean of per-pair reduction
percentages. The geometric summary is `(geomean(baseline MPKI / SGF MPKI) - 1)
× 100`, which remains well-defined for mixtures of improvements and regressions
as long as measured MPKI is positive.
