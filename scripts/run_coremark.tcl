# run_coremark.tcl - Run official EEMBC CoreMark on all 5 pipeline depths.
# Uses imem with DEPTH=4096 (16KB) via defparam override.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set hex_file    "$github_dir/programs/coremark/coremark.hex"
set log_file    "$project_dir/coremark_official_results.log"
set tb_dir      "$project_dir/vivado_coremark"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Official EEMBC CoreMark Benchmark Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

proc write_coremark_tb {filepath top_module} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module coremark_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd ""
    puts $fd "  // Override imem depth to 4096 words (16KB) for CoreMark"
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  // Override dmem depth to 2048 words (8KB) for CoreMark stack"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd ""
    puts $fd "  // Zero all DMEM then load .rodata (prevents X-propagation)"
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
    puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial clk = 0;"
    puts $fd "  always #5 clk = ~clk;"
    puts $fd ""
    puts $fd "  // Halt detection: PC stuck at same address for >10 cycles"
    puts $fd "  int halt_count;"
    puts $fd "  logic \[31:0\] prev_pc;"
    puts $fd "  always_ff @(posedge clk) begin"
    puts $fd "    prev_pc <= debug_pc;"
    puts $fd "    if (!rst_n) halt_count <= 0;"
    puts $fd "    else if (debug_pc == prev_pc) halt_count <= halt_count + 1;"
    puts $fd "    else halt_count <= 0;"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial begin"
    puts $fd "    \$display(\"=== CoreMark: $top_module ===\");"
    puts $fd "    rst_n = 0;"
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 1000);"
    puts $fd "      repeat (50000000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd ""
    puts $fd "    // Results stored by portable_fini() at dmem\[0..5\]"
    puts $fd "    // 0x10000 -> dmem\[0\], 0x10004 -> dmem\[1\], etc."
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    \$display(\"  Iterations:     %0d\", dut.u_dmem.mem\[4\]);"
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    if (dut.u_dmem.mem\[4\] != 0 && dut.u_dmem.mem\[0\] != 0)"
    puts $fd "      \$display(\"  CoreMark/MHz:   %0d.%02d\","
    puts $fd "        (dut.u_dmem.mem\[4\] * 1000000) / dut.u_dmem.mem\[0\],"
    puts $fd "        (((dut.u_dmem.mem\[4\] * 1000000) % dut.u_dmem.mem\[0\]) * 100) / dut.u_dmem.mem\[0\]);"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_coremark {proj_name work_dir rtl_files top_module} {
    global part tb_dir log_file hex_file github_dir

    puts "\n  $proj_name..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_coremark_tb $tb_path $top_module
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top coremark_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    # Copy CoreMark hex as program.hex + data.hex for DMEM rodata
    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $hex_file "$sim_dir/program.hex"
    file copy -force "$github_dir/programs/coremark/data.hex" "$sim_dir/data.hex"

    launch_simulation
    run -all

    # Capture results
    set sim_log "$work_dir/$proj_name.sim/sim_1/behav/xsim/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in [open $sim_log r]
        set fd_out [open $log_file a]
        puts $fd_out "--- $proj_name ---"
        while {[gets $fd_in line] >= 0} { puts $fd_out $line }
        close $fd_in
        puts $fd_out ""
        close $fd_out
    }
    close_sim -quiet
    close_project -quiet
}

file mkdir $tb_dir

# RTL file lists for each pipeline variant
set rtl4 [concat $shared_rtl [list \
    "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
    "$github_dir/rtl_4stage/forwarding_unit.sv" \
    "$github_dir/rtl_4stage/hazard_unit.sv"]]

set rtl5 [concat $shared_rtl [list \
    "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
    "$github_dir/rtl_5stage/forwarding_unit.sv" \
    "$github_dir/rtl_5stage/hazard_unit.sv"]]

set rtl6 [concat $shared_rtl [list \
    "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" \
    "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_top.sv"]]

set rtl7 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [list "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
          "$github_dir/rtl_7stage/forwarding_unit.sv" \
          "$github_dir/rtl_7stage/hazard_unit.sv" \
          "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]

set rtl8 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [list "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
          "$github_dir/rtl_8stage/forwarding_unit.sv" \
          "$github_dir/rtl_8stage/hazard_unit.sv" \
          "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
          "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]

# Run on all 5 depths
set variants [list \
    [list "cm_4s" "$tb_dir/cm_4s" $rtl4 "rv32i_pipeline_4stage_top"] \
    [list "cm_5s" "$tb_dir/cm_5s" $rtl5 "rv32i_pipeline_5stage_top"] \
    [list "cm_6s" "$tb_dir/cm_6s" $rtl6 "rv32i_pipeline_top"] \
    [list "cm_7s" "$tb_dir/cm_7s" $rtl7 "rv32i_pipeline_7stage_top"] \
    [list "cm_8s" "$tb_dir/cm_8s" $rtl8 "rv32i_pipeline_8stage_top"] \
]

foreach variant $variants {
    set vname [lindex $variant 0]
    set vdir  [lindex $variant 1]
    set vrtl  [lindex $variant 2]
    set vtop  [lindex $variant 3]
    run_coremark $vname $vdir $vrtl $vtop
}

puts "\n================================================================"
puts "  COREMARK COMPLETE - Results in: $log_file"
puts "================================================================\n"

# Auto-start Embench after CoreMark finishes
puts "Starting Embench-IoT benchmarks..."
source [file join [file dirname [info script]] run_embench_official.tcl]
