# run_sgf_nlp.tcl - Orthogonality test: baseline vs SGF vs NLP vs SGF+NLP
# (7-stage, CoreMark, identical harness + hex). Tests whether SGF (Mechanism-B
# misprediction fix) and NLP (IF2-bubble fix) are additive or interfere.
#
# Validation oracle: every variant must execute identical instruction (2,893,145)
# and branch (719,810) counts; only cycles/mispredictions change.
# Disk-safe: each project dir + tmp .xilwvdat is deleted after the run.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set rtl7_dir    "$github_dir/rtl_7stage"
set nlp_dir     "$project_dir/rtl_nlp"
set asm_dir     "$github_dir/programs/asm"
set work_root   "$project_dir/vivado_sgfnlp"
set part        "xc7a35tcpg236-1"
set log_file    "$project_dir/sgf_nlp_results.log"

set ::env(TEMP)   "D:/RISCV-Vivado/tmp"
set ::env(TMP)    "D:/RISCV-Vivado/tmp"
set ::env(TMPDIR) "D:/RISCV-Vivado/tmp"
file mkdir "D:/RISCV-Vivado/tmp"
file mkdir $work_root

# common modules (standard pipe registers; SGF forwards its checkpoint in-top)
set common [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl7_dir/forwarding_unit.sv" "$rtl7_dir/hazard_unit.sv" "$rtl7_dir/pipe_if1_if2.sv" \
]
set bp     "$rtl_dir/branch_predictor.sv"
set bpsgf  "$rtl_dir/branch_predictor_sgf.sv"

set rtl_base    [concat $common [list $bp    "$rtl7_dir/rv32i_pipeline_7stage_top.sv"]]
set rtl_nlp     [concat $common [list $bp    "$nlp_dir/rv32i_pipeline_7stage_nlp_top.sv"]]
set rtl_sgf     [concat $common [list $bpsgf "$rtl_dir/rv32i_pipeline_7stage_sgf_top.sv"]]
set rtl_sgfnlp  [concat $common [list $bpsgf "$nlp_dir/rv32i_pipeline_7stage_sgf_nlp_top.sv"]]

set cm_hex  "$asm_dir/coremark_official.hex"
set cm_data "$github_dir/programs/coremark/data.hex"

proc write_tb {filepath top_module} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module sgfnlp_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
    puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
    puts $fd "  end"
    puts $fd "  initial clk = 0;  always #5 clk = ~clk;"
    puts $fd "  int halt_count;  logic \[31:0\] prev_pc;"
    puts $fd "  always_ff @(posedge clk) begin"
    puts $fd "    prev_pc <= debug_pc;"
    puts $fd "    if (!rst_n) halt_count <= 0;"
    puts $fd "    else if (debug_pc\[31:3\] == prev_pc\[31:3\]) halt_count <= halt_count + 1;"
    puts $fd "    else halt_count <= 0;"
    puts $fd "  end"
    puts $fd "  initial begin"
    puts $fd "    \$display(\"=== CoreMark: $top_module ===\");"
    puts $fd "    rst_n = 0; repeat (5) @(posedge clk); rst_n = 1;"
    puts $fd "    fork wait (halt_count > 1000); repeat (500000000) @(posedge clk); join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\", dut.u_dmem.mem\[0\]/dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_one {proj rtl_files top_module} {
    global part work_root log_file cm_hex cm_data
    set wdir "$work_root/$proj"
    puts "\n  >>> $proj ($top_module) ..."
    create_project $proj $wdir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$wdir/${proj}_tb.sv"
    write_tb $tb_path $top_module
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top sgfnlp_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    set sim_dir "$wdir/$proj.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $cm_hex  "$sim_dir/program.hex"
    file copy -force $cm_data "$sim_dir/data.hex"
    launch_simulation
    run -all
    set sim_log "$sim_dir/simulate.log"
    if {[file exists $sim_log]} {
        set fi [open $sim_log r]; set fo [open $log_file a]
        puts $fo "--- $proj ---"
        while {[gets $fi line] >= 0} { puts $fo $line }
        puts $fo ""; close $fi; close $fo
    }
    close_sim -quiet
    close_project -quiet
    catch {file delete -force $wdir}
    catch {foreach f [glob -nocomplain "D:/RISCV-Vivado/tmp/*.xilwvdat"] {file delete -force $f}}
}

set fd [open $log_file w]
puts $fd "=== Orthogonality: baseline / SGF / NLP / SGF+NLP (7-stage CoreMark) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

run_one "base7"    $rtl_base   "rv32i_pipeline_7stage_top"
run_one "sgf7"     $rtl_sgf    "rv32i_pipeline_7stage_sgf_top"
run_one "nlp7"     $rtl_nlp    "rv32i_pipeline_7stage_nlp_top"
run_one "sgfnlp7"  $rtl_sgfnlp "rv32i_pipeline_7stage_sgf_nlp_top"

puts "\n=== SGF+NLP ORTHOGONALITY RUN COMPLETE -> $log_file ===\n"
