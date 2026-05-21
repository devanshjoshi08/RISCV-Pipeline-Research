#!/usr/bin/env python3
"""Convert objcopy -O verilog byte-oriented hex to word-oriented hex for $readmemh.

Input:  @00000000
        17 11 00 00 13 01 01 00 ...

Output: 00001117
        00010113
        ...

Words are little-endian (RISC-V byte order).
"""

import sys

def convert(infile, outfile):
    bytes_data = {}
    base_addr = 0

    with open(infile, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('@'):
                base_addr = int(line[1:], 16)
                continue
            tokens = line.split()
            for i, tok in enumerate(tokens):
                bytes_data[base_addr + i] = int(tok, 16)
            base_addr += len(tokens)

    if not bytes_data:
        print("No data found")
        return

    max_addr = max(bytes_data.keys())
    num_words = (max_addr + 4) // 4

    with open(outfile, 'w') as f:
        for w in range(num_words):
            addr = w * 4
            b0 = bytes_data.get(addr, 0)
            b1 = bytes_data.get(addr + 1, 0)
            b2 = bytes_data.get(addr + 2, 0)
            b3 = bytes_data.get(addr + 3, 0)
            # Little-endian: byte 0 is LSB
            word = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
            f.write(f"{word:08X}\n")

    print(f"Converted {num_words} words: {infile} -> {outfile}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input.hex output.hex")
        sys.exit(1)
    convert(sys.argv[1], sys.argv[2])
