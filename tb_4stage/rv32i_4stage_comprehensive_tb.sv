`timescale 1ns / 1ps

module rv32i_4stage_comprehensive_tb;

  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  rv32i_pipeline_4stage_top dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  // Halt: detect jal x0,0 (0x0000006F) in ID stage
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

  task automatic check_reg_nonzero(input int r, input string name);
    logic [31:0] got;
    got = dut.u_regfile.regs[r];
    total_tests++;
    if (got !== 32'b0) begin
      $display("  PASS [%2d] x%0d = 0x%08h (nonzero)  (%s)", total_tests, r, got, name);
      pass_count++;
    end else begin
      $display("  FAIL [%2d] x%0d = 0 (expected nonzero)  (%s)", total_tests, r, name);
      fail_count++;
    end
  endtask

  initial begin
    $display("");
    $display("==========================================================");
    $display("  4-Stage RV32IM Comprehensive Testbench");
    $display("==========================================================");
    $display("");

    pass_count = 0; fail_count = 0; total_tests = 0;
    rst_n = 0;

    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = 32'h00000013;
    $readmemh("test_comprehensive.hex", dut.u_imem.mem);

    repeat (5) @(posedge clk);
    rst_n = 1;

    fork
      wait (halt_count > 10);
      repeat (20000) @(posedge clk);
    join_any
    repeat (10) @(posedge clk);

    $display("  Program halted at PC = 0x%08h after %0t", debug_pc, $time);
    $display("");

    $display("--- M-extension Multiply ---");
    check_reg(10, 32'h0000005B, "MUL: 7*13=91");
    check_reg(11, 32'hFFFFFFFF, "MULH: upper(-2 * 0x7FFFFFFF)");
    check_reg(12, 32'hFFFFFFFF, "MULHSU: upper(-2s * 3u)");
    check_reg(13, 32'h00000000, "MULHU: upper(3u * 5u)=0");

    $display("");
    $display("--- M-extension Divide ---");
    check_reg(14, 32'h0000000D, "DIV: 91/7=13");
    check_reg(15, 32'h00000000, "REM: 91%7=0");
    check_reg(16, 32'hFFFFFFFF, "DIVU: 0xFFFFFFFF/1");
    check_reg(17, 32'h00000000, "REMU: 0xFFFFFFFF%1=0");
    check_reg(18, 32'hFFFFFFFF, "DIV by zero -> -1");
    check_reg(19, 32'h00000007, "REM by zero -> dividend=7");
    check_reg(20, 32'h80000000, "DIV overflow: MIN_INT/-1");
    check_reg(21, 32'h00000000, "REM overflow: MIN_INT%-1=0");

    $display("");
    $display("--- CSR Operations ---");
    check_reg_nonzero(22, "mcycle nonzero");
    check_reg_nonzero(23, "minstret nonzero");
    check_reg(24, 32'hDEADBEEF, "CSRRW+read mscratch");
    check_reg(25, 32'hDEADBEEF, "CSRRS old value");
    check_reg(26, 32'hDEADBEFF, "CSRRC old value");
    check_reg(27, 32'h0000001F, "CSRRSI read mscratch");
    check_reg(28, 32'h0000001F, "CSRRCI old value");
    check_reg(29, 32'h00000017, "mscratch final");

    $display("");
    $display("--- Trap Handling ---");
    check_reg(30, 32'h000000AB, "trap handler reached");
    check_reg(31, 32'h0000000B, "mcause=11 (ecall)");

    $display("");
    $display("--- Pipeline Hazard (mul forwarding) ---");
    check_reg(3, 32'h0000002A, "MUL result: 6*7=42");
    check_reg(4, 32'h00000030, "ADD after MUL: 42+6=48");

    $display("");
    $display("==========================================================");
    $display("  RESULTS: %0d / %0d tests PASSED", pass_count, total_tests);
    if (fail_count == 0) $display("  ALL TESTS PASSED");
    else $display("  %0d TESTS FAILED", fail_count);
    $display("==========================================================");
    $display("");
    $display("  Performance counters:");
    $display("    mcycle   = %0d", dut.u_csr.mcycle);
    $display("    minstret = %0d", dut.u_csr.minstret);
    $display("    branches = %0d", dut.u_csr.hpmcnt4);
    $display("    mispred  = %0d", dut.u_csr.hpmcnt3);
    $display("");
    $finish;
  end

  initial begin #2000000; $display("TIMEOUT"); $finish; end

endmodule
