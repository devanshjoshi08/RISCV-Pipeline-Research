`timescale 1ns / 1ps

module rv32i_4stage_riscv_tests_tb;

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

  string test_names[$] = '{
    "rv32ui-p-add", "rv32ui-p-addi", "rv32ui-p-and", "rv32ui-p-andi",
    "rv32ui-p-auipc", "rv32ui-p-beq", "rv32ui-p-bge", "rv32ui-p-bgeu",
    "rv32ui-p-blt", "rv32ui-p-bltu", "rv32ui-p-bne",
    "rv32ui-p-jal", "rv32ui-p-jalr",
    "rv32ui-p-lb", "rv32ui-p-lbu", "rv32ui-p-lh", "rv32ui-p-lhu", "rv32ui-p-lw",
    "rv32ui-p-lui",
    "rv32ui-p-or", "rv32ui-p-ori",
    "rv32ui-p-sb", "rv32ui-p-sh", "rv32ui-p-sw",
    "rv32ui-p-sll", "rv32ui-p-slli",
    "rv32ui-p-slt", "rv32ui-p-slti", "rv32ui-p-sltiu", "rv32ui-p-sltu",
    "rv32ui-p-sra", "rv32ui-p-srai",
    "rv32ui-p-srl", "rv32ui-p-srli",
    "rv32ui-p-sub", "rv32ui-p-xor", "rv32ui-p-xori"
  };

  int pass_count, fail_count;

  initial begin
    $display("");
    $display("==========================================================");
    $display("  4-Stage RV32IM RISC-V Compliance Tests");
    $display("==========================================================");
    $display("");

    pass_count = 0; fail_count = 0;

    foreach (test_names[i]) begin
      string hex_file;
      hex_file = {test_names[i], ".hex"};

      rst_n = 0;
      for (int j = 0; j < 1024; j++) dut.u_imem.mem[j] = 32'h00000013;
      $readmemh(hex_file, dut.u_imem.mem);
      repeat (5) @(posedge clk);
      rst_n = 1;

      fork
        wait (halt_count > 5);
        repeat (10000) @(posedge clk);
      join_any
      repeat (5) @(posedge clk);

      if (dut.u_regfile.regs[10] == 32'b0 && halt_count > 5) begin
        $display("  PASS  %s", test_names[i]);
        pass_count++;
      end else begin
        $display("  FAIL  %s  (x10=0x%08h)", test_names[i], dut.u_regfile.regs[10]);
        fail_count++;
      end
    end

    $display("");
    $display("==========================================================");
    $display("  RESULTS: %0d / %0d tests PASSED", pass_count, pass_count + fail_count);
    if (fail_count == 0) $display("  ALL TESTS PASSED");
    else $display("  %0d TESTS FAILED", fail_count);
    $display("==========================================================");
    $display("");
    $finish;
  end

  initial begin #50000000; $display("TIMEOUT"); $finish; end

endmodule
