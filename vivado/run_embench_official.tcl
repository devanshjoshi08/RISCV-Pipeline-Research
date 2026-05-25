# run_embench_official.tcl - Run official Embench-IoT benchmarks on all 5 pipeline depths.
# Uses imem with DEPTH=4096 (16KB) via defparam override.
# Results go to embench_official_results.log (does NOT overwrite embench_results.log).

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/embench_official_results.log"
set tb_dir      "$project_dir/vivado_embench_official"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Official Embench-IoT Benchmark Results ==="
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

proc write_embench_tb {filepath top_module bench_name} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module embench_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd ""
    puts $fd "  // Override imem/dmem depth for larger benchmarks"
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd ""
    puts $fd "  // Pre-load .rodata into DMEM (Harvard arch: loads go to dmem only)"
    puts $fd "  initial \$readmemh(\"data.hex\", dut.u_dmem.mem);"
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
    puts $fd "    \$display(\"=== $bench_name: $top_module ===\");"
    puts $fd "    rst_n = 0;"
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 1000);"
    puts $fd "      repeat (50000000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd ""
    puts $fd "    // Results at dmem\[0..4\] (stored by board.c stop_trigger)"
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    \$display(\"  Correct:        %0d\", dut.u_dmem.mem\[4\]);"
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
    puts $fd ""
    puts $fd "  initial begin #500000000; \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_embench {proj_name work_dir rtl_files top_module hex_file bench_name} {
    global part tb_dir log_file

    puts "\n  $proj_name ($bench_name)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_embench_tb $tb_path $top_module $bench_name
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top embench_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force "$hex_file" "$sim_dir/program.hex"
    # Copy DMEM rodata hex (same name pattern: embench_<bench>_data.hex)
    set data_hex [string map {.hex _data.hex} $hex_file]
    if {[file exists $data_hex]} {
        file copy -force $data_hex "$sim_dir/data.hex"
    }

    launch_simulation
    run -all

    set sim_log "$work_dir/$proj_name.sim/sim_1/behav/xsim/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in [open $sim_log r]
        set fd_out [open $log_file a]
        puts $fd_out "--- $proj_name: $bench_name ---"
        while {[gets $fd_in line] >= 0} { puts $fd_out $line }
        close $fd_in
        puts $fd_out ""
        close $fd_out
    }
    close_sim -quiet
    close_project -quiet
}

file mkdir $tb_dir

# RTL file lists
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

# Benchmarks and their hex files
set benchmarks [list \
    [list "embench_aha-mont64.hex" "aha-mont64"] \
    [list "embench_crc32.hex"      "crc32"] \
    [list "embench_statemate.hex"  "statemate"] \
    [list "embench_edn.hex"        "edn"] \
]

# Pipeline variants
set variants [list \
    [list "4s" $rtl4 "rv32i_pipeline_4stage_top"] \
    [list "5s" $rtl5 "rv32i_pipeline_5stage_top"] \
    [list "6s" $rtl6 "rv32i_pipeline_top"] \
    [list "7s" $rtl7 "rv32i_pipeline_7stage_top"] \
    [list "8s" $rtl8 "rv32i_pipeline_8stage_top"] \
]

# Run each benchmark on each pipeline depth (4 benchmarks x 5 depths = 20 runs)
foreach bench $benchmarks {
    set hex_name [lindex $bench 0]
    set bname [lindex $bench 1]

    foreach variant $variants {
        set vname [lindex $variant 0]
        set vrtl  [lindex $variant 1]
        set vtop  [lindex $variant 2]

        set proj "${vname}_${bname}"
        run_embench $proj "$tb_dir/$proj" $vrtl $vtop "$asm_dir/$hex_name" $bname
    }
}

puts "\n================================================================"
puts "  EMBENCH COMPLETE - Results in: $log_file"
puts "  (Old results preserved in: embench_results.log)"
puts "================================================================\n"
