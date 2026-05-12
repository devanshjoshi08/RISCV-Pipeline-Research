#!/bin/bash
# runs rv32ui-p-* tests against the pipelined processor using iverilog

TESTS_DIR=${1:-"./riscv-tests"}
RTL_DIR="$(dirname "$0")/../rtl"
TB_DIR="$(dirname "$0")/../tb"

TESTS=(
    rv32ui-p-add rv32ui-p-addi rv32ui-p-and rv32ui-p-andi
    rv32ui-p-auipc rv32ui-p-beq rv32ui-p-bge rv32ui-p-bgeu
    rv32ui-p-blt rv32ui-p-bltu rv32ui-p-bne rv32ui-p-jal
    rv32ui-p-jalr rv32ui-p-lb rv32ui-p-lbu rv32ui-p-lh
    rv32ui-p-lhu rv32ui-p-lui rv32ui-p-lw rv32ui-p-or
    rv32ui-p-ori rv32ui-p-sb rv32ui-p-sh rv32ui-p-sll
    rv32ui-p-slli rv32ui-p-slt rv32ui-p-slti rv32ui-p-sltiu
    rv32ui-p-sltu rv32ui-p-sra rv32ui-p-srai rv32ui-p-srl
    rv32ui-p-srli rv32ui-p-sub rv32ui-p-sw rv32ui-p-xor
    rv32ui-p-xori
)

pass=0; fail=0; total=${#TESTS[@]}
echo "running $total tests"

for t in "${TESTS[@]}"; do
    bin="$TESTS_DIR/isa/$t"
    [ ! -f "$bin" ] && echo "  SKIP $t" && continue

    riscv32-unknown-elf-objcopy -O verilog "$bin" program.hex 2>/dev/null

    iverilog -g2012 -o sim_test \
        "$RTL_DIR"/*.sv "$TB_DIR/rv32i_riscv_tests_tb.sv" 2>/dev/null

    res=$(timeout 10 vvp sim_test 2>/dev/null | grep -E "^(PASS|FAIL|TIMEOUT)")

    if echo "$res" | grep -q "PASS"; then
        echo "  PASS $t"; pass=$((pass+1))
    else
        echo "  FAIL $t ($res)"; fail=$((fail+1))
    fi
    rm -f sim_test program.hex
done

echo "$pass / $total passed, $fail failed"
