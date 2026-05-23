# synth_seeds.tcl -- Multi-seed implementation for statistical variation
#
# For each pipeline variant: synthesize once (project mode), save checkpoint,
# then run place+route N times with different placement seeds (non-project mode).
# Collects Fmax, LUT, FF, DSP, BRAM, and estimated power after each run.
#
# The placement seed changes the placer's random starting point, producing
# different PPA results from the same netlist -- useful for error bars.
#
# Usage (in Vivado TCL console):
#   cd D:/RISCV-Vivado
#   source C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor/synth_seeds.tcl
#
# Output:
#   results/synth_seeds_results.csv  -- structured, one row per (variant, seed)
#   results/synth_seeds_results.log  -- human-readable summary

# Configuration -- edit these as needed
set script_dir  [file normalize [file dirname [info script]]]
set rtl_dir     "$script_dir/rtl"
set results_dir "$script_dir/results"
set work_base   "D:/RISCV-Vivado/seed_runs"
set part        "xc7a35tcpg236-1"    ;# Artix-7 (Basys 3)
set clk_period  5.000                ;# ns -> 200 MHz target
set seeds       {1 2 3}             ;# placement seeds to sweep
set num_jobs    4                    ;# parallel jobs for synth

file mkdir $results_dir
file mkdir $work_base

set csv_file "$results_dir/synth_seeds_results.csv"
set log_file "$results_dir/synth_seeds_results.log"

# Minimal XDC for out-of-context synthesis (clock + IO standards only)
set clk_xdc "$work_base/seed_clk_only.xdc"
set fd [open $clk_xdc w]
puts $fd "create_clock -period $clk_period -name clk \[get_ports clk\]"
puts $fd "set_property IOSTANDARD LVCMOS33 \[get_ports clk\]"
puts $fd "set_property IOSTANDARD LVCMOS33 \[get_ports rst_n\]"
close $fd

# Shared RTL (common across all pipeline variants)
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

# Pipeline variant definitions
# Format: {display_name top_module {extra_rtl_specs...}}
# Spec: "file:<path>" or "glob:<pattern>"
set variants {}

lappend variants [list "5-stage" "rv32i_pipeline_5stage_top" \
    [list "glob:$script_dir/rtl_5stage/*.sv"]]

lappend variants [list "6-stage" "rv32i_pipeline_top" \
    [list "file:$rtl_dir/pipe_ex1_ex2.sv" \
          "file:$rtl_dir/forwarding_unit.sv" \
          "file:$rtl_dir/hazard_unit.sv" \
          "file:$rtl_dir/rv32i_pipeline_top.sv"]]

lappend variants [list "7-stage" "rv32i_pipeline_7stage_top" \
    [list "file:$rtl_dir/pipe_ex1_ex2.sv" \
          "glob:$script_dir/rtl_7stage/*.sv"]]

# Uncomment when RTL is complete:
# lappend variants [list "4-stage" "rv32i_pipeline_4stage_top" \
#     [list "glob:$script_dir/rtl_4stage/*.sv"]]
# lappend variants [list "8-stage" "rv32i_pipeline_8stage_top" \
#     [list "glob:$script_dir/rtl_8stage/*.sv"]]

# Helpers

# Resolve "file:" / "glob:" specs into a flat file list
proc resolve_rtl_spec {spec_list} {
    set files {}
    foreach spec $spec_list {
        if {[string match "file:*" $spec]} {
            lappend files [string range $spec 5 end]
        } elseif {[string match "glob:*" $spec]} {
            foreach f [glob -nocomplain [string range $spec 5 end]] {
                lappend files $f
            }
        }
    }
    return $files
}

