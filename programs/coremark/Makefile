# Makefile for building official EEMBC CoreMark on RV32IM processor.
#
# Prerequisites:
#   1. RISC-V GCC toolchain (xPack riscv-none-elf-gcc)
#   2. Official CoreMark source: git clone https://github.com/eembc/coremark.git D:/coremark
#
# Usage:
#   make                    # build coremark.hex (10 iterations)
#   make ITERATIONS=100     # more iterations
#   make clean

# Toolchain
RISCV_BIN = C:/Users/Joshi/Downloads/xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64/xpack-riscv-none-elf-gcc-15.2.0-1/bin
PREFIX    = $(RISCV_BIN)/riscv-none-elf
CC        = $(PREFIX)-gcc
OBJCOPY   = $(PREFIX)-objcopy
OBJDUMP   = $(PREFIX)-objdump
SIZE      = $(PREFIX)-size

# Path to official CoreMark source (cloned to D: to save C: space)
COREMARK_DIR ?= D:/coremark

# Number of iterations for simulation (10 = fast, 100 = more accurate)
ITERATIONS ?= 10

# Optimization level. Default -O1 (paper baseline); override with `make OPT=-O2`.
OPT ?= -O1

# Compiler flags
CFLAGS  = -march=rv32im_zicsr -mabi=ilp32 $(OPT) -nostdlib -nostartfiles -ffreestanding
CFLAGS += -fno-builtin
CFLAGS += -DITERATIONS=$(ITERATIONS) -DPERFORMANCE_RUN=1
FLAGS_DESC = "-march=rv32im_zicsr -mabi=ilp32 $(OPT) -nostdlib -ffreestanding"
CFLAGS += -DFLAGS_STR='$(FLAGS_DESC)'
CFLAGS += -I$(COREMARK_DIR) -I.
LDFLAGS = -T link_coremark.ld -Wl,--no-relax -Wl,--gc-sections

# CoreMark source files (from official EEMBC repo)
COREMARK_SRCS = \
    $(COREMARK_DIR)/core_list_join.c \
    $(COREMARK_DIR)/core_main.c \
    $(COREMARK_DIR)/core_matrix.c \
    $(COREMARK_DIR)/core_state.c \
    $(COREMARK_DIR)/core_util.c

# Our porting layer
PORT_SRCS = start.s core_portme.c

all: coremark.hex

coremark.elf: $(PORT_SRCS) $(COREMARK_SRCS) link_coremark.ld core_portme.h
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(PORT_SRCS) $(COREMARK_SRCS)
	$(SIZE) $@

coremark_raw.hex: coremark.elf
	$(OBJCOPY) -O verilog $< $@

coremark_full.hex: coremark_raw.hex
	python ../../tools/verilog_to_wordhex.py $< $@

coremark.hex: coremark_full.hex
	head -4096 $< > $@
	@echo "Generated $@ (4096 words = 16KB for imem_16k)"

coremark.dump: coremark.elf
	$(OBJDUMP) -d $< > $@

# Copy to programs/asm for testbench use
install: coremark.hex
	cp coremark.hex ../asm/coremark_official.hex
	@echo "Installed to programs/asm/coremark_official.hex"

clean:
	rm -f *.elf *.hex *.dump

.PHONY: all clean install
