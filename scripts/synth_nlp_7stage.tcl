# synth_nlp_7stage.tcl - post-place-and-route F_max for the NLP-augmented cores
# (TC review item D). Synthesizes the 7-stage NLP and SGF+NLP tops out-of-context
# across 3 placement/routing directive pairs (same method as the SGF synth) so the
# IF1-redirect path's effect on F_max can be checked against the deep-tier baseline
# (115.0 MHz) and SGF (117.5 MHz).
#
# Source from the GitHub repo copy (canonical rtl_7stage):
#   source C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor/scripts/synth_nlp_7stage.tcl
# Output: nlp_synth_results.log  (variant,run,Fmax_MHz,WNS_ns,LUTs,FFs)

set project_dir [file normalize [file dirname [file dirname [info script]]]]
set rtl_dir  "$project_dir/rtl"
set rtl7_dir "$project_dir/rtl_7stage"
set part     "xc7a35tcpg236-1"
set work_root "D:/RISCV-Vivado/nlp_synth"
set log_file "$project_dir/nlp_synth_results.log"

set clk_xdc "$work_root/clk_only.xdc"
file mkdir $work_root
set fd [open $clk_xdc w]
puts $fd "create_clock -period 5.000 -name clk \[get_ports clk\]"
close $fd

set shared_rtl [list \
  "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/pipe_ex_mem.sv" "$rtl_dir/pipe_mem_wb.sv" ]
set rtl7_units [list \
  "$rtl7_dir/forwarding_unit.sv" "$rtl7_dir/hazard_unit.sv" "$rtl7_dir/pipe_if1_if2.sv" ]

# (label, predictor, top file, top module)
set variants [list \
  [list "nlp"     "$rtl_dir/branch_predictor.sv"     "$rtl7_dir/rv32i_pipeline_7stage_nlp_top.sv"     "rv32i_pipeline_7stage_nlp_top"] \
  [list "sgf_nlp" "$rtl_dir/branch_predictor_sgf.sv" "$rtl7_dir/rv32i_pipeline_7stage_sgf_nlp_top.sv" "rv32i_pipeline_7stage_sgf_nlp_top"] ]

set place_dirs [list "Default" "Explore" "Default"]
set route_dirs [list "Default" "Explore" "NoTimingRelaxation"]

set fd [open $log_file w]
puts $fd "=== NLP / SGF+NLP 7-stage synthesis ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "variant,run,Fmax_MHz,WNS_ns,LUTs,FFs"
close $fd

foreach v $variants {
  lassign $v vlabel pred top tname
  for {set r 1} {$r <= 3} {incr r} {
    set pdir [lindex $place_dirs [expr {$r-1}]]
    set rdir [lindex $route_dirs [expr {$r-1}]]
    set proj "${vlabel}_r$r"
    set work "$work_root/$proj"
    puts "\n  $proj: synth+impl (place=$pdir route=$rdir)..."
    create_project $proj $work -part $part -force
    add_files -norecurse [concat $shared_rtl [list $pred $top] $rtl7_units]
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $tname [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $pdir [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $rdir [get_runs impl_1]
    update_compile_order -fileset sources_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    open_run impl_1

    set wns "N/A"; set fmax "N/A"
    foreach line [split [report_timing_summary -return_string -no_header] "\n"] {
      if {[regexp {^\s+(-?\d+\.\d+)\s+} $line m val]} {
        if {$wns eq "N/A"} { set wns $val
          set p [expr {5.0 - $wns}]
          if {$p > 0} { set fmax [format "%.1f" [expr {1000.0/$p}]] } }
      }
    }
    set luts "N/A"; set ffs "N/A"
    foreach line [split [report_utilization -return_string] "\n"] {
      if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line m val]} { set luts $val }
      if {[regexp {Slice Registers\s*\|\s*(\d+)} $line m val]} { set ffs $val }
    }
    puts "    Fmax=$fmax WNS=$wns LUTs=$luts FFs=$ffs"
    set fd [open $log_file a]
    puts $fd "$vlabel,$r,$fmax,$wns,$luts,$ffs"
    close $fd
    close_design
    close_project -quiet
    file delete -force $work
  }
}
puts "\n=== NLP synthesis complete. See $log_file ==="
