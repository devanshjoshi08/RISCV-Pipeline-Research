# run_benchmarks_new.tcl - Run all benchmarks on 4-stage and 8-stage.
# Fixes hex loading by copying ALL hex files to xsim working directory.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/benchmarks_4s8s_results.log"
set tb_dir      "$project_dir/vivado_bench_4s8s"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== 4-Stage & 8-Stage Benchmark Results ==="
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

proc write_tb {filepath top_module bench_name} {
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
    puts $fd "    \$display(\"=== $bench_name: $top_module ===\");"
    puts $fd "    rst_n = 0;"
    puts $fd "    // program.hex loaded by imem initial block"
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 10);"
    puts $fd "      repeat (500000) @(posedge clk);"
    puts $fd "    join_any"
    puts $fd "    repeat (10) @(posedge clk);"
    puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
    puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
    puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
    puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
    puts $fd "    \$display(\"  Checksum:       0x%08h\", dut.u_dmem.mem\[4\]);"
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
    puts $fd "  initial begin #50000000; \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_one {proj_name work_dir rtl_files top_module hex_file bench_name} {
    global part tb_dir log_file asm_dir

    puts "\n  $proj_name ($bench_name)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_tb $tb_path $top_module $bench_name
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top bench_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    # Copy the benchmark hex AS program.hex so imem's $readmemh finds it
    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force "$asm_dir/$hex_file" "$sim_dir/program.hex"

    launch_simulation
    run -all

    # Capture results
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

set rtl8 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv" \
    "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
    "$github_dir/rtl_8stage/forwarding_unit.sv" \
    "$github_dir/rtl_8stage/hazard_unit.sv" \
    "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
    "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]

# Benchmarks to run
set benchmarks [list \
    [list "dhrystone.hex"         "Dhrystone"] \
    [list "bench_diagnostic.hex"  "Diagnostic"] \
    [list "coremark_minimal.hex"  "CoreMark-insp"] \
]

# Run on 4-stage
foreach bench $benchmarks {
    set hex [lindex $bench 0]
    set bname [lindex $bench 1]
    run_one "4s_[file rootname $hex]" "$tb_dir/4s_[file rootname $hex]" \
        $rtl4 "rv32i_pipeline_4stage_top" $hex $bname
}

# Run on 8-stage
foreach bench $benchmarks {
    set hex [lindex $bench 0]
    set bname [lindex $bench 1]
    run_one "8s_[file rootname $hex]" "$tb_dir/8s_[file rootname $hex]" \
        $rtl8 "rv32i_pipeline_8stage_top" $hex $bname
}

puts "\n================================================================"
puts "  BENCHMARKS COMPLETE - Results in: $log_file"
puts "================================================================\n"
