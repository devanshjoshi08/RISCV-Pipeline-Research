#!/usr/bin/env bash
# Recompile CoreMark and statemate at -O2 for the compiler-sensitivity experiment
# (TC review item #3). Default builds remain -O1; this produces *_o2 hex variants
# installed alongside the -O1 ones so the run TCL can pick them up.
#
# Usage:  bash scripts/build_O2_benchmarks.sh
# Output: programs/asm/coremark_official_o2.hex
#         programs/asm/embench_statemate_o2.hex (+ _data.hex)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASM="$ROOT/programs/asm"

echo "[O2] CoreMark"
make -C "$ROOT/programs/coremark" clean
make -C "$ROOT/programs/coremark" OPT=-O2 coremark.hex
cp "$ROOT/programs/coremark/coremark.hex" "$ASM/coremark_official_o2.hex"

echo "[O2] statemate"
make -C "$ROOT/programs/embench" clean
make -C "$ROOT/programs/embench" OPT=-O2 statemate.hex
cp "$ROOT/programs/embench/statemate.hex"      "$ASM/embench_statemate_o2.hex"
cp "$ROOT/programs/embench/statemate_data.hex" "$ASM/embench_statemate_o2_data.hex"

# Restore the -O1 defaults so the tree is left as shipped.
make -C "$ROOT/programs/coremark" clean
make -C "$ROOT/programs/embench"  clean

echo "[O2] done. Now run scripts/run_O2_7stage.tcl in the Vivado Tcl console."
echo "[O2] Record branch/instruction counts so IBD at -O2 can be compared to -O1."
