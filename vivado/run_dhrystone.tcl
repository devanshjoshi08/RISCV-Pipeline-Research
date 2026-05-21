# run_dhrystone.tcl - Run Dhrystone 2.1 benchmark on all 3 variants.
# Results saved to dhrystone_results.log.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/dhrystone_results.log"
set tb_dir      "$project_dir/vivado_dhry"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Dhrystone 2.1 Benchmark Results ==="
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

proc write_dhry_tb {filepath top_module} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module dhry_tb;"
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
    puts $fd "    \$display(\"=== Dhrystone 2.1: $top_module ===\");"
    puts $fd "    rst_n = 0;"
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
    puts $fd "    \$display(\"  Dhrystones:     %0d\", dut.u_dmem.mem\[4\]);"
    puts $fd "    \$display(\"  Checksum:       %0d\", dut.u_dmem.mem\[5\]);"
    puts $fd "    if (dut.u_dmem.mem\[1\] != 0) begin"
    puts $fd "      \$display(\"  CPI:            %0d.%02d\","
    puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
    puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
    puts $fd "    end"
    puts $fd "    if (dut.u_dmem.mem\[2\] != 0) begin"
    puts $fd "      \$display(\"  Mispredict%%:    %0d.%02d%%\","
    puts $fd "        (dut.u_dmem.mem\[3\] * 100) / dut.u_dmem.mem\[2\],"
    puts $fd "        ((dut.u_dmem.mem\[3\] * 10000) / dut.u_dmem.mem\[2\]) % 100);"
    puts $fd "    end"
    puts $fd "    \$display(\"=== Done ===\");"
    puts $fd "    \$finish;"
    puts $fd "  end"
    puts $fd "  initial begin #50000000; \$display(\"TIMEOUT\"); \$finish; end"
    puts $fd "endmodule"
    close $fd
}

proc run_dhry {name work_dir rtl_files top_module} {
    global part tb_dir log_file asm_dir

    puts "\n  Running Dhrystone: $name"

    create_project $name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${name}_tb.sv"
    write_dhry_tb $tb_path $top_module
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top dhry_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    set sim_dir "$work_dir/$name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force "$asm_dir/dhrystone.hex" "$sim_dir/program.hex"

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

# 5-stage
set rtl5 [concat $shared_rtl [glob "$github_dir/rtl_5stage/*.sv"]]
run_dhry "dhry_5s" "$tb_dir/dhry_5s" $rtl5 "rv32i_pipeline_5stage_top"

# 6-stage
set rtl6 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_top.sv"]]
run_dhry "dhry_6s" "$tb_dir/dhry_6s" $rtl6 "rv32i_pipeline_top"

# 7-stage
set rtl7 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [glob "$github_dir/rtl_7stage/*.sv"]]
run_dhry "dhry_7s" "$tb_dir/dhry_7s" $rtl7 "rv32i_pipeline_7stage_top"

puts "\n================================================================"
puts "  DHRYSTONE COMPLETE - Results in: $log_file"
puts "================================================================\n"
