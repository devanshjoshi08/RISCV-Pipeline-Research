# run_embench.tcl - Run Embench-inspired benchmarks (CRC32, Sort) on all 3 variants.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/embench_results.log"
set tb_dir      "$project_dir/vivado_embench"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Embench-Inspired Benchmark Results ==="
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

proc write_eb_tb {filepath top_module bench_name} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module eb_tb;"
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
    puts $fd "    repeat (5) @(posedge clk);"
    puts $fd "    rst_n = 1;"
    puts $fd "    fork"
    puts $fd "      wait (halt_count > 10);"
    puts $fd "      repeat (1000000) @(posedge clk);"
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
    puts $fd "  initial begin #100000000; \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_eb {name work_dir rtl_files top_module hex_file bench_name} {
    global part tb_dir log_file asm_dir
    puts "\n  Running: $name"
    create_project $name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$tb_dir/${name}_tb.sv"
    write_eb_tb $tb_path $top_module $bench_name
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top eb_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    set sim_dir "$work_dir/$name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force "$asm_dir/$hex_file" "$sim_dir/program.hex"
    launch_simulation
    run -all
    set sim_log "$work_dir/$name.sim/sim_1/behav/xsim/simulate.log"
    if {[file exists $sim_log]} {
        set fd_in [open $sim_log r]
        set fd_out [open $log_file a]
        while {[gets $fd_in line] >= 0} { puts $fd_out $line }
        close $fd_in
        puts $fd_out ""
        close $fd_out
    }
    close_sim -quiet
    close_project -quiet
}

file mkdir $tb_dir

set rtl5 [concat $shared_rtl [glob "$github_dir/rtl_5stage/*.sv"]]
set rtl6 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" "$rtl_dir/rv32i_pipeline_top.sv"]]
set rtl7 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] [glob "$github_dir/rtl_7stage/*.sv"]]

foreach {hex bname} {bench_crc32.hex CRC32 bench_sort.hex Sort} {
    run_eb "${bname}_5s" "$tb_dir/${bname}_5s" $rtl5 "rv32i_pipeline_5stage_top" $hex $bname
    run_eb "${bname}_6s" "$tb_dir/${bname}_6s" $rtl6 "rv32i_pipeline_top" $hex $bname
    run_eb "${bname}_7s" "$tb_dir/${bname}_7s" $rtl7 "rv32i_pipeline_7stage_top" $hex $bname
}

puts "\n================================================================"
puts "  EMBENCH COMPLETE - Results in: $log_file"
puts "================================================================\n"
