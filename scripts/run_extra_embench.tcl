# run_extra_embench.tcl - Evaluate additional Embench-IoT kernels across pipeline
# depths and under SGF. For each kernel it runs the baseline 4/5/6/7/8-stage
# pipelines and the 6/7/8-stage SGF variants, logging cycles, instructions,
# branches, mispredictions, CPI, and inter-branch distance.
#
# Prerequisite: build the kernel hex with scripts/build_extra_embench.sh.
# Run from the Vivado Tcl console:  source <repo>/scripts/run_extra_embench.tcl
# Output: results/extra_embench_results.log
# Vivado scratch is written under $RISCV_WORK (default D:/RISCV-Vivado), not the repo.

set project_dir [file normalize [file dirname [info script]]]
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir     "$github_dir/rtl"
set asm_dir     "$github_dir/programs/asm"
set part        "xc7a35tcpg236-1"
set log_file    "$github_dir/results/extra_embench_results.log"
if {[info exists ::env(RISCV_WORK)]} { set tb_dir "$::env(RISCV_WORK)/extra_embench" } else { set tb_dir "D:/RISCV-Vivado/extra_embench" }

# Kernels to evaluate (must have been built to programs/asm/embench_<name>.hex).
# Reported screen kernels: huffbench and sglib-combined (low-IBD, data-dependent,
# Mechanism-B positive). They use a 16 KB DMEM, which is orthogonal to the
# control-path misprediction behavior measured here.
set kernels [list huffbench sglib-combined]

# --- canonical RTL (one consistent source) ---
set shared_base [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" ]
# SGF shared swaps in the dual-GHR predictor and adds the EX1/EX2 register
set shared_sgf [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor_sgf.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" ]

set rtl4 [concat $shared_base [list \
    "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
    "$github_dir/rtl_4stage/forwarding_unit.sv" "$github_dir/rtl_4stage/hazard_unit.sv"]]
set rtl5 [concat $shared_base [list \
    "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
    "$github_dir/rtl_5stage/forwarding_unit.sv" "$github_dir/rtl_5stage/hazard_unit.sv"]]
set rtl6 [concat $shared_base [list \
    "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_top.sv"]]
set rtl7 [concat $shared_base [list "$rtl_dir/pipe_ex1_ex2.sv"] [list \
    "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
    "$github_dir/rtl_7stage/forwarding_unit.sv" "$github_dir/rtl_7stage/hazard_unit.sv" \
    "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]
set rtl8 [concat $shared_base [list "$rtl_dir/pipe_ex1_ex2.sv"] [list \
    "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
    "$github_dir/rtl_8stage/forwarding_unit.sv" "$github_dir/rtl_8stage/hazard_unit.sv" \
    "$github_dir/rtl_8stage/pipe_if1_if2.sv" "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]
set rtl7sgf [concat $shared_sgf [list \
    "$github_dir/rtl_7stage/rv32i_pipeline_7stage_sgf_top.sv" \
    "$github_dir/rtl_7stage/forwarding_unit.sv" "$github_dir/rtl_7stage/hazard_unit.sv" \
    "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]
set rtl8sgf [concat $shared_sgf [list \
    "$github_dir/rtl_8stage/rv32i_pipeline_8stage_sgf_top.sv" \
    "$github_dir/rtl_8stage/forwarding_unit.sv" "$github_dir/rtl_8stage/hazard_unit.sv" \
    "$github_dir/rtl_8stage/pipe_if1_if2.sv" "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]
set rtl6sgf [concat $shared_sgf [list \
    "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_sgf_top.sv"]]

proc write_embench_tb {filepath top_module bench_name} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module emb_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd ""
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 4096;   // 16 KB DMEM for the screen kernels"
    puts $fd ""
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 4096; i++) dut.u_dmem.mem\[i\] = 32'h0;"
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
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    if (dut.u_dmem.mem\[2\] != 0) begin"
    puts $fd "      \$display(\"  IBD:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[1\] / dut.u_dmem.mem\[2\],"
    puts $fd "        ((dut.u_dmem.mem\[1\] % dut.u_dmem.mem\[2\]) * 100) / dut.u_dmem.mem\[2\]);"
    puts $fd "      \$display(\"  Mispredict%%:    %0d.%02d%%\","
    puts $fd "        (dut.u_dmem.mem\[3\] * 100) / dut.u_dmem.mem\[2\],"
    puts $fd "        ((dut.u_dmem.mem\[3\] * 10000) / dut.u_dmem.mem\[2\]) % 100);"
    puts $fd "    end"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_one {proj_name rtl_files top_module hex_file data_hex bench_name} {
    global part tb_dir log_file
    puts "\n  $proj_name ($bench_name)..."
    set work_dir "$tb_dir/$proj_name"

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_embench_tb $tb_path $top_module $bench_name
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top emb_tb [get_filesets sim_1]
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
    catch {file delete -force $work_dir}
}

file mkdir $tb_dir

set fd [open $log_file w]
puts $fd "=== Additional Embench-IoT Kernels: Mechanism-B screen ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "=== baseline 4/5/6/7/8 and 6/7/8-stage SGF ==="
puts $fd ""
close $fd

set variants [list \
    [list "4s"     $rtl4    "rv32i_pipeline_4stage_top"] \
    [list "5s"     $rtl5    "rv32i_pipeline_5stage_top"] \
    [list "6s"     $rtl6    "rv32i_pipeline_top"] \
    [list "7s"     $rtl7    "rv32i_pipeline_7stage_top"] \
    [list "8s"     $rtl8    "rv32i_pipeline_8stage_top"] \
    [list "6s_sgf" $rtl6sgf "rv32i_pipeline_sgf_top"] \
    [list "7s_sgf" $rtl7sgf "rv32i_pipeline_7stage_sgf_top"] \
    [list "8s_sgf" $rtl8sgf "rv32i_pipeline_8stage_sgf_top"] \
]

foreach k $kernels {
    set hex  "$asm_dir/embench_${k}.hex"
    set dhex "$asm_dir/embench_${k}_data.hex"
    if {![file exists $hex]} {
        puts "  SKIP $k: $hex not found (build it with scripts/build_extra_embench.sh)"
        set fd [open $log_file a]; puts $fd "--- $k: SKIPPED (hex missing) ---\n"; close $fd
        continue
    }
    foreach v $variants {
        set vname [lindex $v 0]; set vrtl [lindex $v 1]; set vtop [lindex $v 2]
        run_one "${k}_${vname}" $vrtl $vtop $hex $dhex "$k"
    }
}

puts "\n================================================================"
puts "  EXTRA-EMBENCH SCREEN COMPLETE"
puts "  Results: $log_file"
puts "  For each kernel, compare baseline 4s/5s mispred vs 6s/7s/8s:"
puts "    rising  -> Mechanism B (a new positive workload; check 7s_sgf removes it)"
puts "    flat    -> Mechanism-A-only (negative control)"
puts "================================================================\n"
