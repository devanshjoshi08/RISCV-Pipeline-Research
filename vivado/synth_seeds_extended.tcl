# synth_seeds_extended.tcl - 10 placement/routing directive combinations per variant.
# 5 variants x 10 runs = 50 synthesis runs total.
# Based on the proven synth_seeds.tcl structure.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set log_file    "$project_dir/seed_results_extended.log"
set part        "xc7a35tcpg236-1"
set clk_xdc     "$project_dir/synth_clk_only.xdc"

set fd [open $log_file w]
puts $fd "=== Multi-Run Extended Synthesis Results (10 seeds) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd "variant,run,Fmax_MHz,WNS_ns,LUTs,FFs"
close $fd

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

# Place/route directives for each of the 10 runs
set place_directives [list \
    "Default" \
    "Explore" \
    "Default" \
    "ExtraNetDelay_high" \
    "SpreadLogic_high" \
    "ExtraPostPlacementOpt" \
    "AltSpreadLogic_high" \
    "ExtraNetDelay_low" \
    "Default" \
    "Explore" \
]
set route_directives [list \
    "Default" \
    "Explore" \
    "NoTimingRelaxation" \
    "Explore" \
    "Default" \
    "AggressiveExplore" \
    "NoTimingRelaxation" \
    "Explore" \
    "AggressiveExplore" \
    "NoTimingRelaxation" \
]

proc synth_one {name work_dir top_module rtl_files run_num} {
    global part clk_xdc log_file place_directives route_directives

    set proj_name "${name}_r${run_num}"
    set pdir [lindex $place_directives [expr {$run_num - 1}]]
    set rdir [lindex $route_directives [expr {$run_num - 1}]]
    puts "\n  $proj_name: synth + impl (place=$pdir route=$rdir)..."

    create_project $proj_name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $top_module [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

    # Set placement and routing directives
    set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE $pdir [get_runs impl_1]
    set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE $rdir [get_runs impl_1]

    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    open_run impl_1

    # Extract WNS
    set timing_rpt [report_timing_summary -return_string -no_header]
    set wns "N/A"
    set fmax "N/A"
    foreach line [split $timing_rpt "\n"] {
        if {[regexp {^\s+(-?\d+\.\d+)\s+} $line match val]} {
            if {$wns eq "N/A"} {
                set wns $val
                set actual_period [expr {5.0 - $wns}]
                if {$actual_period > 0} {
                    set fmax [format "%.1f" [expr {1000.0 / $actual_period}]]
                }
            }
        }
    }

    # Extract LUTs and FFs
    set util_rpt [report_utilization -return_string]
    set luts "N/A"
    set ffs "N/A"
    foreach line [split $util_rpt "\n"] {
        if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line match val]} { set luts $val }
        if {[regexp {Slice Registers\s*\|\s*(\d+)} $line match val]} { set ffs $val }
    }

    puts "    Fmax=$fmax WNS=$wns LUTs=$luts FFs=$ffs"

    set fd [open $log_file a]
    puts $fd "$name,$run_num,$fmax,$wns,$luts,$ffs"
    close $fd

    close_design
    close_project -quiet
}

set variants [list \
    [list "4stage" "rv32i_pipeline_4stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
            "$github_dir/rtl_4stage/forwarding_unit.sv" \
            "$github_dir/rtl_4stage/hazard_unit.sv"]]] \
    [list "5stage" "rv32i_pipeline_5stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
            "$github_dir/rtl_5stage/forwarding_unit.sv" \
            "$github_dir/rtl_5stage/hazard_unit.sv"]]] \
    [list "6stage" "rv32i_pipeline_top" \
        [concat $shared_rtl [list \
            "$rtl_dir/pipe_ex1_ex2.sv" \
            "$rtl_dir/forwarding_unit.sv" \
            "$rtl_dir/hazard_unit.sv" \
            "$rtl_dir/rv32i_pipeline_top.sv"]]] \
    [list "7stage" "rv32i_pipeline_7stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
                  "$github_dir/rtl_7stage/forwarding_unit.sv" \
                  "$github_dir/rtl_7stage/hazard_unit.sv" \
                  "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]] \
    [list "8stage" "rv32i_pipeline_8stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
                  "$github_dir/rtl_8stage/forwarding_unit.sv" \
                  "$github_dir/rtl_8stage/hazard_unit.sv" \
                  "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
                  "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]] \
]

foreach variant $variants {
    set vname [lindex $variant 0]
    set vtop  [lindex $variant 1]
    set vrtl  [lindex $variant 2]

    puts "\n=== $vname ==="
    for {set r 1} {$r <= 10} {incr r} {
        synth_one $vname "$project_dir/vivado_seeds_ext/${vname}_r${r}" $vtop $vrtl $r
    }
}

puts "\n================================================================"
puts "  ALL 50 EXTENDED SYNTHESIS RUNS COMPLETE"
puts "  Results in: $log_file"
puts "================================================================\n"
