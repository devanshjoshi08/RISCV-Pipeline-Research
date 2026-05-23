# run_saif_workload.tcl - WORKLOAD-SPECIFIC SAIF power analysis (#4).
#
# Replaces the uniform 12.5%-toggle estimate in the paper's power section with
# switching activity captured from an actual CoreMark run on each pipeline
# variant.
#
# Flow per variant (4s,5s,6s,7s,8s):
#   1. Out-of-context synthesis (5 ns clock), memory sized for CoreMark (16 KB).
#   2. Behavioral simulation of CoreMark; after a warm-up, capture a SAIF over a
#      steady-state window (no dependence on the TB's $finish).
#   3. open_run synth_1 -> read_saif (workload activity) -> report_power.
#
# METHODOLOGY NOTES (state these in the paper):
#   * This is vector-based power with an RTL-derived SAIF mapped onto the
#     synthesized netlist. Registers map by name; some optimized combinational
#     nets fall back to default activity. report_power prints the SAIF coverage
#     ("% of nets matched") -- record it; it is the honest accuracy caveat and
#     is still far more workload-faithful than a flat 12.5% toggle everywhere.
#   * Synthesis and simulation use the SAME 4096-word imem (CoreMark config) so
#     the large LUTRAM memory nets map between the two.
#
# KNOWN SNAGS (may need one debug pass):
#   * read_saif -strip_path must match the TB->dut hierarchy (power_tb/dut).
#   * If launch_simulation auto-runs, the `restart` resets it to t=0 first.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set github_dir  "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set asm_dir     "$github_dir/programs/asm"
set work_root   "$project_dir/vivado_saif_wl"
set part        "xc7a35tcpg236-1"
set log_file    "$project_dir/saif_workload_results.log"
set clk_xdc     "$project_dir/synth_clk_only.xdc"

set cm_hex  "$asm_dir/coremark_official.hex"
set cm_data "$github_dir/programs/coremark/data.hex"

set ::env(TEMP)   "D:/RISCV-Vivado/tmp"
set ::env(TMP)    "D:/RISCV-Vivado/tmp"
set ::env(TMPDIR) "D:/RISCV-Vivado/tmp"
file mkdir "D:/RISCV-Vivado/tmp"
file mkdir $work_root

# --- Build a 4096-word imem copy (CoreMark needs 16 KB; default imem is 1 KB) ---
proc make_imem4k {dst} {
    global rtl_dir
    set fd [open "$rtl_dir/imem.sv" r]; set c [read $fd]; close $fd
    regsub {parameter DEPTH = 1024} $c {parameter DEPTH = 4096} c
    set fd [open $dst w]; puts -nonewline $fd $c; close $fd
}
set imem4k "$work_root/imem_4k.sv"
make_imem4k $imem4k

# Shared RTL (imem replaced by the 4096-word copy; dmem default 2048 already fits)
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" $imem4k "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

proc write_power_tb {filepath top_module} {
    set fd [open $filepath w]
    puts $fd "`timescale 1ns / 1ps"
    puts $fd "module power_tb;"
    puts $fd "  logic clk, rst_n;"
    puts $fd "  logic \[31:0\] debug_pc, debug_instr, debug_alu_result;"
    puts $fd "  $top_module dut (.*);"
    puts $fd "  defparam dut.u_imem.DEPTH = 4096;"
    puts $fd "  defparam dut.u_dmem.DEPTH = 2048;"
    puts $fd "  initial begin"
    puts $fd "    for (int i = 0; i < 2048; i++) dut.u_dmem.mem\[i\] = 32'h0;"
    puts $fd "    \$readmemh(\"data.hex\", dut.u_dmem.mem);"
    puts $fd "  end"
    puts $fd "  initial clk = 0;"
    puts $fd "  always #5 clk = ~clk;"
    puts $fd "  initial begin rst_n = 0; repeat (5) @(posedge clk); rst_n = 1; end"
    puts $fd "  // No early \$finish: the xsim Tcl controls the SAIF capture window."
    puts $fd "  initial begin #100000000; \$finish; end  // 100 ms safety stop"
    puts $fd "endmodule"
    close $fd
}

