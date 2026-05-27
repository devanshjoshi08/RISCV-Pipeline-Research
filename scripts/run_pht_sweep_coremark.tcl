# run_pht_sweep_coremark.tcl - PHT capacity sweep on CoreMark and statemate.
# Sweeps PHT_DEPTH = {32, 64, 128, 256, 512, 1024} on the baseline gshare predictor
# across all five pipeline depths (60 simulation runs). The depth-dependent
# inflation persists at every table size, so it is not a PHT aliasing artifact.
#
# Run from the Vivado Tcl console:  source <repo>/scripts/run_pht_sweep_coremark.tcl
# Output: results/pht_sweep_coremark_results.log
# Vivado scratch is written under $RISCV_WORK (default D:/RISCV-Vivado), not the repo.

set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir     "$github_dir/rtl"
set asm_dir     "$github_dir/programs/asm"
set part        "xc7a35tcpg236-1"
set log_file    "$github_dir/results/pht_sweep_coremark_results.log"
if {[info exists ::env(RISCV_WORK)]} { set tb_dir "$::env(RISCV_WORK)/pht_sweep_coremark" } else { set tb_dir "D:/RISCV-Vivado/pht_sweep_coremark" }

set shared_rtl_base [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

# Create modified branch_predictor.sv with given PHT_DEPTH
proc create_bp_variant {outdir pht_depth} {
    global rtl_dir
    set src "$rtl_dir/branch_predictor.sv"
    set fd [open $src r]
    set content [read $fd]
    close $fd
    # Replace PHT_DEPTH parameter default
    regsub {PHT_DEPTH\s*=\s*\d+} $content "PHT_DEPTH = $pht_depth" content
    file mkdir $outdir
    set dst "$outdir/branch_predictor.sv"
    set fd [open $dst w]
    puts -nonewline $fd $content
    close $fd
    return $dst
}

proc write_bench_tb {filepath top_module bench_name result_type} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module pht_sweep_tb;"
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
    puts $fd "  // Halt detection: PC stays in same 8-byte region for >1000 cycles"
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
    if {$result_type eq "coremark"} {
        puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
        puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
        puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
        puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
        puts $fd "    \$display(\"  Iterations:     %0d\", dut.u_dmem.mem\[4\]);"
    } else {
        puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
        puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
        puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
        puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
        puts $fd "    \$display(\"  Correct:        %0d\", dut.u_dmem.mem\[4\]);"
    }
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
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_sweep {proj_name work_dir rtl_files top_module hex_file data_hex bench_name result_type} {
    global part tb_dir log_file

    puts "\n  $proj_name ($bench_name)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_bench_tb $tb_path $top_module $bench_name $result_type
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top pht_sweep_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $hex_file "$sim_dir/program.hex"
    if {[file exists $data_hex]} {
        file copy -force $data_hex "$sim_dir/data.hex"
    } else {
        set dfd [open "$sim_dir/data.hex" w]
        close $dfd
    }

    launch_simulation
    run -all

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

# Variant RTL definitions (without branch_predictor.sv - added per-sweep)
set variant_defs [list \
    [list "4s" "rv32i_pipeline_4stage_top" \
        [concat $shared_rtl_base [list \
            "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
            "$github_dir/rtl_4stage/forwarding_unit.sv" \
            "$github_dir/rtl_4stage/hazard_unit.sv"]]] \
    [list "5s" "rv32i_pipeline_5stage_top" \
        [concat $shared_rtl_base [list \
            "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
            "$github_dir/rtl_5stage/forwarding_unit.sv" \
            "$github_dir/rtl_5stage/hazard_unit.sv"]]] \
    [list "6s" "rv32i_pipeline_top" \
        [concat $shared_rtl_base [list \
            "$rtl_dir/pipe_ex1_ex2.sv" \
            "$rtl_dir/forwarding_unit.sv" \
            "$rtl_dir/hazard_unit.sv" \
            "$rtl_dir/rv32i_pipeline_top.sv"]]] \
    [list "7s" "rv32i_pipeline_7stage_top" \
        [concat $shared_rtl_base [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
                  "$github_dir/rtl_7stage/forwarding_unit.sv" \
                  "$github_dir/rtl_7stage/hazard_unit.sv" \
                  "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]] \
    [list "8s" "rv32i_pipeline_8stage_top" \
        [concat $shared_rtl_base [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
                  "$github_dir/rtl_8stage/forwarding_unit.sv" \
                  "$github_dir/rtl_8stage/hazard_unit.sv" \
                  "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
                  "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]] \
]

# Benchmark definitions: {hex_file data_hex bench_name result_type}
set cm_hex  "$asm_dir/coremark_official.hex"
set cm_data "$github_dir/programs/coremark/data.hex"
set sm_hex  "$asm_dir/embench_statemate.hex"
set sm_data "$asm_dir/embench_statemate_data.hex"

set benchmarks [list \
    [list $cm_hex $cm_data "CoreMark" "coremark"] \
    [list $sm_hex $sm_data "statemate" "embench"] \
]

# PHT depths to sweep
set pht_sizes [list 32 64 128 256 512 1024]

# Write log header
set fd [open $log_file w]
puts $fd "=== PHT Capacity Sweep: CoreMark + statemate ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "=== Baseline gshare, all 5 pipeline depths ==="
puts $fd ""
close $fd

foreach pht $pht_sizes {
    puts "\n================================================================"
    puts "  PHT_DEPTH = $pht"
    puts "================================================================"

    set fd [open $log_file a]
    puts $fd "=== PHT_DEPTH = $pht ==="
    puts $fd ""
    close $fd

    # Create modified branch_predictor.sv
    set bp_dir "$tb_dir/bp_pht${pht}"
    set bp_file [create_bp_variant $bp_dir $pht]

    foreach variant $variant_defs {
        set vname [lindex $variant 0]
        set vtop  [lindex $variant 1]
        set vrtl  [lindex $variant 2]

        # Add the PHT-modified branch_predictor.sv
        set full_rtl [concat $vrtl [list $bp_file]]

        foreach bench $benchmarks {
            set hex_file   [lindex $bench 0]
            set data_hex   [lindex $bench 1]
            set bench_name [lindex $bench 2]
            set rtype      [lindex $bench 3]

            set proj "${vname}_pht${pht}_${bench_name}"
            run_sweep $proj "$tb_dir/$proj" $full_rtl $vtop $hex_file $data_hex \
                "PHT=$pht $bench_name" $rtype
        }
    }
}

puts "\n================================================================"
puts "  PHT SWEEP ON COREMARK+STATEMATE COMPLETE"
puts "  Results in: $log_file"
puts "================================================================\n"
