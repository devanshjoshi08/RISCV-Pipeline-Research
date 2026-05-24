# run_O2_7stage.tcl - Compiler-sensitivity experiment (TC review item #3).
# Runs CoreMark and statemate at -O2 on the 7-stage baseline and 7-stage SGF
# variants and logs instruction/branch/misprediction/cycle counts so Mechanism B
# persistence and SGF's reduction can be re-evaluated under -O2.
#
# PREREQUISITES:
#   1. bash scripts/build_O2_benchmarks.sh   (produces *_o2 hex in programs/asm)
#   2. Run this in the interactive Vivado Tcl console:  source scripts/run_O2_7stage.tcl
#   3. Use the CANONICAL github rtl_7stage (NOT the D: mirror), per project notes:
#      the D: 7-stage RTL lacks the if2_redirect/ras_push gates and gives wrong counts.
#
# After it finishes, read o2_7stage_results.log and transcribe the four rows
# (CoreMark/statemate x baseline/SGF) into Table tab:o2 in the paper.

set project_dir [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir   "$project_dir/rtl"
set rtl7_dir  "$project_dir/rtl_7stage"
set tb7_dir   "$project_dir/tb_7stage"
set prog_dir  "$project_dir/programs/asm"
set part      "xc7a35tcpg236-1"
set work_root "D:/RISCV-Vivado/o2_7stage"
set log_file  "$project_dir/o2_7stage_results.log"

set shared_base [list \
  "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/pipe_ex_mem.sv" "$rtl_dir/pipe_mem_wb.sv" ]

# (top module, predictor RTL, label) for the two variants under test.
set variants [list \
  [list "rv32i_pipeline_7stage_top"     "$rtl_dir/branch_predictor.sv"     "baseline"] \
  [list "rv32i_pipeline_7stage_sgf_top" "$rtl_dir/branch_predictor_sgf.sv" "sgf"] ]

# (program hex, data hex or {}, label) at -O2.
set benches [list \
  [list "coremark_official_o2.hex"      {}                              "coremark"] \
  [list "embench_statemate_o2.hex"      "embench_statemate_o2_data.hex" "statemate"] ]

set fd [open $log_file w]
puts $fd "=== -O2 Compiler-Sensitivity Run (7-stage baseline + SGF) ==="
puts $fd "=== [clock format [clock seconds]] ==="
close $fd

foreach v $variants {
  lassign $v top pred label
  set work "$work_root/$label"
  file mkdir $work
  create_project o2_$label $work -part $part -force
  add_files -norecurse [concat $shared_base [list $pred]]
  add_files -norecurse [glob $rtl7_dir/*.sv]
  set_property file_type SystemVerilog [get_files *.sv]
  add_files -fileset sim_1 -norecurse [glob $tb7_dir/*.sv]
  set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
  set_property top $top [current_fileset]
  # NOTE: confirm the sim top matches your 7-stage benchmark testbench module name.
  set_property top rv32i_7stage_tb [get_filesets sim_1]

  set sim_dir "$work/o2_$label.sim/sim_1/behav/xsim"
  file mkdir $sim_dir
  update_compile_order -fileset sources_1
  update_compile_order -fileset sim_1

  foreach b $benches {
    lassign $b hex data blabel
    # IMPORTANT: disable waveform dumping. Long CoreMark/statemate runs otherwise
    # fill the disk with multi-GB .wdb/.xilwvdat temps (a known hazard here).
    file copy -force "$prog_dir/$hex" "$sim_dir/program.hex"
    if {$data ne ""} { file copy -force "$prog_dir/$data" "$sim_dir/data.hex" }
    puts "=== running $label / $blabel (-O2) ==="
    launch_simulation -noclean_dir
    run all
    # The testbench prints Cycles/Instructions/Branches/Mispredictions to the
    # console; capture them from the xsim log into the results file.
    set fd [open $log_file a]
    puts $fd "--- $label / $blabel (-O2) ---"
    puts $fd "  (transcribe Cycles/Instructions/Branches/Mispredictions from xsim console)"
    close $fd
    close_sim
  }
  close_project
}

puts "=== -O2 runs complete. See $log_file ==="
# TODO(author): record per-run counts, recompute IBD at -O2, and fill Table tab:o2.
