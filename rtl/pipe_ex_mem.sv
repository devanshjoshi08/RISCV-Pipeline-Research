module pipe_ex_mem (
  input logic clk, rst_n,
  input logic reg_write_in, mem_read_in, mem_write_in, mem_to_reg_in,
  input logic jal_in, jalr_in,
  input logic [31:0] pc_plus4_in, alu_result_in, rs2_data_in,
  input logic [4:0] rd_addr_in,
  input logic [2:0] funct3_in,
  input logic is_csr_in,
  input logic [31:0] csr_rdata_in,

  output logic reg_write_out, mem_read_out, mem_write_out, mem_to_reg_out,
  output logic jal_out, jalr_out,
  output logic [31:0] pc_plus4_out, alu_result_out, rs2_data_out,
  output logic [4:0] rd_addr_out,
  output logic [2:0] funct3_out,
  output logic is_csr_out,
  output logic [31:0] csr_rdata_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_write_out <= 0; mem_read_out <= 0;
      mem_write_out <= 0; mem_to_reg_out <= 0;
      jal_out <= 0; jalr_out <= 0;
      pc_plus4_out <= 0; alu_result_out <= 0; rs2_data_out <= 0;
      rd_addr_out <= 0; funct3_out <= 0;
      is_csr_out <= 0; csr_rdata_out <= 0;
    end else begin
      reg_write_out <= reg_write_in; mem_read_out <= mem_read_in;
      mem_write_out <= mem_write_in; mem_to_reg_out <= mem_to_reg_in;
      jal_out <= jal_in; jalr_out <= jalr_in;
      pc_plus4_out <= pc_plus4_in; alu_result_out <= alu_result_in;
      rs2_data_out <= rs2_data_in;
      rd_addr_out <= rd_addr_in; funct3_out <= funct3_in;
      is_csr_out <= is_csr_in; csr_rdata_out <= csr_rdata_in;
    end
  end

endmodule
