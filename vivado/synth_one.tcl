# synth_one.tcl — Synthesize and place/route ONE variant.
# Called by run_seeds.bat with: vivado -mode batch -source synth_one.tcl -tclargs <idx>
# idx: 0=4stage, 1=5stage, 2=6stage, 3=7stage, 4=8stage

set idx [lindex $argv 0]

set rtl_dir    "D:/RISCV-Vivado/rtl"
set gh         "C:/Users/Joshi/OneDrive/Documents/GitHub/RISCV-RV32IM-Processor"
set work       "D:/RISCV-Vivado/vivado_seeds"
set log        "D:/RISCV-Vivado/seed_results.log"
set xdc        "D:/RISCV-Vivado/synth_clk_ooc.xdc"
set part       "xc7a35tcpg236-1"
set clk_period 5.000

file mkdir $work

# Shared RTL
set S [list \
  $rtl_dir/pkg_riscv.sv $rtl_dir/alu.sv $rtl_dir/mdu.sv \
  $rtl_dir/control.sv $rtl_dir/branch_unit.sv $rtl_dir/branch_predictor.sv \
  $rtl_dir/csr_unit.sv $rtl_dir/regfile.sv $rtl_dir/imm_gen.sv \
  $rtl_dir/pc.sv $rtl_dir/icache.sv $rtl_dir/imem.sv $rtl_dir/dmem.sv \
  $rtl_dir/pipe_if_id.sv $rtl_dir/pipe_id_ex.sv $rtl_dir/pipe_ex_mem.sv \
  $rtl_dir/pipe_mem_wb.sv]

# Variant definitions: name, top, extra files
switch $idx {
  0 {
    set name "4stage"
    set top  "rv32i_pipeline_4stage_top"
    set extra [list $gh/rtl_4stage/rv32i_pipeline_4stage_top.sv \
                    $gh/rtl_4stage/forwarding_unit.sv \
                    $gh/rtl_4stage/hazard_unit.sv]
  }
  1 {
    set name "5stage"
    set top  "rv32i_pipeline_5stage_top"
    set extra [list $gh/rtl_5stage/rv32i_pipeline_5stage_top.sv \
                    $gh/rtl_5stage/forwarding_unit.sv \
                    $gh/rtl_5stage/hazard_unit.sv]
  }
  2 {
    set name "6stage"
    set top  "rv32i_pipeline_top"
    set extra [list $rtl_dir/pipe_ex1_ex2.sv \
                    $rtl_dir/forwarding_unit.sv \
                    $rtl_dir/hazard_unit.sv \
                    $rtl_dir/rv32i_pipeline_top.sv]
  }
  3 {
    set name "7stage"
    set top  "rv32i_pipeline_7stage_top"
    set extra [list $rtl_dir/pipe_ex1_ex2.sv \
                    $gh/rtl_7stage/rv32i_pipeline_7stage_top.sv \
                    $gh/rtl_7stage/forwarding_unit.sv \
                    $gh/rtl_7stage/hazard_unit.sv \
                    $gh/rtl_7stage/pipe_if1_if2.sv]
  }
  4 {
    set name "8stage"
    set top  "rv32i_pipeline_8stage_top"
    set extra [list $rtl_dir/pipe_ex1_ex2.sv \
                    $gh/rtl_8stage/rv32i_pipeline_8stage_top.sv \
                    $gh/rtl_8stage/forwarding_unit.sv \
                    $gh/rtl_8stage/hazard_unit.sv \
                    $gh/rtl_8stage/pipe_if1_if2.sv \
                    $gh/rtl_8stage/pipe_mem1_mem2.sv]
  }
}

set dcp "$work/${name}_synth.dcp"

puts "\n======== $name ========"

# --- SYNTH ---
if {![file exists $dcp]} {
  puts "  Synthesizing $name ..."
  read_verilog -sv [concat $S $extra]
  read_xdc $xdc
  synth_design -top $top -part $part -mode out_of_context
  write_checkpoint -force $dcp
  close_design
  puts "  Done: $dcp"
} else {
  puts "  Cached: $dcp"
}

# --- PLACE + ROUTE x3 ---
foreach {pdir rdir label} {
  Default  Default  dir_default
  Explore  Explore  dir_explore
  WLDrivenBlockPlacement  NoTimingRelaxation  dir_wlblock
} {
  puts "  P&R $label ..."
  open_checkpoint $dcp

  place_design -directive $pdir
  route_design -directive $rdir

  # WNS
  set wns "N/A"; set fmax "N/A"
  foreach line [split [report_timing_summary -return_string] "\n"] {
    if {$wns eq "N/A" && [regexp {^\s+(-?\d+\.\d+)\s+} $line m val]} {
      set wns $val
      set p [expr {$clk_period - $wns}]
      if {$p > 0} { set fmax [format "%.1f" [expr {1000.0/$p}]] }
    }
  }

  # LUTs/FFs
  set luts "N/A"; set ffs "N/A"
  foreach line [split [report_utilization -return_string] "\n"] {
    if {[regexp {Slice LUTs\s*\|\s*(\d+)} $line m val]} { set luts $val }
    if {[regexp {Slice Registers\s*\|\s*(\d+)} $line m val]} { set ffs $val }
  }

  puts "    => Fmax=$fmax WNS=$wns LUTs=$luts FFs=$ffs"

  set fd [open $log a]
  puts $fd "$name,$label,$fmax,$wns,$luts,$ffs"
  close $fd

  close_design
}

puts "======== $name complete ========"
