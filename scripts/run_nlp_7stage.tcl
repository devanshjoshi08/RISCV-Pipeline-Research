# run_nlp_7stage.tcl
# Measures the NLP-augmented 7-stage pipeline against the baseline 7-stage,
# to convert the §VI-D IF2-bubble counterfactual from a projection into a
# measured result. Runs both variants through the IDENTICAL harness so the
# comparison controls for any toolchain/file differences.
#
# Validation oracle: the NLP is performance-only, so it MUST reproduce the
# baseline misprediction count exactly (CoreMark 147,760) and the same
# instruction/branch counts, with cycles strictly lower.
#
# Waveform logging is left at XSim defaults (no log_wave / no $dumpvars), and
# every .sim dir is deleted after its result is scraped, so this cannot refill
# the disk.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
# Use the CANONICAL 7-stage RTL from the GitHub repo (a stale local rtl_7stage copy is a
# stale pre-bugfix version that does not reproduce the paper's baseline).
set rtl7_dir    "$github_dir/rtl_7stage"
set nlp_dir     "$project_dir/rtl_nlp"
set asm_dir     "$github_dir/programs/asm"
set work_root   "$project_dir/vivado_nlp"
set part        "xc7a35tcpg236-1"
set log_file    "$project_dir/nlp_results.log"

# Keep XSim temp on D:
set ::env(TEMP)   ".vivado_work/tmp"
set ::env(TMP)    ".vivado_work/tmp"
set ::env(TMPDIR) ".vivado_work/tmp"
file mkdir ".vivado_work/tmp"
file mkdir $work_root

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/branch_predictor.sv" \
    "$rtl7_dir/forwarding_unit.sv" "$rtl7_dir/hazard_unit.sv" \
    "$rtl7_dir/pipe_if1_if2.sv" \
]

# 7-stage support files reused by both variants come from $rtl7_dir.
set baseline_rtl [concat $shared_rtl [list "$rtl7_dir/rv32i_pipeline_7stage_top.sv"]]
set nlp_rtl      [concat $shared_rtl [list "$nlp_dir/rv32i_pipeline_7stage_nlp_top.sv"]]

proc write_tb {filepath top_module bench_name} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module nlp_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
    puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
    puts $fd "  end"
    puts $fd "  initial clk = 0;"
    puts $fd "  always #5 clk = ~clk;"
    puts $fd "  int halt_count;"
    puts $fd "  logic \[31:0\] prev_pc;"
    puts $fd "  always_ff @(posedge clk) begin"
    puts $fd "    prev_pc <= debug_pc;"
    puts $fd "    if (!rst_n) halt_count <= 0;"
    puts $fd "    else if (debug_pc\[31:3\] == prev_pc\[31:3\]) halt_count <= halt_count + 1;"
    puts $fd "    else halt_count <= 0;"
    puts $fd "  end"
    puts $fd "  initial begin"
    puts $fd "    \$display(\"=== $bench_name: $top_module ===\");"
    puts $fd "    rst_n = 0;"
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 1000);"
    puts $fd "      repeat (500000000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    \$display(\"  Iterations:     %0d\", dut.u_dmem.mem\[4\]);"
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    if (dut.u_dmem.mem\[2\] != 0)"
    puts $fd "      \$display(\"  Mispredict%%:    %0d.%02d%%\","
    puts $fd "        (dut.u_dmem.mem\[3\] * 100) / dut.u_dmem.mem\[2\],"
    puts $fd "        ((dut.u_dmem.mem\[3\] * 10000) / dut.u_dmem.mem\[2\]) % 100);"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_one {proj rtl_files top_module hex_file data_hex bench_name} {
    global part work_root log_file
    set wdir "$work_root/$proj"
    puts "\n  >>> $proj ($bench_name) ..."
    create_project $proj $wdir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$wdir/${proj}_tb.sv"
    write_tb $tb_path $top_module $bench_name
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top nlp_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    set sim_dir "$wdir/$proj.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $hex_file "$sim_dir/program.hex"
    if {[file exists $data_hex]} {
        file copy -force $data_hex "$sim_dir/data.hex"
    } else {
        set dfd [open "$sim_dir/data.hex" w]; close $dfd
    }

    launch_simulation
    run -all

    set sim_log "$sim_dir/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in [open $sim_log r]
        set fd_out [open $log_file a]
        puts $fd_out "--- $proj ---"
        while {[gets $fd_in line] >= 0} { puts $fd_out $line }
        puts $fd_out ""
        close $fd_in
        close $fd_out
    }
    close_sim -quiet
    close_project -quiet
    # reclaim disk: drop the whole project dir (waveforms, xsim.dir, etc.)
    catch {file delete -force $wdir}
}

set cm_hex  "$asm_dir/coremark_official.hex"
set cm_data "$github_dir/programs/coremark/data.hex"
set sm_hex  "$asm_dir/embench_statemate.hex"
set sm_data "$asm_dir/embench_statemate_data.hex"

set fd [open $log_file w]
puts $fd "=== NLP-augmented 7-stage vs baseline 7-stage ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

# CoreMark comparison first (the §VI-D projection target):
# baseline control MUST reproduce 147,760 mispredicts / CPI 2.02;
# NLP MUST match mispredicts exactly with strictly lower cycles.
run_one "base7_coremark" $baseline_rtl "rv32i_pipeline_7stage_top" $cm_hex $cm_data "CoreMark"
run_one "nlp7_coremark"  $nlp_rtl "rv32i_pipeline_7stage_nlp_top" $cm_hex $cm_data "CoreMark"
# statemate comparison
run_one "base7_statemate" $baseline_rtl "rv32i_pipeline_7stage_top" $sm_hex $sm_data "statemate"
run_one "nlp7_statemate" $nlp_rtl "rv32i_pipeline_7stage_nlp_top" $sm_hex $sm_data "statemate"

puts "\n=== NLP RUN COMPLETE -> $log_file ===\n"
