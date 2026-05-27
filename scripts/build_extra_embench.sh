#!/usr/bin/env bash
# Build additional Embench-IoT kernels at -O1 into programs/asm/embench_<name>.hex
# (+ _data.hex). The bare-metal harness (main.c, board.c, baremetal_stubs.c,
# start.s, link script) lives under programs/embench/ and is generic across
# kernels. The kernel sources and the Embench support library are not bundled;
# point EMBENCH_SRC at an Embench-IoT checkout (github.com/embench/embench-iot)
# providing src/<kernel>/*.c and support/beebsc.c.
#
# Usage:
#   RISCV_BIN=/path/to/bin EMBENCH_SRC=/path/to/embench-iot \
#     bash scripts/build_extra_embench.sh [kernel1 kernel2 ...]
#
# Output (per kernel K): programs/asm/embench_K.hex and programs/asm/embench_K_data.hex
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASM="$ROOT/programs/asm"
HARNESS="$ROOT/programs/embench"        # main.c, board.c, baremetal_stubs.c, start.s, link script

RISCV_BIN="${RISCV_BIN:-/path/to/riscv-none-elf-gcc/bin}"
EMBENCH_SRC="${EMBENCH_SRC:-/path/to/embench-iot}"   # full Embench-IoT checkout (has src/ + support/)
CC="$RISCV_BIN/riscv-none-elf-gcc"
OBJCOPY="$RISCV_BIN/riscv-none-elf-objcopy"
PY="${PY:-python}"
OPT="${OPT:--O1}"
LINK="${LINK:-link_embench.ld}"         # use link_embench_16k.ld if a kernel overflows

KERNELS=("$@")
[ ${#KERNELS[@]} -eq 0 ] && KERNELS=(huffbench sglib-combined)

[ -f "$CC" ] || [ -f "$CC.exe" ] || { echo "ERROR: gcc not found at $CC  (set RISCV_BIN)"; exit 1; }
[ -d "$EMBENCH_SRC/src" ] || { echo "ERROR: Embench source not at $EMBENCH_SRC/src  (set EMBENCH_SRC to an embench-iot checkout)"; exit 1; }
[ -f "$EMBENCH_SRC/support/beebsc.c" ] || { echo "ERROR: $EMBENCH_SRC/support/beebsc.c missing"; exit 1; }
command -v "$PY" >/dev/null || { echo "ERROR: python not found (set PY)"; exit 1; }

for K in "${KERNELS[@]}"; do
  SRC="$EMBENCH_SRC/src/$K"
  if [ ! -d "$SRC" ]; then echo "SKIP $K: no source at $SRC"; continue; fi
  echo "[$OPT] $K"
  if (
    cd "$HARNESS"
    "$CC" -march=rv32im_zicsr -mabi=ilp32 $OPT -nostdlib -nostartfiles -ffreestanding -fno-builtin \
      -Wno-implicit-function-declaration \
      -I "$EMBENCH_SRC/support" -I "$EMBENCH_SRC/src" -I "$SRC" \
      -DWARMUP_HEAT=1 -DCPU_MHZ=1 -DGLOBAL_SCALE_FACTOR=1 \
      -T "$LINK" -Wl,--no-relax -Wl,--gc-sections \
      -o "${K}.elf" start.s main.c board.c baremetal_stubs.c \
      "$EMBENCH_SRC/support/beebsc.c" "$SRC"/*.c
    "$OBJCOPY" -O verilog "${K}.elf" "${K}_raw.hex"
    "$PY" "$ROOT/tools/verilog_to_wordhex.py" "${K}_raw.hex" "${K}_full.hex"
    head -4096 "${K}_full.hex" > "${K}.hex"
    "$PY" "$ROOT/tools/extract_dmem_hex.py" "${K}_raw.hex" "${K}_data.hex"
    cp "${K}.hex"      "$ASM/embench_${K}.hex"
    cp "${K}_data.hex" "$ASM/embench_${K}_data.hex"
  ); then
    echo "  -> $ASM/embench_${K}.hex (+ _data.hex)"
  else
    echo "  FAILED $K -- skipping (likely too large for the 16 KB IMEM, or a build error above)"
  fi
  ( cd "$HARNESS"; rm -f "${K}.elf" "${K}_raw.hex" "${K}_full.hex" "${K}.hex" "${K}_data.hex" ) 2>/dev/null || true
done

echo "Done. Now run them with:  source scripts/run_extra_embench.tcl  (from the Vivado Tcl console)"
