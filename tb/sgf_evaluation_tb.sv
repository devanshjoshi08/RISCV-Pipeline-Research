`timescale 1ns / 1ps

// Shared Icarus/Verilator harness for the 6/7/8-stage baseline and SGF evaluations.
// DUT_MODULE is supplied by scripts/run_sgf_evaluation.py.  Instruction memory
// is loaded by rtl/imem.sv from program.hex in the simulation working directory.
module sgf_evaluation_tb;
  logic clk, rst_n;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  `DUT_MODULE dut (.*);

`ifdef SGF_CONF_FILTER
  // Diagnostic-only parameter override used to reproduce historical filtered
  // SGF runs. Normal evaluation builds do not define SGF_CONF_FILTER.
  defparam dut.u_bp.CONF_FILTER = `SGF_CONF_FILTER;
`endif

  // The prebuilt benchmark images fit in 16 KiB instruction/data memories.
  defparam dut.u_imem.DEPTH = 4096;
  defparam dut.u_dmem.DEPTH = 4096;

  string data_hex;
  integer max_cycles;
  integer halt_count;
  integer elapsed_cycles;
  logic [31:0] previous_pc;

`ifdef SGF_CHARACTERIZE
  `include "sgf_characterization_monitor.svh"
`endif

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    for (integer i = 0; i < 4096; i = i + 1)
      dut.u_dmem.mem[i] = 32'h00000000;
    if ($value$plusargs("DATA_HEX=%s", data_hex))
      $readmemh(data_hex, dut.u_dmem.mem);
  end

  // The benchmark runtime terminates in a one- or two-instruction loop.  Using
  // the 8-byte PC region also handles the two-instruction halt loops emitted by
  // some of the prebuilt Embench images.
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      previous_pc <= 32'hffff_ffff;
      halt_count <= 0;
    end else begin
      if (debug_pc[31:3] == previous_pc[31:3])
        halt_count <= halt_count + 1;
      else
        halt_count <= 0;
      previous_pc <= debug_pc;
    end
  end

  initial begin
    if (!$value$plusargs("MAX_CYCLES=%d", max_cycles))
      max_cycles = 50000000;

    rst_n = 1'b0;
    halt_count = 0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    elapsed_cycles = 0;
    while ((halt_count <= 1000) && (elapsed_cycles < max_cycles)) begin
      @(posedge clk);
      elapsed_cycles = elapsed_cycles + 1;
    end

    if (elapsed_cycles >= max_cycles) begin
      $display("EVAL_ERROR timeout after %0d cycles pc=0x%08x", max_cycles, debug_pc);
      $fatal(1);
    end

    repeat (10) @(posedge clk);
    if ((dut.u_dmem.mem[0] === 32'hxxxxxxxx) ||
        (dut.u_dmem.mem[1] === 32'hxxxxxxxx) ||
        (dut.u_dmem.mem[2] === 32'hxxxxxxxx) ||
        (dut.u_dmem.mem[3] === 32'hxxxxxxxx) ||
        (dut.u_dmem.mem[4] === 32'hxxxxxxxx) ||
        (dut.u_dmem.mem[1] == 0)) begin
      $display("EVAL_ERROR benchmark did not publish valid dmem[0..4] results");
      $fatal(1);
    end

`ifdef SGF_CHARACTERIZE
    // Observe after the NBA updates; this changes no DUT state.
    @(negedge clk);
    dump_characterization();
`endif
    $display("RESULT cycles=%0d instructions=%0d branches=%0d mispredictions=%0d checksum=%08x",
      dut.u_dmem.mem[0], dut.u_dmem.mem[1], dut.u_dmem.mem[2],
      dut.u_dmem.mem[3], dut.u_dmem.mem[4]);
    $finish;
  end
endmodule
