# run_tournament_7stage.tcl - measured tournament-predictor evaluation.
# Runs CoreMark, statemate, aha-mont64, crc32 on the 7-stage baseline-tournament
# and SGF-tournament variants (XSim), then synthesizes both for F_max/area.
# Tests whether the tournament's GHR-indexed components (global PHT + chooser)
# exhibit Mechanism B and whether SGF removes it, as the paper projects.
#
# Source from the GitHub repo copy (canonical rtl_7stage):
#   source <repo>/scripts/run_tournament_7stage.tcl
# Output: tournament_results.log  (benchmark counts) and tournament_synth_results.log
#
# DETERMINISM GATE: for each workload, the Instructions and Branches counts MUST be
# identical for baseline and SGF (the predictor is performance-only). If they differ,
# the tournament RTL has a bug and the misprediction numbers are meaningless -- fix
# before trusting results.

set project_dir [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir  "$project_dir/rtl"
set rtl7_dir "$project_dir/rtl_7stage"
set asm_dir  "$project_dir/programs/asm"
set part     "xc7a35tcpg236-1"
set work_root ".vivado_work/tournament"
set log_file "$project_dir/tournament_results.log"
set synth_log "$project_dir/tournament_synth_results.log"
set tb_dir   "$work_root/tb"
file mkdir $tb_dir

set shared_rtl [list \
  "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/pipe_ex_mem.sv" "$rtl_dir/pipe_mem_wb.sv" ]
set rtl7_units [list \
  "$rtl7_dir/forwarding_unit.sv" "$rtl7_dir/hazard_unit.sv" "$rtl7_dir/pipe_if1_if2.sv" ]

# (label, predictor RTL, top file, top module)
set variants [list \
  [list "base" "$rtl_dir/branch_predictor_tournament.sv"     "$rtl7_dir/rv32i_pipeline_7stage_tournament_top.sv"     "rv32i_pipeline_7stage_tournament_top"] \
  [list "sgf"  "$rtl_dir/branch_predictor_tournament_sgf.sv" "$rtl7_dir/rv32i_pipeline_7stage_tournament_sgf_top.sv" "rv32i_pipeline_7stage_tournament_sgf_top"] ]

# (label, program hex, data hex)
set benches [list \
  [list "coremark"   "$project_dir/programs/coremark/coremark.hex" "$project_dir/programs/coremark/data.hex"] \
  [list "statemate"  "$asm_dir/embench_statemate.hex"  "$asm_dir/embench_statemate_data.hex"] \
  [list "aha-mont64" "$asm_dir/embench_aha-mont64.hex" "$asm_dir/embench_aha-mont64_data.hex"] \
  [list "crc32"      "$asm_dir/embench_crc32.hex"      "$asm_dir/embench_crc32_data.hex"] ]

proc write_bench_tb {filepath top_module bench_name} {
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
  puts $fd "    \$display(\"=== $bench_name: $top_module ===\");"
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
puts $fd "=== Tournament predictor: baseline vs SGF (7-stage) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "DETERMINISM GATE: Instructions and Branches must match base vs sgf per workload."
close $fd

foreach v $variants {
  lassign $v vlabel pred top tname
  foreach b $benches {
    lassign $b blabel hex data
    set proj "tour_${vlabel}_${blabel}"
    set work "$work_root/$proj"
    puts "\n=== $proj ==="
    create_project $proj $work -part $part -force
    add_files -norecurse [concat $shared_rtl [list $pred $top] $rtl7_units]
    set_property file_type SystemVerilog [get_files *.sv]
    set tb_path "$tb_dir/${proj}_tb.sv"
    write_bench_tb $tb_path $tname $blabel
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
    set slog "$sim_dir/simulate.log"
    if {[file exists $slog]} {
      set fi [open $slog r]; set fo [open $log_file a]
      puts $fo "--- $vlabel / $blabel ---"
      while {[gets $fi line] >= 0} { if {[string match "*:*" $line] || [string match "===*" $line]} { puts $fo $line } }
      puts $fo ""; close $fi; close $fo
    }
    close_sim -quiet
    close_project -quiet
    file delete -force $work
  }
}
puts "=== benchmarks done: $log_file ==="

# --- Synthesis: F_max + area, 3 seeds each, OOC ---
set clk_xdc "$work_root/clk_only.xdc"
set xf [open $clk_xdc w]; puts $xf "create_clock -period 5.000 -name clk \[get_ports clk\]"; close $xf
set place_dirs [list "Default" "Explore" "Default"]
set route_dirs [list "Default" "Explore" "NoTimingRelaxation"]
set sf [open $synth_log w]
puts $sf "=== Tournament synthesis (7-stage) ==="
puts $sf "variant,run,Fmax_MHz,WNS_ns,LUTs,FFs"
close $sf

foreach v $variants {
  lassign $v vlabel pred top tname
  for {set r 1} {$r <= 3} {incr r} {
    set pdir [lindex $place_dirs [expr {$r-1}]]; set rdir [lindex $route_dirs [expr {$r-1}]]
    set proj "tsyn_${vlabel}_r$r"; set work "$work_root/$proj"
    create_project $proj $work -part $part -force
    add_files -norecurse [concat $shared_rtl [list $pred $top] $rtl7_units]
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $tname [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $pdir [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $rdir [get_runs impl_1]
    update_compile_order -fileset sources_1
    launch_runs synth_1 -jobs 4; wait_on_run synth_1
    launch_runs impl_1 -jobs 4;  wait_on_run impl_1
    open_run impl_1
    set wns "N/A"; set fmax "N/A"
    foreach line [split [report_timing_summary -return_string -no_header] "\n"] {
      if {[regexp {^\s+(-?\d+\.\d+)\s+} $line m val] && $wns eq "N/A"} {
        set wns $val; set p [expr {5.0 - $wns}]
        if {$p > 0} { set fmax [format "%.1f" [expr {1000.0/$p}]] }
      }
    }
    set luts "N/A"; set ffs "N/A"
    foreach line [split [report_utilization -return_string] "\n"] {
      if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line m val]} { set luts $val }
      if {[regexp {Slice Registers\s*\|\s*(\d+)} $line m val]} { set ffs $val }
    }
    set sf [open $synth_log a]; puts $sf "$vlabel,$r,$fmax,$wns,$luts,$ffs"; close $sf
    close_design; close_project -quiet; file delete -force $work
  }
}
puts "=== tournament evaluation complete: $log_file , $synth_log ==="
