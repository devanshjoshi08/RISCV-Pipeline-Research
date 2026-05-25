# run_bimodal.tcl - Run Dhrystone with bimodal predictor on all 3 variants.
# Compares against gshare results to show effect persists across predictor architectures.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/bimodal_results.log"
set tb_dir      "$project_dir/vivado_bimodal"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Bimodal Predictor Dhrystone Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

# Shared RTL WITHOUT the gshare predictor (we'll add bimodal instead)
set shared_rtl_base [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

# The bimodal predictor has the same module name interface but different file.
# We rename it to match: create a wrapper that instantiates bimodal as "branch_predictor"
set bimodal_wrapper "$tb_dir/branch_predictor_wrap.sv"
file mkdir $tb_dir
set fd [open $bimodal_wrapper w]
puts $fd "// Wrapper: makes bimodal predictor available as 'branch_predictor' module name"
puts $fd "// so pipeline tops can instantiate it without modification."
puts $fd ""
puts $fd "import pkg_riscv::*;"
puts $fd ""
puts $fd "module branch_predictor #("
puts $fd "  parameter PHT_DEPTH = 64,"
puts $fd "  parameter BTB_DEPTH = 32,"
puts $fd "  parameter RAS_DEPTH = 4"
puts $fd ")("
puts $fd "  input  logic        clk, rst_n,"
puts $fd "  input  logic \[31:0\] pc_if,"
puts $fd "  output logic        predict_taken,"
puts $fd "  output logic \[31:0\] predict_target,"
puts $fd "  output logic        predict_valid,"
puts $fd "  input  logic        ras_push_en,"
puts $fd "  input  logic \[31:0\] ras_push_addr,"
puts $fd "  input  logic        update_en,"
puts $fd "  input  logic \[31:0\] update_pc,"
puts $fd "  input  logic        actual_taken,"
puts $fd "  input  logic \[31:0\] actual_target,"
puts $fd "  input  btb_type_t   update_type,"
puts $fd "  input  logic        flush,"
puts $fd "  input  logic \[1:0\]  flush_ras_ptr,"
puts $fd "  output logic \[1:0\]  ras_ptr_out"
puts $fd ");"
puts $fd "  branch_predictor_bimodal #(.PHT_DEPTH(PHT_DEPTH),.BTB_DEPTH(BTB_DEPTH),.RAS_DEPTH(RAS_DEPTH)) u ("
puts $fd "    .clk(clk), .rst_n(rst_n), .pc_if(pc_if),"
puts $fd "    .predict_taken(predict_taken), .predict_target(predict_target),"
puts $fd "    .predict_valid(predict_valid),"
puts $fd "    .ras_push_en(ras_push_en), .ras_push_addr(ras_push_addr),"
puts $fd "    .update_en(update_en), .update_pc(update_pc),"
puts $fd "    .actual_taken(actual_taken), .actual_target(actual_target),"
puts $fd "    .update_type(update_type),"
puts $fd "    .flush(flush), .flush_ras_ptr(flush_ras_ptr),"
puts $fd "    .ras_ptr_out(ras_ptr_out)"
puts $fd "  );"
puts $fd "endmodule"
close $fd

# Bimodal source
set bimodal_src "$github_dir/rtl/branch_predictor_bimodal.sv"

proc write_bimodal_tb {filepath top_module} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module bimodal_tb;"
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
    puts $fd "    \$display(\"=== Bimodal Dhrystone: $top_module ===\");"
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

proc run_bimodal {name work_dir rtl_files top_module} {
    global part tb_dir log_file asm_dir
    puts "\n  Running bimodal: $name"
    create_project $name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$tb_dir/${name}_tb.sv"
    write_bimodal_tb $tb_path $top_module
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top bimodal_tb [get_filesets sim_1]
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

# 5-stage with bimodal
set rtl5 [concat $shared_rtl_base [list $bimodal_src $bimodal_wrapper] \
    [glob "$github_dir/rtl_5stage/*.sv"]]
run_bimodal "bim_5s" "$tb_dir/bim_5s" $rtl5 "rv32i_pipeline_5stage_top"

# 6-stage with bimodal
set rtl6 [concat $shared_rtl_base [list $bimodal_src $bimodal_wrapper \
    "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/forwarding_unit.sv" \
    "$rtl_dir/hazard_unit.sv" "$rtl_dir/rv32i_pipeline_top.sv"]]
run_bimodal "bim_6s" "$tb_dir/bim_6s" $rtl6 "rv32i_pipeline_top"

# 7-stage with bimodal
set rtl7 [concat $shared_rtl_base [list $bimodal_src $bimodal_wrapper \
    "$rtl_dir/pipe_ex1_ex2.sv"] [glob "$github_dir/rtl_7stage/*.sv"]]
run_bimodal "bim_7s" "$tb_dir/bim_7s" $rtl7 "rv32i_pipeline_7stage_top"

puts "\n================================================================"
puts "  BIMODAL PREDICTOR COMPLETE - Results in: $log_file"
puts "================================================================\n"
