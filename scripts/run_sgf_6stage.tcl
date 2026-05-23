# run_sgf_6stage.tcl - Run SGF benchmarks on 6-stage pipeline.
# PREREQUISITE: You must create rtl/rv32i_pipeline_sgf_top.sv (6-stage SGF variant)
# by adapting rv32i_pipeline_top.sv to use branch_predictor_sgf.sv and forward
# the 6-bit ghr_checkpoint through pipe_id_ex → pipe_ex1_ex2 → pipe_ex_mem.
# See REQUIRED_RTL_CHANGES below.

# REQUIRED RTL CHANGES for 6-stage SGF:
# 1. Copy rv32i_pipeline_top.sv → rv32i_pipeline_sgf_top.sv
# 2. Replace: branch_predictor u_bp → branch_predictor_sgf u_bp
# 3. Add wires: logic [5:0] if_ghr_checkpoint, id_ghr_checkpoint, ex1_ghr_checkpoint
# 4. Connect: u_bp.ghr_checkpoint → if_ghr_checkpoint
# 5. Forward checkpoint through pipeline registers:
#    - pipe_if_id: add if_ghr_checkpoint → id_ghr_checkpoint
#    - pipe_id_ex: add id_ghr_checkpoint → ex1_ghr_checkpoint (= id_ex_ghr_checkpoint)
#    - At EX2 resolution: pass ex1_ghr_checkpoint to u_bp.update_ghr_checkpoint
# 6. Wire spec_update_en, committed_ghr outputs from u_bp as needed

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set asm_dir     "$github_dir/programs/asm"
set tb_dir      "$project_dir/vivado_sgf_6s"
set part        "xc7a35tcpg236-1"
set log_file    "$project_dir/sgf_6stage_results.log"

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor_sgf.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
]

# CHECK: rv32i_pipeline_sgf_top.sv must exist
set sgf_top "$rtl_dir/rv32i_pipeline_sgf_top.sv"
if {![file exists $sgf_top]} {
    puts "ERROR: $sgf_top does not exist."
    puts "You need to create the 6-stage SGF top module first."
    puts "See REQUIRED RTL CHANGES at the top of this script."
    exit 1
}

set rtl6sgf [concat $shared_rtl [list $sgf_top]]

proc write_bench_tb {filepath top_module bench_name result_type} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module sgf6s_tb;"
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

proc run_bench {proj_name work_dir rtl_files top_module hex_file data_hex bench_name result_type} {
    global part tb_dir log_file

    puts "\n  $proj_name ($bench_name)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${proj_name}_tb.sv"
    write_bench_tb $tb_path $top_module $bench_name $result_type
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top sgf6s_tb [get_filesets sim_1]
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
    # reclaim disk after each run (waveforms/xsim.dir) so D: cannot fill up
    catch {file delete -force $work_dir}
}

file mkdir $tb_dir

set cm_hex  "$asm_dir/coremark_official.hex"
set cm_data "$github_dir/programs/coremark/data.hex"
set sm_hex  "$asm_dir/embench_statemate.hex"
set sm_data "$asm_dir/embench_statemate_data.hex"

set benchmarks [list \
    [list $cm_hex $cm_data "CoreMark" "coremark"] \
    [list $sm_hex $sm_data "statemate" "embench"] \
    [list "$asm_dir/embench_aha-mont64.hex" "$asm_dir/embench_aha-mont64_data.hex" "aha-mont64" "embench"] \
    [list "$asm_dir/embench_crc32.hex" "$asm_dir/embench_crc32_data.hex" "crc32" "embench"] \
    [list "$asm_dir/embench_edn.hex" "$asm_dir/embench_edn_data.hex" "edn" "embench"] \
]

set fd [open $log_file w]
puts $fd "=== SGF 6-Stage Benchmark Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

foreach bench $benchmarks {
    set hex_file   [lindex $bench 0]
    set data_hex   [lindex $bench 1]
    set bench_name [lindex $bench 2]
    set rtype      [lindex $bench 3]

    set proj "6s_sgf_${bench_name}"
    run_bench $proj "$tb_dir/$proj" $rtl6sgf "rv32i_pipeline_sgf_top" $hex_file $data_hex $bench_name $rtype
}

puts "\n================================================================"
puts "  SGF 6-STAGE COMPLETE"
puts "  Results in: $log_file"
puts "================================================================\n"
