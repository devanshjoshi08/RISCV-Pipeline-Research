# create_project_5stage.tcl
# Run this in the Vivado TCL console:
#   cd C:/Users/Joshi/RISCV-Vivado
#   source create_project_5stage.tcl

set project_name "RISCV-5stage"
set project_dir  [file normalize [file dirname [info script]]]
set rtl_dir      "$project_dir/rtl"
set rtl5_dir     "$project_dir/rtl_5stage"
set tb5_dir      "$project_dir/tb_5stage"
set prog_dir     "$project_dir/programs/asm"

# Create project targeting Basys 3 (Artix-7 XC7A35T)
create_project $project_name "$project_dir/vivado_5stage" -part xc7a35tcpg236-1 -force

# Add shared RTL from rtl/
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
  "$rtl_dir/pipe_mem_wb.sv" \
]
add_files -norecurse $shared_files

# Add 5-stage specific RTL
add_files -norecurse [glob $rtl5_dir/*.sv]

# Set all as SystemVerilog
set_property file_type SystemVerilog [get_files *.sv]

# Add testbench
add_files -fileset sim_1 -norecurse [glob $tb5_dir/*.sv]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]

# Set top modules
set_property top rv32i_pipeline_5stage_top [current_fileset]
set_property top rv32i_5stage_tb [get_filesets sim_1]

# Copy hex program so $readmemh can find it
set sim_dir "$project_dir/vivado_5stage/$project_name.sim/sim_1/behav/xsim"
file mkdir $sim_dir
file copy -force "$prog_dir/sum_1_to_10.hex" "$sim_dir/program.hex"

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "Project created: vivado_5stage/$project_name.xpr"
puts "Sim top:     rv32i_5stage_tb"
puts "Synth top:   rv32i_pipeline_5stage_top"
puts "Target:      xc7a35tcpg236-1 (Basys 3)"
puts ""
puts "To simulate:  launch_simulation"
puts ""
