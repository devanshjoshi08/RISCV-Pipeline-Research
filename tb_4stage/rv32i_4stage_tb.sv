`timescale 1ns / 1ps

module rv32i_4stage_tb;

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

  int pass_count, fail_count;

  task automatic check_reg(input int r, input int exp);
    logic [31:0] got;
    got = dut.u_regfile.regs[r];
    if (got == exp[31:0]) begin
      $display("  PASS: x%0d = %0d", r, got);
      pass_count++;
    end else begin
      $display("  FAIL: x%0d = %0d, expected %0d", r, got, exp);
      fail_count++;
    end
  endtask

  task automatic check_mem(input int addr, input int exp);
    logic [31:0] got;
    got = dut.u_dmem.mem[addr];
    if (got == exp[31:0]) begin
      $display("  PASS: mem[%0d] = %0d", addr, got);
      pass_count++;
    end else begin
      $display("  FAIL: mem[%0d] = %0d, expected %0d", addr, got, exp);
      fail_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    fail_count = 0;
    $display("=== 4-Stage Pipeline Testbench ===");
    rst_n = 0;
    repeat (5) @(posedge clk);
    rst_n = 1;

    $display("Running...");
    fork
      wait (halt_count > 10);
      repeat (2000) @(posedge clk);
    join_any
    repeat (10) @(posedge clk);

    $display("  Halted at PC = 0x%08h", debug_pc);
    $display("");
    check_reg(1, 55);
    check_reg(2, 11);
    check_reg(3, 11);
    check_reg(5, 55);
    check_mem(0, 55);

    $display("");
    $display("Register dump:");
    for (int i = 0; i < 32; i++)
      if (dut.u_regfile.regs[i] != 0)
        $display("  x%0d = %0d (0x%08h)", i, dut.u_regfile.regs[i], dut.u_regfile.regs[i]);

    $display("");
    $display("=== Results: %0d PASS, %0d FAIL ===", pass_count, fail_count);
    $finish;
  end

  initial begin #300000; $display("TIMEOUT"); $finish; end

endmodule
