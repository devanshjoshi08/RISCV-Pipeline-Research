# run_7s8s_rerun.tcl - Re-run ONLY 7-stage and 8-stage on all benchmarks.
# Uses fixed hex files (NOPs in unused imem instead of illegal instructions).
# Results APPEND to existing logs (does NOT overwrite 4s/5s/6s results).

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set asm_dir     "$github_dir/programs/asm"
set tb_dir      "$project_dir/vivado_7s8s_rerun"
set part        "xc7a35tcpg236-1"

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

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
    puts $fd "  // Halt detection: PC stays in same 8-byte region for >1000 cycles"
    puts $fd "  // Allows for ±4 byte wobble from speculative fetch in 7/8-stage pipelines"
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
        puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
        puts $fd "      \$display(\"  CPI:            %0d.%02d\","
        puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
        puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    } else {
        puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
        puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
        puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
        puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
        puts $fd "    \$display(\"  Correct:        %0d\", dut.u_dmem.mem\[4\]);"
        puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
        puts $fd "      \$display(\"  CPI:            %0d.%02d\","
        puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
        puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    }
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd ""
    puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_bench {proj_name work_dir rtl_files top_module hex_file data_hex_file bench_name result_type log_file} {
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
    if {[file exists $data_hex_file]} {
        file copy -force $data_hex_file "$sim_dir/data.hex"
    } else {
        # Create empty data.hex
        set dfd [open "$sim_dir/data.hex" w]
        close $dfd
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

# RTL for 7-stage and 8-stage only
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

set log_file "$project_dir/7s8s_rerun_results.log"
set fd [open $log_file w]
puts $fd "=== 7-stage & 8-stage Re-run (fixed hex: NOPs in unused imem) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

# All benchmarks to re-run
set benchmarks [list \
    [list "coremark_official.hex" "" "CoreMark" "coremark"] \
    [list "embench_aha-mont64.hex" "embench_aha-mont64_data.hex" "aha-mont64" "embench"] \
    [list "embench_crc32.hex" "embench_crc32_data.hex" "crc32" "embench"] \
    [list "embench_statemate.hex" "embench_statemate_data.hex" "statemate" "embench"] \
    [list "embench_edn.hex" "embench_edn_data.hex" "edn" "embench"] \
]

set variants [list \
    [list "7s" $rtl7 "rv32i_pipeline_7stage_top"] \
    [list "8s" $rtl8 "rv32i_pipeline_8stage_top"] \
]

# CoreMark data.hex path
set cm_data "$github_dir/programs/coremark/data.hex"

foreach bench $benchmarks {
    set hex_name [lindex $bench 0]
    set data_name [lindex $bench 1]
    set bname [lindex $bench 2]
    set rtype [lindex $bench 3]

    foreach variant $variants {
        set vname [lindex $variant 0]
        set vrtl  [lindex $variant 1]
        set vtop  [lindex $variant 2]

        set proj "${vname}_${bname}_rerun"

        if {$rtype eq "coremark"} {
            set data_path $cm_data
        } else {
            set data_path "$asm_dir/$data_name"
        }

        run_bench $proj "$tb_dir/$proj" $vrtl $vtop "$asm_dir/$hex_name" $data_path $bname $rtype $log_file
    }
}

puts "\n================================================================"
puts "  7s/8s RE-RUN COMPLETE - Results in: $log_file"
puts "================================================================\n"
