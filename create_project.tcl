# create_project.tcl
# Run this in the Vivado TCL console:
#   cd <path-to-RISCV-RV32I-Processor>
#   source create_project.tcl

set project_name "RISCV-RV32I-Processor"
set project_dir  [file normalize [file dirname [info script]]]
set rtl_dir      "$project_dir/rtl"
set tb_dir       "$project_dir/tb"
set constr_dir   "$project_dir/constraints"
set prog_dir     "$project_dir/programs/asm"

# Create project targeting Basys 3 (Artix-7 XC7A35T)
create_project $project_name "$project_dir/vivado" -part xc7a35tcpg236-1 -force

# Add RTL design sources
add_files -norecurse [glob $rtl_dir/*.sv]
set_property file_type SystemVerilog [get_files [glob $rtl_dir/*.sv]]

# Add testbenches as simulation sources
add_files -fileset sim_1 -norecurse [glob $tb_dir/*.sv]
set_property file_type SystemVerilog [get_files [glob $tb_dir/*.sv]]

# Add constraints
add_files -fileset constrs_1 -norecurse "$constr_dir/basys3.xdc"

# Set top modules
set_property top rv32i_pipeline_top [current_fileset]
set_property top rv32i_pipeline_tb [get_filesets sim_1]

# FPGA synthesis top is fpga_top
set_property top fpga_top [current_fileset -quiet]

# Copy hex program to simulation directory so $readmemh can find it
set sim_dir "$project_dir/vivado/$project_name.sim/sim_1/behav/xsim"
file mkdir $sim_dir
file copy -force "$prog_dir/sum_1_to_10.hex" "$sim_dir/program.hex"

# Update compile order
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "Project created: vivado/$project_name.xpr"
puts "Sim top:     rv32i_pipeline_tb"
puts "Synth top:   fpga_top"
puts "Target:      xc7a35tcpg236-1 (Basys 3)"
puts ""
