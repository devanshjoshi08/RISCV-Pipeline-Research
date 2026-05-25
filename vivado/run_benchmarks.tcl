# run_benchmarks.tcl - Run ALL 7 benchmarks on ALL 5 pipeline variants.
# Based on the proven working pattern: generate TB on-the-fly, create_project,
# copy hex as program.hex, launch_simulation, run -all.
#
# Usage: cd <your Vivado scratch dir>
#        source run_benchmarks.tcl
#
# Output: benchmark_results_all.log (appended for each run)

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$project_dir/programs/asm"
set log_file    "$project_dir/benchmark_results_all.log"

set fd [open $log_file w]
puts $fd "=== Pipeline Benchmark Results (All Variants) ==="
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

set part "xc7a35tcpg236-1"

proc run_bench {proj_name work_dir part rtl_files tb_file sim_top bench_hex hex_name} {
    global project_dir asm_dir log_file

    puts "\n--- $proj_name: $hex_name ---"

    set fd [open $log_file a]
    puts $fd "--- $proj_name: $hex_name ---"
    close $fd

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset sim_1 -norecurse $tb_file
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top $sim_top [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    launch_simulation
    run -all

    # Capture simulation log
    set sim_log "$work_dir/$proj_name.sim/sim_1/behav/xsim/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in [open $sim_log r]
        set fd_out [open $log_file a]
        while {[gets $fd_in line] >= 0} {
            puts $fd_out $line
        }
        close $fd_in
        puts $fd_out ""
        close $fd_out
    }

    close_sim -quiet
    close_project -quiet
}

# Generate a testbench for a given DUT and benchmark hex
proc write_bench_tb {filepath top_module bench_hex} {
    global asm_dir
    # Use absolute path with forward slashes so xsim finds hex file
    set abs_hex [string map {\\ /} [file normalize "$asm_dir/$bench_hex"]]
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module bench_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd "  initial clk = 0;"
    puts $fd "  always #5 clk = ~clk;"
    puts $fd "  int halt_count;"
    puts $fd "  always_ff @(posedge clk) begin"
    puts $fd "    if (!rst_n) halt_count <= 0;"
    puts $fd "    else if (debug_instr == 32'h0000006F) halt_count <= halt_count + 1;"
    puts $fd "    else halt_count <= 0;"
    puts $fd "  end"
    puts $fd "  initial begin"
    puts $fd "    \$display(\"=== $bench_hex on $top_module ===\");"
    puts $fd "    rst_n = 0;"
    puts $fd "    for (int i = 0; i < 1024; i++) dut.u_imem.mem\[i\] = 32'h00000013;"
    puts $fd "    \$readmemh(\"$abs_hex\", dut.u_imem.mem);"
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 10);"
    puts $fd "      repeat (500000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd "    if (halt_count <= 10) begin"
    puts $fd "      \$display(\"  TIMEOUT - did not halt\");"
    puts $fd "    end else begin"
    puts $fd "      \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "      \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "      \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "      \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "      \$display(\"  Checksum:       0x%08h\", dut.u_dmem.mem\[4\]);"
    puts $fd "      if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "        \$display(\"  CPI:            %0d.%02d\","
    puts $fd "          dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "          ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "      if (dut.u_dmem.mem\[2\] != 0)"
    puts $fd "        \$display(\"  Mispredict%%:    %0d.%02d%%\","
    puts $fd "          (dut.u_dmem.mem\[3\] * 100) / dut.u_dmem.mem\[2\],"
    puts $fd "          ((dut.u_dmem.mem\[3\] * 10000) / dut.u_dmem.mem\[2\]) % 100);"
    puts $fd "    end"
    puts $fd "    \$display(\"=== Done ===\");"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd "  initial begin #50000000; \$display(\"TIMEOUT-HARD\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

# All 7 benchmarks
set benchmarks [list \
    "bench_diagnostic.hex" \
    "bench_branch_heavy.hex" \
    "bench_compute_heavy.hex" \
    "bench_crc32.hex" \
    "bench_sort.hex" \
    "dhrystone.hex" \
    "coremark_minimal.hex" \
]

# All 5 variants: {label top_module rtl_files}
set variants [list \
    [list "4stage" "rv32i_pipeline_4stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
            "$github_dir/rtl_4stage/forwarding_unit.sv" \
            "$github_dir/rtl_4stage/hazard_unit.sv"]]] \
    [list "5stage" "rv32i_pipeline_5stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
            "$github_dir/rtl_5stage/forwarding_unit.sv" \
            "$github_dir/rtl_5stage/hazard_unit.sv"]]] \
    [list "6stage" "rv32i_pipeline_top" \
        [concat $shared_rtl [list \
            "$rtl_dir/pipe_ex1_ex2.sv" \
            "$rtl_dir/forwarding_unit.sv" \
            "$rtl_dir/hazard_unit.sv" \
            "$rtl_dir/rv32i_pipeline_top.sv"]]] \
    [list "7stage" "rv32i_pipeline_7stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
                  "$github_dir/rtl_7stage/forwarding_unit.sv" \
                  "$github_dir/rtl_7stage/hazard_unit.sv" \
                  "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]] \
    [list "8stage" "rv32i_pipeline_8stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
                  "$github_dir/rtl_8stage/forwarding_unit.sv" \
                  "$github_dir/rtl_8stage/hazard_unit.sv" \
                  "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
                  "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]] \
]

set tb_tmp_dir "$project_dir/vivado_bench"
file mkdir $tb_tmp_dir

# Run all variants x all benchmarks = 35 runs
foreach variant $variants {
    set vlabel [lindex $variant 0]
    set vtop   [lindex $variant 1]
    set vrtl   [lindex $variant 2]

    puts "\n================================================================"
    puts "  VARIANT: $vlabel ($vtop)"
    puts "================================================================"

    set fd [open $log_file a]
    puts $fd "\n================================================================"
    puts $fd "  VARIANT: $vlabel ($vtop)"
    puts $fd "================================================================"
    close $fd

    foreach bench $benchmarks {
        set bname [file rootname $bench]
        set tb_path "$tb_tmp_dir/bench_${vlabel}_tb.sv"
        write_bench_tb $tb_path $vtop $bench
        run_bench "b_${vlabel}_${bname}" \
            "$tb_tmp_dir/${vlabel}_${bname}" \
            $part $vrtl $tb_path "bench_tb" $bench $bench
    }
}

puts "\n================================================================"
puts "  ALL 35 BENCHMARK RUNS COMPLETE"
puts "  Results in: $log_file"
puts "================================================================\n"
