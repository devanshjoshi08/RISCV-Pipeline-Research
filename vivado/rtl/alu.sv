import pkg_riscv::*;

module alu (
  input logic [31:0] a,
  input logic [31:0] b,
  input alu_op_t op,
  output logic [31:0] result,
  output logic zero
);

  always_comb begin
    case (op)
      ALU_ADD: result = a + b;
      ALU_SUB: result = a - b;
      ALU_AND: result = a & b;
      ALU_OR:  result = a | b;
      ALU_XOR: result = a ^ b;
      ALU_SLT: result = {31'b0, $signed(a) < $signed(b)};
      ALU_SLTU: result = {31'b0, a < b};
      ALU_SLL: result = a << b[4:0];
      ALU_SRL: result = a >> b[4:0];
      ALU_SRA: result = $signed(a) >>> b[4:0];
      default: result = 32'b0;
    endcase
  end

  assign zero = (result == 32'b0);

endmodule
