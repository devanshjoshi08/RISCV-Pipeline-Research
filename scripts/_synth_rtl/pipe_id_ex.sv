import pkg_riscv::*;

module pipe_id_ex (
  input logic clk, rst_n, flush, stall,

  input logic reg_write_in, mem_read_in, mem_write_in,
  input logic mem_to_reg_in, alu_src_in,
  input logic branch_in, jal_in, jalr_in, lui_in, auipc_in,
  input alu_op_t alu_op_in,
  input logic [31:0] pc_in, pc_plus4_in,
  input logic [31:0] rs1_data_in, rs2_data_in, imm_in,
  input logic [4:0] rs1_addr_in, rs2_addr_in, rd_addr_in,
  input logic [2:0] funct3_in,
  input logic predict_taken_in,
  input logic is_mext_in,
  input mdu_op_t mdu_op_in,
  input csr_op_t csr_op_in,
  input logic csr_zimm_in,
  input logic [11:0] csr_addr_in,
  input logic is_ecall_in, is_ebreak_in, is_mret_in,
  input logic illegal_instr_in,
  input logic [1:0] ras_ptr_in,

  output logic reg_write_out, mem_read_out, mem_write_out,
  output logic mem_to_reg_out, alu_src_out,
  output logic branch_out, jal_out, jalr_out, lui_out, auipc_out,
  output alu_op_t alu_op_out,
  output logic [31:0] pc_out, pc_plus4_out,
  output logic [31:0] rs1_data_out, rs2_data_out, imm_out,
  output logic [4:0] rs1_addr_out, rs2_addr_out, rd_addr_out,
  output logic [2:0] funct3_out,
  output logic predict_taken_out,
  output logic is_mext_out,
  output mdu_op_t mdu_op_out,
  output csr_op_t csr_op_out,
  output logic csr_zimm_out,
  output logic [11:0] csr_addr_out,
  output logic is_ecall_out, is_ebreak_out, is_mret_out,
  output logic illegal_instr_out,
  output logic [1:0] ras_ptr_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      reg_write_out <= 0; mem_read_out <= 0; mem_write_out <= 0;
      mem_to_reg_out <= 0; alu_src_out <= 0;
      branch_out <= 0; jal_out <= 0; jalr_out <= 0;
      lui_out <= 0; auipc_out <= 0;
      alu_op_out <= ALU_ADD;
      pc_out <= 0; pc_plus4_out <= 0;
      rs1_data_out <= 0; rs2_data_out <= 0; imm_out <= 0;
      rs1_addr_out <= 0; rs2_addr_out <= 0; rd_addr_out <= 0;
      funct3_out <= 0;
      predict_taken_out <= 0;
      is_mext_out <= 0;
      mdu_op_out <= MDU_MUL;
      csr_op_out <= CSR_NONE;
      csr_zimm_out <= 0;
      csr_addr_out <= 0;
      is_ecall_out <= 0; is_ebreak_out <= 0; is_mret_out <= 0;
      illegal_instr_out <= 0;
      ras_ptr_out <= 0;
    end else if (!stall) begin
      reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
      mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
      alu_src_out <= alu_src_in;
      branch_out <= branch_in; jal_out <= jal_in; jalr_out <= jalr_in;
      lui_out <= lui_in; auipc_out <= auipc_in;
      alu_op_out <= alu_op_in;
      pc_out <= pc_in; pc_plus4_out <= pc_plus4_in;
      rs1_data_out <= rs1_data_in; rs2_data_out <= rs2_data_in;
      imm_out <= imm_in;
      rs1_addr_out <= rs1_addr_in; rs2_addr_out <= rs2_addr_in;
      rd_addr_out <= rd_addr_in;
      funct3_out <= funct3_in;
      predict_taken_out <= predict_taken_in;
      is_mext_out <= is_mext_in;
      mdu_op_out <= mdu_op_in;
      csr_op_out <= csr_op_in;
      csr_zimm_out <= csr_zimm_in;
      csr_addr_out <= csr_addr_in;
      is_ecall_out <= is_ecall_in; is_ebreak_out <= is_ebreak_in;
      is_mret_out <= is_mret_in;
      illegal_instr_out <= illegal_instr_in;
      ras_ptr_out <= ras_ptr_in;
    end
  end

endmodule
