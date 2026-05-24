# synth_nlp_7stage.tcl - post-place-and-route F_max for the NLP-augmented cores
# (TC review item D). Synthesizes the 7-stage NLP and SGF+NLP tops out-of-context
# under the same 10-seed placement-directive methodology as tab:results, so the
# IF1-redirect path's effect on F_max can be confirmed against the deep-tier
# baseline (115.0 MHz) and SGF (117.5 MHz).
#
# IMPORTANT: source this from the GitHub repo copy so it uses the CANONICAL
# rtl/ and rtl_7stage/ (the D:/RISCV-Vivado mirror lacks the if2_redirect/ras_push
# gates and yields wrong results). Vivado's cwd may be on D:; that is fine, the
# RTL paths below are resolved relative to THIS script's location, not the cwd.
# Scratch projects are written under D: (work_root) and auto-deleted per seed.
#
# Run in the interactive Vivado Tcl console:  source <github>/scripts/synth_nlp_7stage.tcl
# Output: nlp_synth_results.log  (variant,seed,Fmax_MHz,WNS_ns,LUTs,FFs)
# Transcribe the per-variant mean +/- std into the paper next to the SGF synth
# numbers and update the NLP F_max caveat in Section VI-D.

set project_dir [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir  "$project_dir/rtl"
set rtl7_dir "$project_dir/rtl_7stage"
set part     "xc7a35tcpg236-1"
set work_root "D:/RISCV-Vivado/nlp_synth"
set log_file "$project_dir/nlp_synth_results.log"

# Shared functional-unit RTL (identical to the other variants).
set shared_base [list \
  "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/pipe_ex_mem.sv" "$rtl_dir/pipe_mem_wb.sv" \
  "$rtl_dir/branch_predictor.sv" "$rtl_dir/branch_predictor_sgf.sv" ]

# (top module, label) for the two NLP variants under test.
set variants [list \
  [list "rv32i_pipeline_7stage_nlp_top"     "nlp"] \
  [list "rv32i_pipeline_7stage_sgf_nlp_top" "sgf_nlp"] ]

# Same 10 placement/routing directive pairings as the baseline study.
set directives [list \
  {Default Default} {Explore Explore} {Default NoTimingRelaxation} \
  {ExtraNetDelay_high Explore} {Default Default} {ExtraPostPlacementOpt AggressiveExplore} \
  {Explore NoTimingRelaxation} {ExtraNetDelay_low Explore} {Default AggressiveExplore} \
  {Explore NoTimingRelaxation} ]

# Clock-only constraint (200 MHz target) for F_max extraction.
set clk_xdc "$project_dir/nlp_synth_clk_only.xdc"
set fd [open $clk_xdc w]
puts $fd "create_clock -period 5.000 -name clk \[get_ports clk\]"
close $fd

set fd [open $log_file w]
puts $fd "=== NLP / SGF+NLP 7-stage synthesis (10 seeds) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "variant,seed,Fmax_MHz,WNS_ns,LUTs,FFs"
close $fd

foreach v $variants {
  lassign $v top label
  set seed 0
  foreach d $directives {
    incr seed
    lassign $d synthdir impldir
    set work "$work_root/${label}_s$seed"
    file delete -force $work
    create_project nlp_$label $work -part $part -force
    add_files -norecurse [concat $shared_base [glob $rtl7_dir/*.sv]]
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $top [current_fileset]
    set_property strategy "Flow_PerfOptimized_high" [get_runs synth_1]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE} -value $synthdir -objects [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $synthdir [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $impldir  [get_runs impl_1]
    launch_runs impl_1 -to_step route_design -jobs 4
    wait_on_run impl_1
    open_run impl_1
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
    set fmax [expr {1000.0/(5.0 - $wns)}]
    set luts [get_property STATS.SLICE_LUTS [get_runs impl_1]]
    set ffs  [get_property STATS.SLICE_REGISTERS [get_runs impl_1]]
    set fd [open $log_file a]
    puts $fd [format "%s,%d,%.1f,%.3f,%s,%s" $label $seed $fmax $wns $luts $ffs]
    close $fd
    close_project
    file delete -force $work
  }
}
puts "Done. See $log_file. Expect deep-tier F_max (~115-118 MHz) if the IF1 redirect does not create a new critical path."