proc run_saif_wl {name top_module rtl_files} {
    global part clk_xdc log_file work_root cm_hex cm_data

    puts "\n=================================================="
    puts "  SAIF workload power: $name ($top_module)"
    puts "==================================================\n"
    set wdir "$work_root/$name"

    create_project $name $wdir -part $part -force
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]
    add_files -fileset constrs_1 -norecurse $clk_xdc
    set_property top $top_module [current_fileset]
    set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} \
        -value {-mode out_of_context} -objects [get_runs synth_1]

    # Testbench (for the SAIF-generating behavioral sim)
    set tb_path "$wdir/${name}_tb.sv"
    write_power_tb $tb_path $top_module
    add_files -fileset sim_1 -norecurse $tb_path
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
    set_property top power_tb [get_filesets sim_1]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    # 1) Synthesize (OOC)
    puts "  synthesizing..."
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1

    # 2) Behavioral sim -> capture workload SAIF over a steady-state window
    set sim_dir "$wdir/$name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    file copy -force $cm_hex  "$sim_dir/program.hex"
    file copy -force $cm_data "$sim_dir/data.hex"
    set saif_path "$sim_dir/coremark.saif"

    launch_simulation -mode behavioral
    restart
    run 200us                                      ;# reset + warm-up (~20k cycles)
    open_saif $saif_path
    log_saif [get_objects -r /power_tb/dut/*]
    run 2000us                                     ;# capture window (~200k cycles)
    close_saif
    close_sim -quiet

    # 3) Power with workload activity
    open_run synth_1
    set covered "n/a"
    if {[catch {read_saif -strip_path {power_tb/dut} $saif_path} emsg]} {
        puts "  read_saif WARNING: $emsg"
    }
    set power_rpt [report_power -return_string]
    close_design

    set fd [open $log_file a]
    puts $fd "------------------------------------------------------------"
    puts $fd "  $name ($top_module) -- workload-SAIF: CoreMark"
    puts $fd "------------------------------------------------------------"
    foreach line [split $power_rpt "\n"] {
        if {[regexp {Total On-Chip Power} $line] ||
            [regexp {Dynamic \(} $line] ||
            [regexp {Device Static} $line] ||
            [regexp {Clocks} $line] || [regexp {Signals} $line] ||
            [regexp {Slice Logic} $line] || [regexp {Logic} $line] ||
            [regexp {Signal} $line] || [regexp {DSP} $line] ||
            [regexp {confidence} $line] || [regexp {Vectorless} $line] ||
            [regexp {SAIF} $line]} {
            puts $fd "  $line"
        }
    }
    puts $fd ""
    close $fd

    close_project -quiet
    catch {file delete -force "$wdir/$name.sim"}
    catch {file delete -force "$wdir/$name.runs"}
}

set fd [open $log_file w]
puts $fd "=== Workload-Specific SAIF Power (CoreMark) ==="
puts $fd "=== [clock format [clock seconds]] ==="
puts $fd ""
close $fd

set variants [list \
    [list "wl_4s" "rv32i_pipeline_4stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_4stage/rv32i_pipeline_4stage_top.sv" \
            "$github_dir/rtl_4stage/forwarding_unit.sv" \
            "$github_dir/rtl_4stage/hazard_unit.sv"]]] \
    [list "wl_5s" "rv32i_pipeline_5stage_top" \
        [concat $shared_rtl [list \
            "$github_dir/rtl_5stage/rv32i_pipeline_5stage_top.sv" \
            "$github_dir/rtl_5stage/forwarding_unit.sv" \
            "$github_dir/rtl_5stage/hazard_unit.sv"]]] \
    [list "wl_6s" "rv32i_pipeline_top" \
        [concat $shared_rtl [list \
            "$rtl_dir/pipe_ex1_ex2.sv" "$rtl_dir/forwarding_unit.sv" \
            "$rtl_dir/hazard_unit.sv" "$rtl_dir/rv32i_pipeline_top.sv"]]] \
    [list "wl_7s" "rv32i_pipeline_7stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_7stage/rv32i_pipeline_7stage_top.sv" \
                  "$github_dir/rtl_7stage/forwarding_unit.sv" \
                  "$github_dir/rtl_7stage/hazard_unit.sv" \
                  "$github_dir/rtl_7stage/pipe_if1_if2.sv"]]] \
    [list "wl_8s" "rv32i_pipeline_8stage_top" \
        [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
            [list "$github_dir/rtl_8stage/rv32i_pipeline_8stage_top.sv" \
                  "$github_dir/rtl_8stage/forwarding_unit.sv" \
                  "$github_dir/rtl_8stage/hazard_unit.sv" \
                  "$github_dir/rtl_8stage/pipe_if1_if2.sv" \
                  "$github_dir/rtl_8stage/pipe_mem1_mem2.sv"]]] \
]

foreach v $variants {
    run_saif_wl [lindex $v 0] [lindex $v 1] [lindex $v 2]
}

puts "\n=================================================="
puts "  WORKLOAD-SAIF POWER COMPLETE -> $log_file"
puts "==================================================\n"
