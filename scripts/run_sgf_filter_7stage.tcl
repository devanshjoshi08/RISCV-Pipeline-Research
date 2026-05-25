# run_sgf_filter_7stage.tcl — measure the gshare SGF *confidence filter* on the
# 7-stage pipeline (CoreMark + statemate), the experiment behind the paper's
# "build-time confidence filter" claim.
#
# For each workload it runs TWO configurations of the SAME RTL:
#   CONF_FILTER = 0  -> shipped SGF (must reproduce the 101,418 CoreMark count;
#                       this is the self-check that the rig is correct)
#   CONF_FILTER = 1  -> filter enabled (the value the paper needs)
# The filter is the build-time parameter added to branch_predictor_sgf.sv; it is
# toggled per run with a testbench `defparam dut.u_bp.CONF_FILTER = <0|1>`.
#
# Run from the Vivado Tcl console (any CWD):
#   source <repo>/scripts/run_sgf_filter_7stage.tcl
# Output: results/sgf_filter_7stage_results.log

set project_dir [file normalize [file dirname [info script]]]
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir     "$github_dir/rtl"
set rtl7_dir    "$github_dir/rtl_7stage"
set asm_dir     "$github_dir/programs/asm"
set part        "xc7a35tcpg236-1"
# Vivado scratch MUST live OFF the OneDrive-synced repo (OneDrive locks project
# files mid-build, causing "directory is not writable" errors). Defaults to the
# D: scratch drive used for all synthesis/sim here; override with RISCV_WORK.
if {[info exists ::env(RISCV_WORK)]} {
    set tb_dir "$::env(RISCV_WORK)/sgf_filter"
} else {
    set tb_dir "D:/RISCV-Vivado/sgf_filter"
}
set log_file    "$github_dir/results/sgf_filter_7stage_results.log"

# Canonical 7-stage SGF build set (same files as the baseline SGF eval, from rtl/)
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor_sgf.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" \
]
set rtl7sgf [concat $shared_rtl [list \
    "$rtl7_dir/rv32i_pipeline_7stage_sgf_top.sv" \
    "$rtl7_dir/forwarding_unit.sv" \
    "$rtl7_dir/hazard_unit.sv" \
    "$rtl7_dir/pipe_if1_if2.sv"]]

set top_module "rv32i_pipeline_7stage_sgf_top"

# Generate a testbench that sets the confidence-filter parameter on the predictor.
proc write_bench_tb {filepath bench_name conf_filter} {
    global top_module
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module sgffilt_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd ""
    puts $fd "  // ==== confidence filter toggle (this run) ===="
    puts $fd "  defparam dut.u_bp.CONF_FILTER = $conf_filter;"
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
    puts $fd "    \$display(\"=== $bench_name (CONF_FILTER=$conf_filter): $top_module ===\");"
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

proc run_one {proj_name hex_file data_hex bench_name conf_filter} {
    global part tb_dir log_file rtl7sgf

    puts "\n  $proj_name (CONF_FILTER=$conf_filter)..."
    set work_dir "$tb_dir/$proj_name"

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl7sgf
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_bench_tb $tb_path $bench_name $conf_filter
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top sgffilt_tb [get_filesets sim_1]
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

    set sim_log "$sim_dir/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in  [open $sim_log r]
        set fd_out [open $log_file a]
        puts $fd_out "--- $bench_name  CONF_FILTER=$conf_filter ---"
        while {[gets $fd_in line] >= 0} { puts $fd_out $line }
        close $fd_in
        puts $fd_out ""
        close $fd_out
    }
    close_sim -quiet
    close_project -quiet
    # reclaim disk so the scratch dir cannot fill up
    catch {file delete -force $work_dir}
}

file mkdir $tb_dir

# DETERMINISM/SELF-CHECK: the CONF_FILTER=0 CoreMark run MUST print 101,418
# mispredictions, matching results/sgf_benchmark_results.log. If it does not,
# the rig is wrong and the CONF_FILTER=1 number is not trustworthy.
set benchmarks [list \
    [list "CoreMark"  "$github_dir/programs/coremark/coremark.hex" "$github_dir/programs/coremark/data.hex"] \
    [list "statemate" "$asm_dir/embench_statemate.hex"             "$asm_dir/embench_statemate_data.hex"] \
]

set fd [open $log_file w]
puts $fd "=== SGF Confidence-Filter Evaluation (7-stage, gshare) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "=== CONF_FILTER=0 is the shipped SGF (self-check vs 101,418 CoreMark); CONF_FILTER=1 is the filtered variant ==="
puts $fd ""
close $fd

foreach bench $benchmarks {
    set bname [lindex $bench 0]
    set hex   [lindex $bench 1]
    set dhex  [lindex $bench 2]
    foreach cf {0 1} {
        run_one "7s_sgf_${bname}_cf${cf}" $hex $dhex $bname $cf
    }
}

puts "\n================================================================"
puts "  SGF CONFIDENCE-FILTER RUN COMPLETE"
puts "  Results: $log_file"
puts "  Check: CONF_FILTER=0 CoreMark should read Mispredictions: 101418"
puts "         CONF_FILTER=1 CoreMark is the value for the paper (replaces 117,207)"
puts "================================================================\n"
