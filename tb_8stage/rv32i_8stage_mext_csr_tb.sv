`timescale 1ns / 1ps

module rv32i_8stage_mext_csr_tb;

  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  rv32i_pipeline_8stage_top dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  int halt_count;
  always_ff @(posedge clk) begin
    if (!rst_n) halt_count <= 0;
    else if (debug_instr == 32'h0000006F) halt_count <= halt_count + 1;
    else halt_count <= 0;
  end

  int pass_count, fail_count, total_tests;

  task automatic check_reg(input int r, input logic [31:0] exp, input string name);
    logic [31:0] got;
    got = dut.u_regfile.regs[r];
    total_tests++;
    if (got === exp) begin
      $display("  PASS [%2d] x%0d = 0x%08h  (%s)", total_tests, r, got, name);
      pass_count++;
    end else begin
      $display("  FAIL [%2d] x%0d = 0x%08h, expected 0x%08h  (%s)", total_tests, r, got, exp, name);
      fail_count++;
    end
  endtask

  initial begin
    $display("");
    $display("==========================================================");
    $display("  8-Stage RV32IM M-Extension + CSR Testbench");
    $display("==========================================================");
    $display("");

    pass_count = 0; fail_count = 0; total_tests = 0;
    rst_n = 0;

    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = 32'h00000013;
    $readmemh("test_mext_csr.hex", dut.u_imem.mem);

    repeat (5) @(posedge clk);
    rst_n = 1;

    fork
      wait (halt_count > 10);
      repeat (50000) @(posedge clk);
    join_any
    repeat (10) @(posedge clk);

    $display("  Program halted at PC = 0x%08h after %0t", debug_pc, $time);
    $display("");

    $display("--- M-extension ---");
    check_reg(10, 32'h0000005B, "MUL: 7*13=91");
    check_reg(14, 32'h0000000D, "DIV: 91/7=13");
    check_reg(15, 32'h00000000, "REM: 91%7=0");

    $display("");
    $display("==========================================================");
    $display("  RESULTS: %0d / %0d tests PASSED", pass_count, total_tests);
    if (fail_count == 0) $display("  ALL TESTS PASSED");
    else $display("  %0d TESTS FAILED", fail_count);
    $display("==========================================================");
    $display("");
    $finish;
  end

  initial begin #2000000; $display("TIMEOUT"); $finish; end

endmodule
