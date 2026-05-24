#!/usr/bin/env bash
# Recompile CoreMark and statemate at -O2 for the compiler-sensitivity experiment
# (TC review item B). Make-free: invokes the toolchain directly so it runs on a
# machine without `make` (e.g. Cygwin/Git bash). Reproduces the Makefile recipes.
#
# Usage:  bash scripts/build_O2_benchmarks.sh
# Output: programs/asm/coremark_official_o2.hex
#         programs/asm/embench_statemate_o2.hex (+ _data.hex)
#
# Override paths with env vars if your install differs, e.g.:
#   RISCV_BIN=/path/to/bin COREMARK_DIR=D:/coremark bash scripts/build_O2_benchmarks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASM="$ROOT/programs/asm"

RISCV_BIN="${RISCV_BIN:-C:/Users/Joshi/Downloads/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin}"
COREMARK_DIR="${COREMARK_DIR:-D:/coremark}"
EMBENCH_DIR="${EMBENCH_DIR:-D:/embench-iot}"
CC="$RISCV_BIN/riscv-none-elf-gcc"
OBJCOPY="$RISCV_BIN/riscv-none-elf-objcopy"
PY="${PY:-python}"
OPT="-O2"

[ -f "$CC" ] || [ -f "$CC.exe" ] || { echo "ERROR: gcc not found at $CC  (set RISCV_BIN)"; exit 1; }
[ -d "$COREMARK_DIR" ] || { echo "ERROR: CoreMark source not at $COREMARK_DIR  (set COREMARK_DIR)"; exit 1; }
[ -d "$EMBENCH_DIR" ]  || { echo "ERROR: Embench source not at $EMBENCH_DIR  (set EMBENCH_DIR)"; exit 1; }
command -v "$PY" >/dev/null || { echo "ERROR: python not found (set PY)"; exit 1; }

echo "[O2] CoreMark"
( cd "$ROOT/programs/coremark"
  "$CC" -march=rv32im_zicsr -mabi=ilp32 $OPT -nostdlib -nostartfiles -ffreestanding -fno-builtin \
    -DITERATIONS=10 -DPERFORMANCE_RUN=1 '-DFLAGS_STR="-march=rv32im_zicsr -mabi=ilp32 -O2"' \
    -I"$COREMARK_DIR" -I. -T link_coremark.ld -Wl,--no-relax -Wl,--gc-sections \
    -o coremark_o2.elf start.s core_portme.c \
    "$COREMARK_DIR"/core_list_join.c "$COREMARK_DIR"/core_main.c "$COREMARK_DIR"/core_matrix.c \
    "$COREMARK_DIR"/core_state.c "$COREMARK_DIR"/core_util.c
  "$OBJCOPY" -O verilog coremark_o2.elf coremark_o2_raw.hex
  "$PY" ../../tools/verilog_to_wordhex.py coremark_o2_raw.hex coremark_o2_full.hex
  head -4096 coremark_o2_full.hex > coremark_o2.hex
  "$PY" ../../tools/extract_dmem_hex.py coremark_o2_raw.hex coremark_o2_data.hex
  cp coremark_o2.hex      "$ASM/coremark_official_o2.hex"
  cp coremark_o2_data.hex "$ASM/coremark_official_o2_data.hex"
  rm -f coremark_o2.elf coremark_o2_raw.hex coremark_o2_full.hex coremark_o2.hex coremark_o2_data.hex )
echo "  -> $ASM/coremark_official_o2.hex (+ _data.hex)"

echo "[O2] statemate"
( cd "$ROOT/programs/embench"
  "$CC" -march=rv32im_zicsr -mabi=ilp32 $OPT -nostdlib -nostartfiles -ffreestanding -fno-builtin \
    -Wno-implicit-function-declaration -I"$EMBENCH_DIR"/support -I"$EMBENCH_DIR"/src \
    -DWARMUP_HEAT=1 -DCPU_MHZ=1 -DGLOBAL_SCALE_FACTOR=1 -I"$EMBENCH_DIR"/src/statemate \
    -T link_embench.ld -Wl,--no-relax -Wl,--gc-sections \
    -o statemate_o2.elf start.s main.c board.c baremetal_stubs.c \
    "$EMBENCH_DIR"/support/beebsc.c "$EMBENCH_DIR"/src/statemate/*.c
  "$OBJCOPY" -O verilog statemate_o2.elf statemate_o2_raw.hex
  "$PY" ../../tools/verilog_to_wordhex.py statemate_o2_raw.hex statemate_o2_full.hex
  head -4096 statemate_o2_full.hex > statemate_o2.hex
  "$PY" ../../tools/extract_dmem_hex.py statemate_o2_raw.hex statemate_o2_data.hex
  cp statemate_o2.hex      "$ASM/embench_statemate_o2.hex"
  cp statemate_o2_data.hex "$ASM/embench_statemate_o2_data.hex"
  rm -f statemate_o2.elf statemate_o2_raw.hex statemate_o2_full.hex statemate_o2.hex statemate_o2_data.hex )
echo "  -> $ASM/embench_statemate_o2.hex (+ _data.hex)"

echo "[O2] done. Now in the Vivado Tcl console:"
echo "     source $ROOT/scripts/run_O2_7stage.tcl"
