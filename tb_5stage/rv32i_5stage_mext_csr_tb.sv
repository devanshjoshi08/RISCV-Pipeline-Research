`timescale 1ns / 1ps

module rv32i_5stage_mext_csr_tb;

  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  rv32i_pipeline_5stage_top dut (.*);

  initial clk = 0;
  always #5 clk = ~clk;

  int halt_count;
  always_ff @(posedge clk) begin
    if (!rst_n) halt_count <= 0;
    else if (debug_instr == 32'h0000006F) halt_count <= halt_count + 1;
    else halt_count <= 0;
  end

  task automatic check_reg(input int r, input int exp);
    logic [31:0] got;
    got = dut.u_regfile.regs[r];
    if (got == exp[31:0])
      $display("  PASS: x%0d = 0x%08h", r, got);
    else
      $display("  FAIL: x%0d = 0x%08h, expected 0x%08h", r, got, exp);
  endtask

  initial begin
    $display("5-Stage M-extension + CSR testbench");
    rst_n = 0;

    for (int i = 0; i < 1024; i++) dut.u_imem.mem[i] = 32'h00000013;
    $readmemh("test_mext_csr.hex", dut.u_imem.mem);

    repeat (5) @(posedge clk);
    rst_n = 1;

    fork
      wait (halt_count > 10);
      repeat (5000) @(posedge clk);
    join_any
    repeat (10) @(posedge clk);

    $display("  Halted at PC = 0x%08h", debug_pc);
    $display("");

    check_reg(10, 91);
    check_reg(11, 13);
    check_reg(12, 0);
    check_reg(13, -30);
    if (dut.u_regfile.regs[14] != 0)
      $display("  PASS: x14 (mcycle) = %0d (nonzero)", dut.u_regfile.regs[14]);
    else
      $display("  FAIL: x14 (mcycle) = 0");
    check_reg(15, 32'hDEADBEEF);

    $display("");
    $display("  mcycle=%0d  minstret=%0d  branches=%0d  mispred=%0d",
      dut.u_csr.mcycle, dut.u_csr.minstret, dut.u_csr.hpmcnt4, dut.u_csr.hpmcnt3);
    $display("done");
    $finish;
  end

  initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
