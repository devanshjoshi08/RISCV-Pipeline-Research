# Makefile for building official Embench-IoT benchmarks on RV32IM processor.
#
# Prerequisites:
#   1. RISC-V GCC toolchain (xPack riscv-none-elf-gcc)
#   2. Embench-IoT source: git clone https://github.com/embench/embench-iot.git D:/embench-iot
#
# Usage:
#   make              # build all benchmarks
#   make crc32.hex    # build just crc32
#   make install      # copy all hex to programs/asm/
#   make clean

# Toolchain
RISCV_BIN = C:/Users/Joshi/Downloads/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin
PREFIX    = $(RISCV_BIN)/riscv-none-elf
CC        = $(PREFIX)-gcc
OBJCOPY   = $(PREFIX)-objcopy
SIZE      = $(PREFIX)-size

# Embench source (cloned to D: to save C: space)
EMBENCH_DIR = D:/embench-iot

# Benchmarks to build (all pure integer, fit in 16KB imem + 4KB dmem)
BENCHMARKS = aha-mont64 crc32 statemate edn

# Optimization level. Default -O1 (paper baseline); override with `make OPT=-O2`.
OPT ?= -O1

# Compiler flags
CFLAGS  = -march=rv32im_zicsr -mabi=ilp32 $(OPT) -nostdlib -nostartfiles -ffreestanding
CFLAGS += -fno-builtin -Wno-implicit-function-declaration
CFLAGS += -I$(EMBENCH_DIR)/support -I$(EMBENCH_DIR)/src
CFLAGS += -DWARMUP_HEAT=1 -DCPU_MHZ=1 -DGLOBAL_SCALE_FACTOR=1
LDFLAGS = -T link_embench.ld -Wl,--no-relax -Wl,--gc-sections

# Common sources
COMMON_SRCS = start.s main.c board.c baremetal_stubs.c $(EMBENCH_DIR)/support/beebsc.c

# Hex targets
HEX_TARGETS = $(addsuffix .hex, $(BENCHMARKS))

all: $(HEX_TARGETS)
	@echo "=== All benchmarks built ==="
	@for h in $(HEX_TARGETS); do echo "  $$h"; done

# Pattern rule: build each benchmark
# The benchmark source is in $(EMBENCH_DIR)/src/<name>/*.c
%.elf: $(COMMON_SRCS) link_embench.ld
	@echo "--- Building $* ---"
	$(CC) $(CFLAGS) -I$(EMBENCH_DIR)/src/$* $(LDFLAGS) -o $@ \
		$(COMMON_SRCS) $(EMBENCH_DIR)/src/$*/*.c
	$(SIZE) $@

%_raw.hex: %.elf
	$(OBJCOPY) -O verilog $< $@

%.hex: %_raw.hex
	python ../../tools/verilog_to_wordhex.py $< $@.full
	@head -4096 $@.full > $@
	python ../../tools/extract_dmem_hex.py $< $*_data.hex
	@echo "  -> $@ + $*_data.hex"

# Install all hex files to programs/asm/ with embench_ prefix
install: $(HEX_TARGETS)
	@for h in $(HEX_TARGETS); do \
		base=$${h%.hex}; \
		cp $$h ../asm/embench_$$h; \
		cp $${base}_data.hex ../asm/embench_$${base}_data.hex; \
		echo "  Installed embench_$$h + data"; \
	done

sizes: $(addsuffix .elf, $(BENCHMARKS))
	@echo "=== Benchmark sizes ==="
	@for e in $(addsuffix .elf, $(BENCHMARKS)); do \
		echo "--- $$e ---"; \
		$(SIZE) $$e; \
	done

clean:
	rm -f *.elf *.hex *.dump *.tmp

.PHONY: all clean install sizes
