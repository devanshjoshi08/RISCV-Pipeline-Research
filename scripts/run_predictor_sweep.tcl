# run_predictor_sweep.tcl - Run Dhrystone with PHT_DEPTH = 32, 64, 128
# on all 3 pipeline variants (9 runs total).
# Results saved to predictor_sweep_results.log.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set asm_dir     "$github_dir/programs/asm"
set log_file    "$project_dir/predictor_sweep_results.log"
set tb_dir      "$project_dir/vivado_predsweep"
set part        "xc7a35tcpg236-1"

set fd [open $log_file w]
puts $fd "=== Predictor Sweep: PHT_DEPTH = 32, 64, 128 x 3 pipeline variants ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

set shared_rtl_base [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

proc write_sweep_tb {filepath top_module pht_depth} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module sweep_tb;"
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
    puts $fd "    \$display(\"=== %s PHT=%0d ===\", \"$top_module\", $pht_depth);"
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

# For each PHT size, we create a modified branch_predictor.sv with the parameter default changed.
# This avoids needing to modify the pipeline top modules.
proc create_bp_variant {outdir pht_depth} {
    global rtl_dir
    set src "$rtl_dir/branch_predictor.sv"
    set dst "$outdir/branch_predictor.sv"
    file mkdir $outdir
    set fd_in [open $src r]
    set fd_out [open $dst w]
    while {[gets $fd_in line] >= 0} {
        if {[regexp {parameter PHT_DEPTH\s*=\s*\d+} $line]} {
            regsub {PHT_DEPTH\s*=\s*\d+} $line "PHT_DEPTH  = $pht_depth" line
        }
        puts $fd_out $line
    }
    close $fd_in
    close $fd_out
    return $dst
}

proc run_sweep {name work_dir rtl_files top_module pht_depth} {
    global part tb_dir log_file asm_dir

    puts "\n  Running: $name (PHT=$pht_depth)"
    create_project $name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    set tb_path "$tb_dir/${name}_tb.sv"
    write_sweep_tb $tb_path $top_module $pht_depth
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top sweep_tb [get_filesets sim_1]
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

foreach pht {32 64 128} {
    # Create modified branch predictor for this PHT size
    set bp_dir "$tb_dir/bp_pht${pht}"
    set bp_file [create_bp_variant $bp_dir $pht]

    # 5-stage
    set rtl5 [concat $shared_rtl_base [list $bp_file] [glob "$github_dir/rtl_5stage/*.sv"]]
    run_sweep "5s_pht${pht}" "$tb_dir/5s_pht${pht}" $rtl5 "rv32i_pipeline_5stage_top" $pht

    # 6-stage
    set rtl6 [concat $shared_rtl_base [list $bp_file "$rtl_dir/pipe_ex1_ex2.sv" \
        "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
        "$rtl_dir/rv32i_pipeline_top.sv"]]
    run_sweep "6s_pht${pht}" "$tb_dir/6s_pht${pht}" $rtl6 "rv32i_pipeline_top" $pht

    # 7-stage
    set rtl7 [concat $shared_rtl_base [list $bp_file "$rtl_dir/pipe_ex1_ex2.sv"] \
        [glob "$github_dir/rtl_7stage/*.sv"]]
    run_sweep "7s_pht${pht}" "$tb_dir/7s_pht${pht}" $rtl7 "rv32i_pipeline_7stage_top" $pht
}

puts "\n================================================================"
puts "  PREDICTOR SWEEP COMPLETE - Results in: $log_file"
puts "================================================================\n"
