# run_O2_7stage.tcl - Compiler-sensitivity experiment (TC review item B).
# Runs CoreMark and statemate at -O2 on the 7-stage baseline and 7-stage SGF
# variants and captures Cycles/Instructions/Branches/Mispredictions so Mechanism B
# persistence and SGF's reduction can be re-evaluated under -O2.
#
# PREREQUISITES:
#   1. bash scripts/build_O2_benchmarks.sh   (produces *_o2 hex in programs/asm)
#   2. Source this from the GitHub repo copy (uses the canonical rtl_7stage, NOT
#      the D: mirror which lacks the if2_redirect/ras_push gates):
#        source <repo>/scripts/run_O2_7stage.tcl
#
# Output: o2_7stage_results.log (the four runs, with the printed counters).

set project_dir [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir  "$project_dir/rtl"
set rtl7_dir "$project_dir/rtl_7stage"
set asm_dir  "$project_dir/programs/asm"
set part     "xc7a35tcpg236-1"
set work_root ".vivado_work/o2_7stage"
set log_file "$project_dir/o2_7stage_results.log"
set tb_dir   "$work_root/tb"
file mkdir $tb_dir

# Shared functional-unit RTL (predictor added per-variant).
set shared_rtl [list \
  "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/pipe_ex_mem.sv" "$rtl_dir/pipe_mem_wb.sv" ]
set rtl7_units [list \
  "$rtl7_dir/forwarding_unit.sv" "$rtl7_dir/hazard_unit.sv" "$rtl7_dir/pipe_if1_if2.sv" ]

# (label, predictor RTL, 7-stage top)
set variants [list \
  [list "baseline" "$rtl_dir/branch_predictor.sv"     "$rtl7_dir/rv32i_pipeline_7stage_top.sv"     "rv32i_pipeline_7stage_top"] \
  [list "sgf"      "$rtl_dir/branch_predictor_sgf.sv" "$rtl7_dir/rv32i_pipeline_7stage_sgf_top.sv" "rv32i_pipeline_7stage_sgf_top"] ]

# (label, program hex, data hex, coremark? )
set benches [list \
  [list "coremark"  "$asm_dir/coremark_official_o2.hex" "$asm_dir/coremark_official_o2_data.hex" coremark] \
  [list "statemate" "$asm_dir/embench_statemate_o2.hex" "$asm_dir/embench_statemate_o2_data.hex" embench] ]

proc write_bench_tb {filepath top_module bench_name result_type} {
  set fd [open $filepath w]
  puts $fd "`timescale 1ns / 1ps"
  puts $fd "module bench_tb;"
  puts $fd "  logic clk, rst_n;"
  puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
  puts $fd "  $top_module dut (.*);"
  puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
  puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
  puts $fd "  initial begin"
  puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
  puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
  puts $fd "  end"
  puts $fd "  initial clk = 0;  always #5 clk = ~clk;"
  puts $fd "  int halt_count;  logic \[31:0\] prev_pc;"
  puts $fd "  always_ff @(posedge clk) begin"
  puts $fd "    prev_pc <= debug_pc;"
  puts $fd "    if (!rst_n) halt_count <= 0;"
  puts $fd "    else if (debug_pc\[31:3\] == prev_pc\[31:3\]) halt_count <= halt_count + 1;"
  puts $fd "    else halt_count <= 0;"
  puts $fd "  end"
  puts $fd "  initial begin"
  puts $fd "    \$display(\"=== $bench_name: $top_module (-O2) ===\");"
  puts $fd "    rst_n = 0;  repeat (5) @(posedge clk);  rst_n = 1;"
  puts $fd "    fork wait (halt_count > 1000); repeat (500000000) @(posedge clk); join_any"
  puts $fd "    repeat (10) @(posedge clk);"
  puts $fd "    \$display(\"  Cycles:         %0d\", dut.u_dmem.mem\[0\]);"
  puts $fd "    \$display(\"  Instructions:   %0d\", dut.u_dmem.mem\[1\]);"
  puts $fd "    \$display(\"  Branches:       %0d\", dut.u_dmem.mem\[2\]);"
  puts $fd "    \$display(\"  Mispredictions: %0d\", dut.u_dmem.mem\[3\]);"
  puts $fd "    if (dut.u_dmem.mem\[1\] != 0)"
  puts $fd "      \$display(\"  CPI:            %0d.%02d\","
  puts $fd "        dut.u_dmem.mem\[0\] / dut.u_dmem.mem\[1\],"
  puts $fd "        ((dut.u_dmem.mem\[0\] % dut.u_dmem.mem\[1\]) * 100) / dut.u_dmem.mem\[1\]);"
  puts $fd "    \$finish;"
  puts $fd "  end"
  puts $fd "  initial begin repeat(500000000) @(posedge clk); \$display(\"TIMEOUT\"); \$finish; end"
  puts $fd "endmodule"
  close $fd
}

set fd [open $log_file w]
puts $fd "=== -O2 Compiler-Sensitivity Run (7-stage baseline + SGF) ==="
puts $fd "=== [clock format [clock seconds]] ==="
close $fd

foreach v $variants {
  lassign $v vlabel pred top tname
  foreach b $benches {
    lassign $b blabel hex data rtype
    set proj "o2_${vlabel}_${blabel}"
    set work "$work_root/$proj"
    puts "\n=== $proj ==="
    create_project $proj $work -part $part -force
    add_files -norecurse [concat $shared_rtl [list $pred $top] $rtl7_units]
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$tb_dir/${proj}_tb.sv"
    write_bench_tb $tb_path $tname $blabel $rtype
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top bench_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    set sim_dir "$work/$proj.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $hex  "$sim_dir/program.hex"
    file copy -force $data "$sim_dir/data.hex"
    launch_simulation
    run -all
    set sim_log "$sim_dir/simulate.log"
    if {[file exists $sim_log]} {
      set fi [open $sim_log r]; set fo [open $log_file a]
      puts $fo "--- $vlabel / $blabel (-O2) ---"
      while {[gets $fi line] >= 0} { if {[string match "*:*" $line] || [string match "===*" $line]} { puts $fo $line } }
      puts $fo ""; close $fi; close $fo
    }
    close_sim -quiet
    close_project -quiet
    file delete -force $work
  }
}
puts "=== -O2 runs complete. See $log_file ==="
