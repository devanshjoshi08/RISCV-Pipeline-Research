# run_sgf_eval.tcl - Evaluate SGF (Speculative GHR Forwarding) predictor variants.
# Runs CoreMark + 4 Embench benchmarks on 7-stage-SGF and 8-stage-SGF,
# then synthesizes both for Fmax comparison.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/sgf_benchmark_results.log"
set synth_log   "$project_dir/sgf_synth_results.log"
set tb_dir      "$project_dir/vivado_sgf"
set part        "xc7a35tcpg236-1"
set clk_xdc     "$project_dir/synth_clk_only.xdc"

# Shared RTL (same as all variants, plus SGF predictor)
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor_sgf.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" \
]

# 7-stage SGF RTL
set rtl7sgf [concat $shared_rtl [list \
    "$rtl_dir/rv32i_pipeline_7stage_sgf_top.sv" \
    "$github_dir/rtl_7stage/forwarding_unit.sv" \
    "$github_dir/rtl_7stage/hazard_unit.sv" \
    "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]

# 8-stage SGF RTL
set rtl8sgf [concat $shared_rtl [list \
    "$rtl_dir/rv32i_pipeline_8stage_sgf_top.sv" \
    "$github_dir/rtl_8stage/forwarding_unit.sv" \
    "$github_dir/rtl_8stage/hazard_unit.sv" \
    "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
    "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]

# PART 1: BENCHMARK EVALUATION

set fd [open $log_file w]
puts $fd "=== SGF Predictor Benchmark Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

proc write_bench_tb {filepath top_module bench_name result_type} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module bench_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd ""
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd ""
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
    puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial clk = 0;"
    puts $fd "  always #5 clk = ~clk;"
    puts $fd ""
    puts $fd "  int halt_count;"
    puts $fd "  logic \[31:0\] prev_pc;"
    puts $fd "  always_ff @(posedge clk) begin"
    puts $fd "    prev_pc <= debug_pc;"
    puts $fd "    if (!rst_n) halt_count <= 0;"
    puts $fd "    else if (debug_pc\[31:3\] == prev_pc\[31:3\]) halt_count <= halt_count + 1;"
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
    puts $fd "      repeat (500000000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd ""
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    if {$result_type eq "coremark"} {
        puts $fd "    \$display(\"  Iterations:     %0d\", dut.u_dmem.mem\[4\]);"
    } else {
        puts $fd "    \$display(\"  Correct:        %0d\", dut.u_dmem.mem\[4\]);"
    }
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_bench {proj_name work_dir rtl_files top_module hex_file data_hex bench_name result_type log_file} {
    global part tb_dir

    puts "\n  $proj_name ($bench_name)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_bench_tb $tb_path $top_module $bench_name $result_type
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top bench_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $hex_file "$sim_dir/program.hex"
    if {[file exists $data_hex]} {
        file copy -force $data_hex "$sim_dir/data.hex"
    } else {
        set dfd [open "$sim_dir/data.hex" w]; close $dfd
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

# CoreMark data paths
set cm_hex "$github_dir/programs/coremark/coremark.hex"
set cm_data "$github_dir/programs/coremark/data.hex"

# Benchmarks to run
set benchmarks [list \
    [list "$cm_hex" "$cm_data" "CoreMark" "coremark"] \
    [list "$asm_dir/embench_aha-mont64.hex" "$asm_dir/embench_aha-mont64_data.hex" "aha-mont64" "embench"] \
    [list "$asm_dir/embench_crc32.hex" "$asm_dir/embench_crc32_data.hex" "crc32" "embench"] \
    [list "$asm_dir/embench_statemate.hex" "$asm_dir/embench_statemate_data.hex" "statemate" "embench"] \
    [list "$asm_dir/embench_edn.hex" "$asm_dir/embench_edn_data.hex" "edn" "embench"] \
]

set variants [list \
    [list "7s_sgf" $rtl7sgf "rv32i_pipeline_7stage_sgf_top"] \
    [list "8s_sgf" $rtl8sgf "rv32i_pipeline_8stage_sgf_top"] \
]

foreach bench $benchmarks {
    set hex [lindex $bench 0]
    set dhex [lindex $bench 1]
    set bname [lindex $bench 2]
    set rtype [lindex $bench 3]

    foreach variant $variants {
        set vname [lindex $variant 0]
        set vrtl  [lindex $variant 1]
        set vtop  [lindex $variant 2]
        run_bench "${vname}_${bname}" "$tb_dir/${vname}_${bname}" $vrtl $vtop $hex $dhex $bname $rtype $log_file
    }
}

puts "\n  BENCHMARKS COMPLETE: $log_file"

# PART 2: SYNTHESIS (3 seeds each for Fmax comparison)

set fd [open $synth_log w]
puts $fd "=== SGF Predictor Synthesis Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "variant,run,Fmax_MHz,WNS_ns,LUTs,FFs"
close $fd

set place_directives [list "Default" "Explore" "Default"]
set route_directives [list "Default" "Explore" "NoTimingRelaxation"]

proc synth_one {name work_dir top_module rtl_files run_num} {
    global part clk_xdc synth_log place_directives route_directives

    set proj_name "${name}_r${run_num}"
    set pdir [lindex $place_directives [expr {$run_num - 1}]]
    set rdir [lindex $route_directives [expr {$run_num - 1}]]
    puts "\n  $proj_name: synth + impl (place=$pdir route=$rdir)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $top_module [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $pdir [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $rdir [get_runs impl_1]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    open_run impl_1

    set timing_rpt [report_timing_summary -return_string -no_header]
    set wns "N/A"
    set fmax "N/A"
    foreach line [split $timing_rpt "\n"] {
        if {[regexp {^\s+(-?\d+\.\d+)\s+} $line match val]} {
            if {$wns eq "N/A"} {
                set wns $val
                set actual_period [expr {5.0 - $wns}]
                if {$actual_period > 0} {
                    set fmax [format "%.1f" [expr {1000.0 / $actual_period}]]
                }
            }
        }
    }

    set util_rpt [report_utilization -return_string]
    set luts "N/A"
    set ffs "N/A"
    foreach line [split $util_rpt "\n"] {
        if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line match val]} { set luts $val }
        if {[regexp {Slice Registers\s*\|\s*(\d+)} $line match val]} { set ffs $val }
    }

    puts "    Fmax=$fmax WNS=$wns LUTs=$luts FFs=$ffs"

    set fd [open $synth_log a]
    puts $fd "$name,$run_num,$fmax,$wns,$luts,$ffs"
    close $fd

    close_design
    close_project -quiet
}

set synth_variants [list \
    [list "7stage_sgf" "rv32i_pipeline_7stage_sgf_top" $rtl7sgf] \
    [list "8stage_sgf" "rv32i_pipeline_8stage_sgf_top" $rtl8sgf] \
]

foreach variant $synth_variants {
    set vname [lindex $variant 0]
    set vtop  [lindex $variant 1]
    set vrtl  [lindex $variant 2]

    for {set r 1} {$r <= 3} {incr r} {
        synth_one $vname "$project_dir/vivado_sgf_synth/${vname}_r${r}" $vtop $vrtl $r
    }
}

puts "\n================================================================"
puts "  SGF EVALUATION COMPLETE"
puts "  Benchmark results: $log_file"
puts "  Synthesis results: $synth_log"
puts "================================================================\n"
