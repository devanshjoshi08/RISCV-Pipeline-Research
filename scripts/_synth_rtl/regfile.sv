// 32x32 register file. x0 always reads as zero.
// write-through bypass so WB and ID can hit the same reg in one cycle.

module regfile (
  input logic clk,
  input logic rst_n,
  input logic we,
  input logic [4:0] rs1_addr,
  input logic [4:0] rs2_addr,
  input logic [4:0] rd_addr,
  input logic [31:0] rd_data,
  output logic [31:0] rs1_data,
  output logic [31:0] rs2_data
);

  logic [31:0] regs [0:31];

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 32; i++)
        regs[i] <= 32'b0;
    end else if (we && rd_addr != 5'b0) begin
      regs[rd_addr] <= rd_data;
    end
  end

  // bypass: if WB writes the same reg ID is reading, forward it
  assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 :
                    (we && rd_addr != 5'b0 && rd_addr == rs1_addr) ? rd_data :
                    regs[rs1_addr];
  assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 :
                    (we && rd_addr != 5'b0 && rd_addr == rs2_addr) ? rd_data :
                    regs[rs2_addr];

endmodule
