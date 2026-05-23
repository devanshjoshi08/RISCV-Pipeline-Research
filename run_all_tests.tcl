# run_all_tests.tcl — Run all testbenches for 5-stage, 6-stage, and 7-stage.
# Usage in Vivado TCL console:
#   cd C:/Users/Joshi/RISCV-Vivado
#   source run_all_tests.tcl
#
# Each test creates a project, runs simulation, closes. Results in console output.

set project_dir [file normalize [file dirname [info script]]]
set rtl_dir     "$project_dir/rtl"
set asm_dir     "$project_dir/programs/asm"

# Helper: create project, add files, simulate, close
proc run_test {proj_name work_dir part rtl_files tb_files sim_top hex_files} {
    global project_dir asm_dir

    puts "\n================================================================"
    puts "  Running: $proj_name (top: $sim_top)"
    puts "================================================================\n"

    # Create project
    create_project $proj_name $work_dir -part $part -force

    # Add RTL
    add_files -norecurse $rtl_files
    set_property file_type SystemVerilog [get_files *.sv]

    # Add TB
    add_files -fileset sim_1 -norecurse $tb_files
    set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]

    # Set sim top
    set_property top $sim_top [get_filesets sim_1]

    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    # Copy hex files to sim directory
    set sim_dir "$work_dir/$proj_name.sim/sim_1/behav/xsim"
    file mkdir $sim_dir
    foreach hex $hex_files {
        set src "$asm_dir/$hex"
        set dst "$sim_dir/$hex"
        if {[file exists $src]} {
            file copy -force $src $dst
        }
    }
    # Also copy sum_1_to_10.hex as program.hex (needed by imem's $readmemh)
    file copy -force "$asm_dir/sum_1_to_10.hex" "$sim_dir/program.hex"

    # Run simulation
    launch_simulation
    run -all

    # Close
    close_sim -quiet
    close_project -quiet
}

# Shared file lists
set shared_rtl [list \
    "$rtl_dir/pkg_riscv.sv" "$rtl_dir/alu.sv" "$rtl_dir/mdu.sv" \
    "$rtl_dir/control.sv" "$rtl_dir/branch_unit.sv" "$rtl_dir/branch_predictor.sv" \
    "$rtl_dir/csr_unit.sv" "$rtl_dir/regfile.sv" "$rtl_dir/imm_gen.sv" \
    "$rtl_dir/pc.sv" "$rtl_dir/icache.sv" "$rtl_dir/imem.sv" "$rtl_dir/dmem.sv" \
    "$rtl_dir/pipe_if_id.sv" "$rtl_dir/pipe_id_ex.sv" "$rtl_dir/pipe_ex_mem.sv" \
    "$rtl_dir/pipe_mem_wb.sv" \
]

set hex_files [list "sum_1_to_10.hex" "test_comprehensive.hex" "test_mext_csr.hex" \
    "bench_diagnostic.hex" "bench_branch_heavy.hex" "bench_compute_heavy.hex" \
    "bench_crc32.hex" "bench_sort.hex" "dhrystone.hex" "coremark_minimal.hex"]
set part "xc7a35tcpg236-1"

# 5-STAGE TESTS
set rtl5 [concat $shared_rtl [glob "$project_dir/rtl_5stage/*.sv"]]

run_test "test_5s_basic" "$project_dir/vivado_test/5s_basic" $part \
    $rtl5 [list "$project_dir/tb_5stage/rv32i_5stage_tb.sv"] \
    "rv32i_5stage_tb" $hex_files

run_test "test_5s_comp" "$project_dir/vivado_test/5s_comp" $part \
    $rtl5 [list "$project_dir/tb_5stage/rv32i_5stage_comprehensive_tb.sv"] \
    "rv32i_5stage_comprehensive_tb" $hex_files

run_test "test_5s_mext" "$project_dir/vivado_test/5s_mext" $part \
    $rtl5 [list "$project_dir/tb_5stage/rv32i_5stage_mext_csr_tb.sv"] \
    "rv32i_5stage_mext_csr_tb" $hex_files

