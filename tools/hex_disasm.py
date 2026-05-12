#!/usr/bin/env python3
# usage: python hex_disasm.py <file.hex>

import sys

R_FUNCT = {
    (0b000, 0b0000000): "add", (0b000, 0b0100000): "sub",
    (0b001, 0b0000000): "sll", (0b010, 0b0000000): "slt",
    (0b011, 0b0000000): "sltu", (0b100, 0b0000000): "xor",
    (0b101, 0b0000000): "srl", (0b101, 0b0100000): "sra",
    (0b110, 0b0000000): "or", (0b111, 0b0000000): "and",
}
I_FUNCT = {0b000: "addi", 0b001: "slli", 0b010: "slti", 0b011: "sltiu",
           0b100: "xori", 0b110: "ori", 0b111: "andi"}
BRANCH_FUNCT = {0b000: "beq", 0b001: "bne", 0b100: "blt",
                0b101: "bge", 0b110: "bltu", 0b111: "bgeu"}
LOAD_FUNCT = {0b000: "lb", 0b001: "lh", 0b010: "lw", 0b100: "lbu", 0b101: "lhu"}
STORE_FUNCT = {0b000: "sb", 0b001: "sh", 0b010: "sw"}

def sext(val, bits):
    return val - (1 << bits) if val & (1 << (bits - 1)) else val

def decode(w, addr):
    op = w & 0x7F
    rd = (w >> 7) & 0x1F
    f3 = (w >> 12) & 0x7
    rs1 = (w >> 15) & 0x1F
    rs2 = (w >> 20) & 0x1F
    f7 = (w >> 25) & 0x7F

    if op == 0b0110011:
        return f"{R_FUNCT.get((f3, f7), '???')} x{rd}, x{rs1}, x{rs2}"
    elif op == 0b0010011:
        imm = sext((w >> 20) & 0xFFF, 12)
        if f3 == 0b101:
            return f"{'srai' if f7 & 0x20 else 'srli'} x{rd}, x{rs1}, {rs2}"
        return f"{I_FUNCT.get(f3, '???')} x{rd}, x{rs1}, {imm}"
    elif op == 0b0000011:
        imm = sext((w >> 20) & 0xFFF, 12)
        return f"{LOAD_FUNCT.get(f3, '???')} x{rd}, {imm}(x{rs1})"
    elif op == 0b0100011:
        imm = sext(((w >> 25) << 5) | ((w >> 7) & 0x1F), 12)
        return f"{STORE_FUNCT.get(f3, '???')} x{rs2}, {imm}(x{rs1})"
    elif op == 0b1100011:
        imm = (((w>>31)&1)<<12) | (((w>>7)&1)<<11) | (((w>>25)&0x3F)<<5) | (((w>>8)&0xF)<<1)
        imm = sext(imm, 13)
        return f"{BRANCH_FUNCT.get(f3, '???')} x{rs1}, x{rs2}, {imm} (-> 0x{addr+imm:04x})"
    elif op == 0b1101111:
        imm = (((w>>31)&1)<<20) | (((w>>12)&0xFF)<<12) | (((w>>20)&1)<<11) | (((w>>21)&0x3FF)<<1)
        imm = sext(imm, 21)
        return f"jal x{rd}, {imm} (-> 0x{addr+imm:04x})"
    elif op == 0b1100111:
        return f"jalr x{rd}, x{rs1}, {sext((w>>20) & 0xFFF, 12)}"
    elif op == 0b0110111:
        return f"lui x{rd}, 0x{(w & 0xFFFFF000) >> 12:05x}"
    elif op == 0b0010111:
        return f"auipc x{rd}, 0x{(w & 0xFFFFF000) >> 12:05x}"
    return f"??? (0x{w:08x})"

if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <file.hex>")
    sys.exit(1)

with open(sys.argv[1]) as f:
    lines = [l.strip() for l in f if l.strip()]

print(f"{'ADDR':>6}  {'HEX':>10}  INSTRUCTION")
print("-" * 44)
for i, line in enumerate(lines):
    w = int(line, 16)
    print(f"0x{i*4:04x}  0x{w:08x}  {decode(w, i*4)}")
