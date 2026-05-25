import pkg_riscv::*;

module branch_unit (
  input logic [2:0] funct3,
  input logic [31:0] rs1_data,
  input logic [31:0] rs2_data,
  output logic taken
);

  always_comb begin
    case (funct3)
      F3_BEQ:  taken = (rs1_data == rs2_data);
      F3_BNE:  taken = (rs1_data != rs2_data);
      F3_BLT:  taken = ($signed(rs1_data) < $signed(rs2_data));
      F3_BGE:  taken = ($signed(rs1_data) >= $signed(rs2_data));
      F3_BLTU: taken = (rs1_data < rs2_data);
      F3_BGEU: taken = (rs1_data >= rs2_data);
      default: taken = 1'b0;
    endcase
  end

endmodule