# 6-STAGE TESTS (baseline)
set rtl6 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv" \
    "$rtl_dir/forwarding_unit.sv" "$rtl_dir/hazard_unit.sv" \
    "$rtl_dir/rv32i_pipeline_top.sv"]]

run_test "test_6s_basic" "$project_dir/vivado_test/6s_basic" $part \
    $rtl6 [list "$project_dir/tb/rv32i_pipeline_tb.sv"] \
    "rv32i_pipeline_tb" $hex_files

run_test "test_6s_comp" "$project_dir/vivado_test/6s_comp" $part \
    $rtl6 [list "$project_dir/tb/rv32i_comprehensive_tb.sv"] \
    "rv32i_comprehensive_tb" $hex_files

run_test "test_6s_mext" "$project_dir/vivado_test/6s_mext" $part \
    $rtl6 [list "$project_dir/tb/rv32i_mext_csr_tb.sv"] \
    "rv32i_mext_csr_tb" $hex_files

# 7-STAGE TESTS
set rtl7 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [glob "$project_dir/rtl_7stage/*.sv"]]

run_test "test_7s_basic" "$project_dir/vivado_test/7s_basic" $part \
    $rtl7 [list "$project_dir/tb_7stage/rv32i_7stage_tb.sv"] \
    "rv32i_7stage_tb" $hex_files

run_test "test_7s_comp" "$project_dir/vivado_test/7s_comp" $part \
    $rtl7 [list "$project_dir/tb_7stage/rv32i_7stage_comprehensive_tb.sv"] \
    "rv32i_7stage_comprehensive_tb" $hex_files

run_test "test_7s_mext" "$project_dir/vivado_test/7s_mext" $part \
    $rtl7 [list "$project_dir/tb_7stage/rv32i_7stage_mext_csr_tb.sv"] \
    "rv32i_7stage_mext_csr_tb" $hex_files

# 4-STAGE TESTS
set rtl4 [concat $shared_rtl [glob "$project_dir/rtl_4stage/*.sv"]]

run_test "test_4s_basic" "$project_dir/vivado_test/4s_basic" $part \
    $rtl4 [list "$project_dir/tb_4stage/rv32i_4stage_tb.sv"] \
    "rv32i_4stage_tb" $hex_files

run_test "test_4s_comp" "$project_dir/vivado_test/4s_comp" $part \
    $rtl4 [list "$project_dir/tb_4stage/rv32i_4stage_comprehensive_tb.sv"] \
    "rv32i_4stage_comprehensive_tb" $hex_files

run_test "test_4s_mext" "$project_dir/vivado_test/4s_mext" $part \
    $rtl4 [list "$project_dir/tb_4stage/rv32i_4stage_mext_csr_tb.sv"] \
    "rv32i_4stage_mext_csr_tb" $hex_files

# 8-STAGE TESTS
set rtl8 [concat $shared_rtl [list "$rtl_dir/pipe_ex1_ex2.sv"] \
    [glob "$project_dir/rtl_8stage/*.sv"]]

run_test "test_8s_basic" "$project_dir/vivado_test/8s_basic" $part \
    $rtl8 [list "$project_dir/tb_8stage/rv32i_8stage_tb.sv"] \
    "rv32i_8stage_tb" $hex_files

run_test "test_8s_comp" "$project_dir/vivado_test/8s_comp" $part \
    $rtl8 [list "$project_dir/tb_8stage/rv32i_8stage_comprehensive_tb.sv"] \
    "rv32i_8stage_comprehensive_tb" $hex_files

run_test "test_8s_mext" "$project_dir/vivado_test/8s_mext" $part \
    $rtl8 [list "$project_dir/tb_8stage/rv32i_8stage_mext_csr_tb.sv"] \
    "rv32i_8stage_mext_csr_tb" $hex_files

puts "\n================================================================"
puts "  ALL TESTS COMPLETE"
puts "================================================================\n"
