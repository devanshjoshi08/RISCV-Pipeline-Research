// 16KB instruction memory for CoreMark and larger benchmarks.
// Same interface as imem.sv but with 4096-word (16KB) depth.
// No hardcoded program — relies entirely on $readmemh or testbench loading.

module imem_16k (
  input logic [31:0] addr,
  output logic [31:0] instr,
  input logic [31:0] data_addr,
  output logic [31:0] data_out
);

  localparam DEPTH = 4096; // 16KB

  logic [31:0] mem [0:DEPTH-1];

  initial begin
    for (int i = 0; i < DEPTH; i++)
      mem[i] = 32'h00000013; // NOP

    // synthesis translate_off
    $readmemh("program.hex", mem);
    // synthesis translate_on
  end

  assign instr = mem[addr[31:2]];
  assign data_out = mem[data_addr[31:2]];

endmodule