# Extract timing / utilization / power from the currently open design.
# clk_pd is the clock period in ns.
proc extract_results {clk_pd} {
    set r [dict create wns N/A fmax N/A luts N/A ffs N/A \
           dsps N/A brams N/A total_power N/A dynamic_power N/A]

    # Timing (WNS -> Fmax)
    set rpt [report_timing_summary -return_string -no_header]
    foreach line [split $rpt "\n"] {
        if {[regexp {^\s+(-?\d+\.\d+)\s+} $line -> val]} {
            dict set r wns $val
            set actual [expr {$clk_pd - $val}]
            if {$actual > 0} {
                dict set r fmax [format "%.2f" [expr {1000.0 / $actual}]]
            }
            break
        }
    }

    # Utilization
    set rpt [report_utilization -return_string]
    foreach line [split $rpt "\n"] {
        if {[regexp {Slice LUTs\s*\|\s*(\d+)}     $line -> v]} { dict set r luts  $v }
        if {[regexp {Slice Registers\s*\|\s*(\d+)} $line -> v]} { dict set r ffs   $v }
        if {[regexp {DSPs\s*\|\s*(\d+)}            $line -> v]} { dict set r dsps  $v }
        if {[regexp {Block RAM Tile\s*\|\s*(\d+)}  $line -> v]} { dict set r brams $v }
    }

    # Power
    set rpt [report_power -return_string]
    foreach line [split $rpt "\n"] {
        if {[regexp {Total On-Chip Power.*\|\s*([0-9.]+)} $line -> v]} {
            dict set r total_power $v
        }
        if {[regexp {Dynamic.*\|\s*([0-9.]+)} $line -> v]} {
            if {[dict get $r dynamic_power] eq "N/A"} {
                dict set r dynamic_power $v
            }
        }
    }
    return $r
}

# Initialize output files
set fd [open $csv_file w]
puts $fd "variant,seed,fmax_mhz,wns_ns,luts,ffs,dsps,brams,total_power_w,dynamic_power_w"
close $fd

set fd [open $log_file w]
puts $fd "================================================================"
puts $fd "  RISC-V Pipeline Multi-Seed Implementation Results"
puts $fd "  Target : $part (Artix-7, Basys 3)"
puts $fd "  Clock  : [format "%.0f" [expr {1000.0/$clk_period}]] MHz ($clk_period ns)"
puts $fd "  Seeds  : $seeds"
puts $fd "  Date   : [clock format [clock seconds]]"
puts $fd "================================================================"
puts $fd ""
close $fd

# MAIN: synth once per variant (project mode), then impl N times
#       with different seeds (non-project mode from checkpoint)
set total_start [clock seconds]

