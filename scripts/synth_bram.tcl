# synth_bram.tcl - Synthesize BRAM variants of all 3 pipelines.
# Results saved to bram_synth_results.log.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set github_dir  [file normalize [file dirname [file dirname [info script]]]]
set log_file    "$project_dir/bram_synth_results.log"
set part        "xc7a35tcpg236-1"

set clk_xdc "$project_dir/synth_clk_only.xdc"

set fd [open $log_file w]
puts $fd "=== BRAM Variant Synthesis Results ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" \
    "$rtl_dir/imem_bram.sv" "$rtl_dir/icache_bram.sv" \
    "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

proc synth_bram_variant {name work_dir top_module rtl_files} {
    global part clk_xdc log_file

    puts "\n  Synthesizing BRAM: $name ($top_module)"
    create_project $name $work_dir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $top_module [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    update_compile_order -fileset sources_1

    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1
    open_run impl_1

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

    set util_rpt [report_utilization -return_string]
    set luts "N/A"; set ffs "N/A"; set dsps "N/A"; set brams "N/A"
    foreach line [split $util_rpt "\n"] {
        if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line match val]} { set luts $val }
        if {[regexp {Slice Registers\s*\|\s*(\d+)} $line match val]} { set ffs $val }
        if {[regexp {DSPs\s*\|\s*(\d+)} $line match val]} { set dsps $val }
        if {[regexp {Block RAM Tile\s*\|\s*(\d+)} $line match val]} { set brams $val }
    }

    set fd [open $log_file a]
    puts $fd "------------------------------------------------------------"
    puts $fd "  $name ($top_module)"
    puts $fd "------------------------------------------------------------"
    puts $fd "  Fmax (est) : $fmax MHz"
    puts $fd "  WNS        : $wns ns"
    puts $fd "  LUTs       : $luts"
    puts $fd "  FFs        : $ffs"
    puts $fd "  DSPs       : $dsps"
    puts $fd "  BRAMs      : $brams"
    puts $fd ""
    close $fd

    puts "  $name: Fmax=$fmax MHz, LUTs=$luts, FFs=$ffs, BRAMs=$brams"
    close_design
    close_project -quiet
}

# 5-stage BRAM
set rtl5 [concat $shared_rtl [list \
    "$github_dir/rtl_5stage/forwarding_unit.sv" \
    "$github_dir/rtl_5stage/hazard_unit.sv" \
    "$github_dir/rtl_5stage/rv32i_pipeline_5stage_bram_top.sv"]]
synth_bram_variant "bram_5s" "$project_dir/vivado_bram/5stage" \
    "rv32i_pipeline_5stage_bram_top" $rtl5

# 6-stage BRAM
set rtl6 [concat $shared_rtl [list \
    "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" \
    "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_bram_top.sv"]]
synth_bram_variant "bram_6s" "$project_dir/vivado_bram/6stage" \
    "rv32i_pipeline_bram_top" $rtl6

# 7-stage BRAM
set rtl7 [concat $shared_rtl [list \
    "$rtl_dir/pipe_ex1_ex2.sv" \
    "$github_dir/rtl_7stage/forwarding_unit.sv" \
    "$github_dir/rtl_7stage/hazard_unit.sv" \
    "$github_dir/rtl_7stage/pipe_if1_if2.sv" \
    "$github_dir/rtl_7stage/rv32i_pipeline_7stage_bram_top.sv"]]
synth_bram_variant "bram_7s" "$project_dir/vivado_bram/7stage" \
    "rv32i_pipeline_7stage_bram_top" $rtl7

puts "\n================================================================"
puts "  BRAM SYNTHESIS COMPLETE - Results in: $log_file"
puts "================================================================\n"
