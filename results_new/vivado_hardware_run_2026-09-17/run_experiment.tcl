# Frozen current-source SGF hardware-cost experiment.
# Inputs are generated and validated by run_vivado.ps1.

if {[llength $argv] != 3} {
    error "usage: run_experiment.tcl <repo> <out> <Smoke|All>"
}
set repo [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
set mode [lindex $argv 2]
if {$mode ni {Smoke All}} { error "mode must be Smoke or All" }

set part xc7a35tcpg236-1
set clk_period 5.000
set membership [file join $out source_membership.tsv]
set xdc [file join $repo scripts synth_clk_ooc.xdc]

proc csv_field {value} {
    return "\"[string map [list \" \"\"] $value]\""
}

proc safe_property {property object {fallback "N/A"}} {
    if {[llength $object] == 0} { return $fallback }
    if {[catch {get_property $property $object} value]} { return $fallback }
    if {$value eq ""} { return $fallback }
    return $value
}

proc utilization_value {report label} {
    set escaped [regsub -all {([][(){}.+*?^$\\|])} $label {\\\1}]
    if {[regexp -line "^\\|?\\s*$escaped\\s*\\|\\s*([0-9.]+)" $report -> value]} {
        return $value
    }
    return "N/A"
}

proc append_result {csv values} {
    set fields {}
    foreach value $values { lappend fields [csv_field $value] }
    set fd [open $csv a]
    puts $fd [join $fields ,]
    close $fd
}

set fd [open $membership r]
set lines [split [string trim [read $fd]] "\n"]
close $fd
set sets [dict create]
foreach line [lrange $lines 1 end] {
    set columns [split [string trim $line "\r"] "\t"]
    if {[llength $columns] != 5} { error "bad membership row: $line" }
    lassign $columns stage design top ordinal relative
    set key "$stage/$design"
    set source_path [file join $repo {*}[split $relative /]]
    if {![dict exists $sets $key]} {
        dict set sets $key [dict create top $top files [list $source_path]]
    } else {
        set entry [dict get $sets $key]
        dict lappend entry files $source_path
        dict set sets $key $entry
    }
}

set version_file [file join $out vivado_version.txt]
set fd [open $version_file w]
puts $fd [version]
close $fd
set tool_version [version -short]
set fd [open [file join $out git_commit.txt] r]
set git_commit [string trim [read $fd]]
close $fd

set csv [file join $out hardware_cost_runs.csv]
if {![file exists $csv]} {
    append_result $csv {stage design run_label commit tool_version part clock_period_ns luts ffs dsps bram_tiles wns_ns fmax_estimated_mhz critical_startpoint critical_endpoint critical_path_delay_ns route_complete hold_wns_ns status}
}

set run_defs [list \
    [list default Default Default] \
    [list explore Explore Explore] \
    [list wlblock WLDrivenBlockPlacement NoTimingRelaxation]]

if {$mode eq "Smoke"} {
    set design_keys [list 6/baseline]
    set run_defs [lrange $run_defs 0 0]
} else {
    set design_keys [list 6/baseline 6/sgf 7/baseline 7/sgf 8/baseline 8/sgf]
}

foreach key $design_keys {
    lassign [split $key /] stage design
    set top [dict get $sets $key top]
    set rtl_files [dict get $sets $key files]
    foreach source $rtl_files {
        if {![file exists $source]} { error "missing source: $source" }
    }

    set design_dir [file join $out "stage${stage}_${design}"]
    file mkdir $design_dir
    set dcp [file join $design_dir synthesized.dcp]
    set candidate_dcp [file join $design_dir synthesized_candidate.dcp]
    if {![file exists $dcp]} {
        if {[file exists $candidate_dcp]} {
            open_checkpoint $candidate_dcp
        } else {
            read_verilog -sv $rtl_files
            read_xdc $xdc
            synth_design -top $top -part $part -mode out_of_context
            write_checkpoint -force $candidate_dcp
        }
        set design_object [current_design]
        set actual_top [safe_property TOP $design_object]
        if {$actual_top ne $top} { error "elaborated top mismatch for $key: actual=$actual_top expected=$top" }
        if {[safe_property PART [current_design]] ne $part} { error "part mismatch for $key" }
        if {[llength [get_clocks -quiet clk]] != 1} { error "expected exactly one clk constraint for $key" }
        set actual_period [safe_property PERIOD [get_clocks clk]]
        if {[expr {abs($actual_period - $clk_period)}] > 0.0001} { error "clock period mismatch for $key" }
        if {[llength [get_cells -quiet -hier -filter {NAME =~ *u_bp}]] == 0} { error "u_bp missing for $key" }
        report_utilization -file [file join $design_dir synthesis_utilization.rpt]
        report_utilization -hierarchical -file [file join $design_dir synthesis_utilization_hierarchical.rpt]
        report_clock_utilization -file [file join $design_dir synthesis_clock_utilization.rpt]
        report_methodology -file [file join $design_dir synthesis_methodology.rpt]
        write_checkpoint -force $dcp
        close_design
    }

    foreach run_def $run_defs {
        lassign $run_def label pdir rdir
        set run_dir [file join $design_dir $label]
        set routed_dcp [file join $run_dir routed.dcp]
        set routed_candidate [file join $run_dir routed_candidate.dcp]
        if {[file exists $routed_dcp]} {
            puts "Skipping completed run $key/$label"
            continue
        }
        file mkdir $run_dir
        if {[file exists $routed_candidate]} {
            open_checkpoint $routed_candidate
        } else {
            open_checkpoint $dcp
            opt_design
            place_design -directive $pdir
            route_design -directive $rdir
            write_checkpoint -force $routed_candidate
        }

        set route_report [report_route_status -return_string]
        set routable -1; set fully_routed -2; set route_errors -1
        regexp {# of routable nets\.+\s*:\s*([0-9]+)} $route_report -> routable
        regexp {# of fully routed nets\.+\s*:\s*([0-9]+)} $route_report -> fully_routed
        regexp {# of nets with routing errors\.+\s*:\s*([0-9]+)} $route_report -> route_errors
        set route_complete [expr {$routable >= 0 && $routable == $fully_routed && $route_errors == 0 ? "true" : "false"}]
        report_route_status -file [file join $run_dir route_status.rpt]
        report_drc -file [file join $run_dir drc.rpt]
        check_timing -verbose -file [file join $run_dir check_timing.rpt]
        report_clocks -file [file join $run_dir clocks.rpt]
        report_utilization -file [file join $run_dir utilization.rpt]
        report_utilization -hierarchical -file [file join $run_dir utilization_hierarchical.rpt]
        report_timing_summary -report_unconstrained -file [file join $run_dir timing_summary.rpt]
        report_timing -delay_type max -max_paths 10 -file [file join $run_dir critical_setup_paths.rpt]
        report_timing -delay_type min -max_paths 10 -file [file join $run_dir critical_hold_paths.rpt]

        if {$route_complete ne "true"} { error "routing incomplete for $key/$label: routable=$routable fully_routed=$fully_routed errors=$route_errors" }
        set setup_path [get_timing_paths -quiet -delay_type max -max_paths 1 -nworst 1]
        set hold_path [get_timing_paths -quiet -delay_type min -max_paths 1 -nworst 1]
        if {[llength $setup_path] == 0} { error "no constrained setup path for $key/$label" }
        set start_clk [safe_property STARTPOINT_CLOCK $setup_path]
        set end_clk [safe_property ENDPOINT_CLOCK $setup_path]
        if {$start_clk ne "clk" || $end_clk ne "clk"} {
            error "worst setup path is not internal clk-to-clk for $key/$label ($start_clk -> $end_clk)"
        }
        set wns [safe_property SLACK $setup_path]
        set hold_wns [safe_property SLACK $hold_path]
        set denominator [expr {$clk_period - $wns}]
        if {$denominator <= 0} { error "invalid Fmax denominator for $key/$label" }
        set fmax [format %.6f [expr {1000.0 / $denominator}]]
        set startpoint [safe_property STARTPOINT_PIN $setup_path]
        set endpoint [safe_property ENDPOINT_PIN $setup_path]
        set path_delay [safe_property DATAPATH_DELAY $setup_path]

        set util [report_utilization -return_string]
        set luts [utilization_value $util "Slice LUTs"]
        set ffs [utilization_value $util "Slice Registers"]
        set dsps [utilization_value $util "DSPs"]
        set bram [utilization_value $util "Block RAM Tile"]
        foreach {metric value} [list luts $luts ffs $ffs dsps $dsps bram $bram] {
            if {$value eq "N/A"} { error "could not extract $metric for $key/$label" }
        }

        write_checkpoint -force $routed_dcp
        append_result $csv [list $stage $design $label $git_commit $tool_version $part $clk_period $luts $ffs $dsps $bram $wns $fmax $startpoint $endpoint $path_delay $route_complete $hold_wns success]
        close_design
    }
}

puts "Experiment mode $mode completed successfully."
