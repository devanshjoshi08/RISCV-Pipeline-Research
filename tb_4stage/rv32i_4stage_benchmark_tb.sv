`timescale 1ns / 1ps

module rv32i_4stage_benchmark_tb;

  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  rv32i_pipeline_4stage_top dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  int halt_count;
  always_ff @(posedge clk) begin
    if (!rst_n) halt_count <= 0;
    else if (debug_instr == 32'h0000006F) halt_count <= halt_count + 1;
    else halt_count <= 0;
  end

  string bench_names[$] = '{
    "bench_diagnostic",
    "bench_branch_heavy",
    "bench_compute_heavy",
    "bench_crc32",
    "bench_sort",
    "dhrystone",
    "coremark_minimal"
  };

  initial begin
    $display("");
    $display("==========================================================");
    $display("  4-Stage Pipeline Benchmark Suite");
    $display("==========================================================");
    $display("");

    foreach (bench_names[i]) begin
      string hex_file;
      hex_file = {bench_names[i], ".hex"};

      rst_n = 0;
      halt_count = 0;

      for (int j = 0; j < 1024; j++) dut.u_imem.mem[j] = 32'h00000013;
      $readmemh(hex_file, dut.u_imem.mem);
      for (int j = 0; j < 8; j++) dut.u_dmem.mem[j] = 32'b0;

      repeat (5) @(posedge clk);
      rst_n = 1;

      fork
        wait (halt_count > 10);
        repeat (500000) @(posedge clk);
      join_any
      repeat (10) @(posedge clk);

      $display("--- %s ---", bench_names[i]);
      if (halt_count <= 10) begin
        $display("  TIMEOUT (did not halt)");
      end else begin
        $display("  dmem: cycles=%0d instr=%0d branches=%0d mispred=%0d checksum=0x%08h",
          dut.u_dmem.mem[0], dut.u_dmem.mem[1], dut.u_dmem.mem[2],
          dut.u_dmem.mem[3], dut.u_dmem.mem[4]);
        $display("  CSR:  mcycle=%0d minstret=%0d branches=%0d mispred=%0d",
          dut.u_csr.mcycle, dut.u_csr.minstret,
          dut.u_csr.hpmcnt4, dut.u_csr.hpmcnt3);
        if (dut.u_dmem.mem[1] != 0)
          $display("  CPI:  %0d.%02d",
            dut.u_dmem.mem[0] / dut.u_dmem.mem[1],
            ((dut.u_dmem.mem[0] % dut.u_dmem.mem[1]) * 100) / dut.u_dmem.mem[1]);
      end
      $display("");
    end

    $display("==========================================================");
    $display("  4-Stage Benchmark Suite Complete");
    $display("==========================================================");
    $finish;
  end

  initial begin #50000000; $display("TIMEOUT"); $finish; end

endmodule
