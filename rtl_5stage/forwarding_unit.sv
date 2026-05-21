// 2-source forwarding for 5-stage pipeline (IF → ID → EX → MEM → WB).
// 00 = no forward, 01 = from MEM (1 ahead), 10 = from WB (2 ahead).
// MEM has priority (most recent). Loads in MEM are forwarded directly
// since MEM data is available combinationally within the MEM stage.

module forwarding_unit (
  input logic [4:0] ex_rs1_addr, ex_rs2_addr,
  input logic [4:0] mem_rd_addr,
  input logic mem_reg_write,
  input logic [4:0] wb_rd_addr,
  input logic wb_reg_write,
  output logic [1:0] forward_a,
  output logic [1:0] forward_b
);

  always_comb begin
    forward_a = 2'b00;
    forward_b = 2'b00;

    // from WB (lower priority)
    if (wb_reg_write && wb_rd_addr != 0 && wb_rd_addr == ex_rs1_addr)
      forward_a = 2'b10;
    if (wb_reg_write && wb_rd_addr != 0 && wb_rd_addr == ex_rs2_addr)
      forward_b = 2'b10;

    // from MEM (higher priority — most recent result)
    if (mem_reg_write && mem_rd_addr != 0 && mem_rd_addr == ex_rs1_addr)
      forward_a = 2'b01;
    if (mem_reg_write && mem_rd_addr != 0 && mem_rd_addr == ex_rs2_addr)
      forward_b = 2'b01;
  end

endmodule