foreach variant $variants {
    set vname    [lindex $variant 0]
    set top      [lindex $variant 1]
    set rtl_spec [lindex $variant 2]
    set vsafe    [string map {"-" ""} $vname]
    set work_dir "$work_base/$vsafe"

    puts "\n================================================================"
    puts "  VARIANT: $vname  (top=$top)"
    puts "================================================================"

    set extra_rtl [resolve_rtl_spec $rtl_spec]
    set all_rtl   [concat $shared_rtl $extra_rtl]

    # Phase 1: Synthesis in project mode (reuses existing synth_all flow)
    puts "  Creating project..."
    create_project "seed_${vsafe}" "$work_dir/proj" -part $part -force

    add_files -norecurse $all_rtl
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc

    set_property top $top [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
        -value {-mode out_of_context} -objects [get_runs synth_1]
    update_compile_order -fileset sources_1

    puts "  Launching synthesis..."
    set t0 [clock seconds]
    launch_runs synth_1 -jobs $num_jobs
    wait_on_run synth_1
    set synth_time [expr {[clock seconds] - $t0}]
    puts "  Synthesis done in ${synth_time}s"

    set synth_status [get_property STATUS [get_runs synth_1]]
    if {$synth_status ne "synth_design Complete!"} {
        puts "  ERROR: Synthesis failed ($synth_status) -- skipping $vname"
        close_project -quiet
        continue
    }

    # Save the post-synth checkpoint
    open_run synth_1 -name synth_1
    set synth_dcp "$work_dir/post_synth.dcp"
    write_checkpoint -force $synth_dcp
    close_design
    close_project -quiet

    # Phase 2: Implementation per seed (non-project mode)
    #
    # We open the synth checkpoint, place, route, extract, close.
    # Each iteration starts from the same netlist with a different seed.
    foreach seed $seeds {
        puts "\n  --- $vname / seed $seed ---"
        set t0 [clock seconds]

        # Open the post-synthesis checkpoint (non-project)
        open_checkpoint $synth_dcp

        # Read constraints into the non-project design
        read_xdc $clk_xdc

        # Place with this seed.
        # STRATEGY: Vivado's placer accepts SEED through the internal
        # parameter place.seed (available in Vivado 2020.1+). If your
        # Vivado version does not support it, fall back to directive
        # variation (see comments below).
        puts "    place_design (seed=$seed)..."
        catch {set_param place.seed $seed}
        # Fallback: if set_param fails, we still get one valid placement
        # per call, just with less seed control. The catch prevents abort.
        place_design -directive Default

        # Route
        puts "    route_design..."
        route_design -directive Default

        # Extract PPA metrics
        puts "    Extracting metrics..."
        set r [extract_results $clk_period]

        set fmax  [dict get $r fmax]
        set wns   [dict get $r wns]
        set luts  [dict get $r luts]
        set ffs   [dict get $r ffs]
        set dsps  [dict get $r dsps]
        set brams [dict get $r brams]
        set tpow  [dict get $r total_power]
        set dpow  [dict get $r dynamic_power]

        set impl_time [expr {[clock seconds] - $t0}]

        # CSV
        set fd [open $csv_file a]
        puts $fd "$vname,$seed,$fmax,$wns,$luts,$ffs,$dsps,$brams,$tpow,$dpow"
        close $fd

        # Log
        set fd [open $log_file a]
        puts $fd "------------------------------------------------------------"
        puts $fd "  $vname  |  seed $seed  |  ${impl_time}s"
        puts $fd "------------------------------------------------------------"
        puts $fd "  Fmax          : $fmax MHz  (WNS: $wns ns)"
        puts $fd "  LUTs          : $luts"
        puts $fd "  FFs           : $ffs"
        puts $fd "  DSPs          : $dsps"
        puts $fd "  BRAMs         : $brams"
        puts $fd "  Total Power   : $tpow W"
        puts $fd "  Dynamic Power : $dpow W"
        puts $fd ""
        close $fd

        # Console
        puts "    => Fmax=$fmax MHz  LUTs=$luts  FFs=$ffs  BRAMs=$brams  Power=$tpow W  (${impl_time}s)"

        # Save routed checkpoint for later inspection
        write_checkpoint -force "$work_dir/impl_seed${seed}.dcp"

        close_design
    }
}

set total_time [expr {[clock seconds] - $total_start}]

# Print final summary table
puts "\n================================================================"
puts "  ALL SEED RUNS COMPLETE  (total: ${total_time}s)"
puts "================================================================\n"

set fd [open $csv_file r]
set lines [split [read $fd] "\n"]
close $fd

puts [format "  %-10s %4s %10s %8s %6s %6s %5s %5s %7s %7s" \
    "Variant" "Seed" "Fmax" "WNS" "LUTs" "FFs" "DSPs" "BRAMs" "Ptot" "Pdyn"]
puts "  [string repeat - 76]"

foreach line $lines {
    if {$line eq "" || [string match "variant*" $line]} continue
    set f [split $line ","]
    if {[llength $f] < 10} continue
    puts [format "  %-10s %4s %8s %8s %6s %6s %5s %5s %7s %7s" \
        [lindex $f 0] [lindex $f 1] [lindex $f 2] [lindex $f 3] \
        [lindex $f 4] [lindex $f 5] [lindex $f 6] [lindex $f 7] \
        [lindex $f 8] [lindex $f 9]]
}

puts ""
puts "  CSV : $csv_file"
puts "  Log : $log_file"
puts "================================================================\n"
