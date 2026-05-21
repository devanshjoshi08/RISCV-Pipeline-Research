#!/usr/bin/env python3
"""Extract DMEM-mapped sections from a verilog hex file.

The full hex file has both IMEM data (addresses 0x0000-0x3FFF) and
DMEM data (addresses 0x10000+). This script extracts only the DMEM
portion and remaps addresses to start at 0 (since dmem uses addr[11:2]).

Usage: python extract_dmem_hex.py full_hex output_dmem_hex [dmem_base_addr]
"""

import sys

def extract(infile, outfile, dmem_base=0x10000):
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

    # Filter to only DMEM addresses and remap
    dmem_bytes = {}
    for addr, val in bytes_data.items():
        if addr >= dmem_base:
            # Remap: dmem uses addr[11:2], so mask to low 12 bits
            dmem_addr = addr - dmem_base
            if dmem_addr < 4096:  # 4KB DMEM
                dmem_bytes[dmem_addr] = val

    if not dmem_bytes:
        print(f"No DMEM data found (base=0x{dmem_base:X})")
        # Write empty file (1024 words of zeros)
        with open(outfile, 'w') as f:
            for _ in range(1024):
                f.write("00000000\n")
        return

    max_addr = max(dmem_bytes.keys())
    num_words = (max_addr + 4) // 4

    with open(outfile, 'w') as f:
        for w in range(num_words):
            addr = w * 4
            b0 = dmem_bytes.get(addr, 0)
            b1 = dmem_bytes.get(addr + 1, 0)
            b2 = dmem_bytes.get(addr + 2, 0)
            b3 = dmem_bytes.get(addr + 3, 0)
            word = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
            f.write(f"{word:08X}\n")

    print(f"Extracted {num_words} DMEM words: {infile} -> {outfile}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} input_raw.hex output_dmem.hex [dmem_base]")
        sys.exit(1)
    base = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x10000
    extract(sys.argv[1], sys.argv[2], base)
