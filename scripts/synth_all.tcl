# synth_all.tcl — Synthesize + Implement all 3 pipeline variants.
# Extracts Fmax, LUT, FF, DSP, BRAM for each.
# Results saved to synth_results.log
#
# Usage: close Vivado, reopen, then:
#   cd C:/Users/Joshi/RISCV-Vivado
#   source synth_all.tcl

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set log_file    "$project_dir/synth_results.log"
set part        "xc7a35tcpg236-1"

# Minimal clock-only constraint for Fmax extraction
set clk_xdc "$project_dir/synth_clk_only.xdc"
set fd [open $clk_xdc w]
puts $fd "create_clock -period 5.000 -name clk \[get_ports clk\]"
puts $fd "set_property IOSTANDARD LVCMOS33 \[get_ports clk\]"
puts $fd "set_property IOSTANDARD LVCMOS33 \[get_ports rst_n\]"
close $fd

# Initialize log
set fd [open $log_file w]
puts $fd "============================================================"
puts $fd "  RISC-V Pipeline Synthesis Results"
puts $fd "  Target: $part (Artix-7, Basys 3)"
puts $fd "  Clock constraint: 200 MHz (5ns period)"
puts $fd "  Date: [clock format [clock seconds]]"
puts $fd "============================================================"
puts $fd ""
close $fd

# =====================================================================
# Shared RTL files
# =====================================================================
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

# =====================================================================
# Helper: synth + implement one variant, extract results
# =====================================================================
proc synth_variant {name work_dir top_module rtl_files} {
    global part clk_xdc log_file

    puts "\n================================================================"
    puts "  Synthesizing: $name (top: $top_module)"
    puts "================================================================\n"

    # Create project
    create_project $name $work_dir -part $part -force

    # Add RTL
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    # Add clock constraint
    add_files -fileset constrs_1 -norecurse $clk_xdc

    # Set top and out-of-context mode (no IO buffers — pure core logic comparison)
    set_property top $top_module [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
    update_compile_order -fileset sources_1

    # Run synthesis
    puts "  Running synthesis..."
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1

    # Run implementation (place + route)
    puts "  Running implementation..."
    set_property -name {STEPS.PLACE_DESIGN.ARGS.MORE OPTIONS} -value {} -objects [get_runs impl_1]
    launch_runs impl_1 -jobs 4
    wait_on_run impl_1

    # Open implemented design to extract reports
    open_run impl_1

    # Extract timing
    set timing_rpt [report_timing_summary -return_string -no_header]
    set wns "N/A"
    set fmax "N/A"
    # Find WNS line
    foreach line [split $timing_rpt "\n"] {
        if {[regexp {^\s+(-?\d+\.\d+)\s+} $line match val]} {
            if {$wns eq "N/A"} {
                set wns $val
                # Fmax = 1000 / (period - WNS)  where period = 5ns
                set actual_period [expr {5.0 - $wns}]
                if {$actual_period > 0} {
                    set fmax [format "%.1f" [expr {1000.0 / $actual_period}]]
                }
            }
        }
    }

    # Extract utilization
    set util_rpt [report_utilization -return_string]
    set luts "N/A"
    set ffs  "N/A"
    set dsps "N/A"
    set brams "N/A"
    foreach line [split $util_rpt "\n"] {
        if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line match val]} { set luts $val }
        if {[regexp {Slice Registers\s*\|\s*(\d+)} $line match val]} { set ffs $val }
        if {[regexp {DSPs\s*\|\s*(\d+)} $line match val]} { set dsps $val }
        if {[regexp {Block RAM Tile\s*\|\s*(\d+)} $line match val]} { set brams $val }
    }

    # Write to log
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

    # Also print to console
    puts ""
    puts "  === $name Results ==="
    puts "  Fmax : $fmax MHz  (WNS: $wns ns)"
    puts "  LUTs : $luts   FFs: $ffs   DSPs: $dsps   BRAMs: $brams"
    puts ""

    close_design
    close_project -quiet
}

# =====================================================================
# 5-STAGE
# =====================================================================
set rtl5 [concat $shared_rtl [glob "$project_dir/rtl_5stage/*.sv"]]
synth_variant "synth_5stage" "$project_dir/vivado_synth/5stage" \
    "rv32i_pipeline_5stage_top" $rtl5

# =====================================================================
# 6-STAGE (baseline)
# =====================================================================
set rtl6 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_top.sv"]]
synth_variant "synth_6stage" "$project_dir/vivado_synth/6stage" \
    "rv32i_pipeline_top" $rtl6

# =====================================================================
# 7-STAGE
# =====================================================================
set rtl7 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [glob "$project_dir/rtl_7stage/*.sv"]]
synth_variant "synth_7stage" "$project_dir/vivado_synth/7stage" \
    "rv32i_pipeline_7stage_top" $rtl7

# =====================================================================
puts "\n================================================================"
puts "  ALL SYNTHESIS COMPLETE"
puts "  Results saved to: $log_file"
puts "================================================================\n"
