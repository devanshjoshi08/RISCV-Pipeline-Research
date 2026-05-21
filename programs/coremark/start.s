# CoreMark startup for bare-metal RV32IM.
# Sets up stack, clears BSS, then calls main.

.section .text.init
.global _start

_start:
    la   sp, __stack_top

    # Clear BSS section
    la   t0, __bss_start
    la   t1, __bss_end
.Lclear_bss:
    bge  t0, t1, .Lbss_done
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    .Lclear_bss
.Lbss_done:

    call main
halt:
    j    halt
