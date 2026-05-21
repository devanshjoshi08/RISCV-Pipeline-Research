`timescale 1ns / 1ps

// Generic benchmark testbench for any pipeline variant.
// Loads a benchmark hex file, runs until halt (jal x0,0), then reads
// performance counters from dmem[0..4]:
//   dmem[0] = cycles
//   dmem[1] = instructions retired
//   dmem[2] = total branches
//   dmem[3] = mispredictions
//   dmem[4] = checksum
//
// Instantiate with the desired top module by editing the DUT line.
// The hex file is loaded via $readmemh in the initial block.

module rv32i_benchmark_tb;

  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  // Change this line for different variants:
  // rv32i_pipeline_5stage_top dut (.*);
  rv32i_pipeline_top dut (.*);
  // rv32i_pipeline_7stage_top dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  // Halt detection: jal x0,0 = 0x0000006F
  int halt_count;
  always_ff @(posedge clk) begin
    if (!rst_n) halt_count <= 0;
    else if (debug_instr == 32'h0000006F) halt_count <= halt_count + 1;
    else halt_count <= 0;
  end

  initial begin
    $display("=== Pipeline Benchmark Testbench ===");
    rst_n = 0;

    // Load benchmark program
    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = 32'h00000013;
    // Change this line for different benchmarks:
    $readmemh("bench_branch_heavy.hex", dut.u_imem.mem);
    // $readmemh("bench_compute_heavy.hex", dut.u_imem.mem);

    repeat (5) @(posedge clk);
    rst_n = 1;

    // Wait for halt
    fork
      wait (halt_count > 10);
      repeat (200000) @(posedge clk);
    join_any
    repeat (10) @(posedge clk);

    // Read performance counters from dmem
    $display("");
    $display("  Benchmark results (from dmem):");
    $display("    Cycles:          %0d", dut.u_dmem.mem[0]);
    $display("    Instructions:    %0d", dut.u_dmem.mem[1]);
    $display("    Branches:        %0d", dut.u_dmem.mem[2]);
    $display("    Mispredictions:  %0d", dut.u_dmem.mem[3]);
    $display("    Checksum:        0x%08h", dut.u_dmem.mem[4]);
    $display("");

    if (dut.u_dmem.mem[1] != 0) begin
      // CPI = cycles / instructions (integer part)
      $display("    CPI (approx):   %0d.%02d",
        dut.u_dmem.mem[0] / dut.u_dmem.mem[1],
        ((dut.u_dmem.mem[0] % dut.u_dmem.mem[1]) * 100) / dut.u_dmem.mem[1]);
    end

    if (dut.u_dmem.mem[2] != 0) begin
      $display("    Mispredict rate: %0d.%02d%%",
        (dut.u_dmem.mem[3] * 100) / dut.u_dmem.mem[2],
        ((dut.u_dmem.mem[3] * 10000) / dut.u_dmem.mem[2]) % 100);
    end

    // Also read CSR counters directly
    $display("");
    $display("  CSR counters (total including setup):");
    $display("    mcycle   = %0d", dut.u_csr.mcycle);
    $display("    minstret = %0d", dut.u_csr.minstret);
    $display("    branches = %0d", dut.u_csr.hpmcnt4);
    $display("    mispred  = %0d", dut.u_csr.hpmcnt3);

    $display("");
    $display("=== Benchmark Complete ===");
    $finish;
  end

  initial begin #10000000; $display("TIMEOUT"); $finish; end

endmodule
