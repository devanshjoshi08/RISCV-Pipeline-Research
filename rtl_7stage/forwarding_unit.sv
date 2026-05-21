// 3-source forwarding for 7-stage pipeline (IF1 → IF2 → ID → EX1 → EX2 → MEM → WB).
// Same forwarding topology as 6-stage: EX1 is the consumer, sources are EX2/MEM/WB.
// 00 = no forward, 01 = from EX2 (1 ahead), 10 = from MEM (2 ahead), 11 = from WB (3 ahead).
// EX2 has priority (most recent). Loads in EX2 are excluded (hazard unit stalls instead).

module forwarding_unit (
  input logic [4:0] ex1_rs1_addr, ex1_rs2_addr,
  input logic [4:0] ex2_rd_addr,
  input logic ex2_reg_write,
  input logic ex2_mem_read,
  input logic ex2_is_mext,
  input logic ex2_mdu_valid,
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

    // from WB (lowest priority)
    if (wb_reg_write && wb_rd_addr != 0 && wb_rd_addr == ex1_rs1_addr)
      forward_a = 2'b11;
    if (wb_reg_write && wb_rd_addr != 0 && wb_rd_addr == ex1_rs2_addr)
      forward_b = 2'b11;

    // from MEM (overrides WB)
    if (mem_reg_write && mem_rd_addr != 0 && mem_rd_addr == ex1_rs1_addr)
      forward_a = 2'b10;
    if (mem_reg_write && mem_rd_addr != 0 && mem_rd_addr == ex1_rs2_addr)
      forward_b = 2'b10;

    // from EX2 (highest priority, but not for loads or in-progress M-ext)
    if (ex2_reg_write && !ex2_mem_read && !(ex2_is_mext && !ex2_mdu_valid) &&
        ex2_rd_addr != 0 && ex2_rd_addr == ex1_rs1_addr)
      forward_a = 2'b01;
    if (ex2_reg_write && !ex2_mem_read && !(ex2_is_mext && !ex2_mdu_valid) &&
        ex2_rd_addr != 0 && ex2_rd_addr == ex1_rs2_addr)
      forward_b = 2'b01;
  end

endmodule
