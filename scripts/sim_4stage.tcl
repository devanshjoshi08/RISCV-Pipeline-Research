# sim_4stage.tcl — Simulate 4-stage pipeline in Vivado
# Usage: Open Vivado TCL console, cd to project root, then:
#   source sim_4stage.tcl

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/_synth_rtl"
set rtl4_dir    "$project_dir/rtl_4stage"
set tb4_dir     "$project_dir/tb_4stage"
set prog_dir    "$project_dir/programs/asm"

# Create project in local (non-OneDrive) path to avoid permission issues
set work_dir ".vivado_work/4stage"
file mkdir $work_dir
create_project sim_4stage $work_dir -part xc7a35tcpg236-1 -force

# Add shared RTL
set shared_files [list \
  "$rtl_dir/pkg_riscv.sv" \
  "$rtl_dir/alu.sv" \
  "$rtl_dir/mdu.sv" \
  "$rtl_dir/control.sv" \
  "$rtl_dir/branch_unit.sv" \
  "$rtl_dir/branch_predictor.sv" \
  "$rtl_dir/csr_unit.sv" \
  "$rtl_dir/regfile.sv" \
  "$rtl_dir/imm_gen.sv" \
  "$rtl_dir/pc.sv" \
  "$rtl_dir/icache.sv" \
  "$rtl_dir/imem.sv" \
  "$rtl_dir/dmem.sv" \
  "$rtl_dir/pipe_if_id.sv" \
  "$rtl_dir/pipe_id_ex.sv" \
  "$rtl_dir/pipe_ex_mem.sv" \
]
add_files -norecurse $shared_files

# Add 4-stage specific RTL
add_files -norecurse [glob $rtl4_dir/*.sv]

# Set all as SystemVerilog
set_property file_type SystemVerilog [get_files *.sv]

# Add testbenches
add_files -fileset sim_1 -norecurse [glob $tb4_dir/*.sv]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]

# Set top modules
set_property top rv32i_pipeline_4stage_top [current_fileset]
set_property top rv32i_4stage_tb [get_filesets sim_1]

# Copy hex files
set sim_dir "$work_dir/sim_4stage.sim/sim_1/behav/xsim"
file mkdir $sim_dir
file copy -force "$prog_dir/sum_1_to_10.hex" "$sim_dir/program.hex"

# Copy ALL hex files (benchmarks + tests)
foreach hex [glob -nocomplain "$prog_dir/*.hex"] {
    file copy -force $hex "$sim_dir/[file tail $hex]"
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "=== 4-Stage Pipeline Project Created ==="
puts "Sim top:  rv32i_4stage_tb"
puts "Target:   xc7a35tcpg236-1 (Basys 3)"
puts ""
puts "To simulate: click 'Run Simulation' or run:"
puts "  launch_simulation"
puts ""
