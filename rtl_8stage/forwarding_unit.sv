// 3-source forwarding for 8-stage pipeline (IF1 -> IF2 -> ID -> EX1 -> EX2 -> MEM1 -> MEM2 -> WB).
// EX1 is the consumer, explicit forwarding sources are EX2/MEM1/MEM2.
// WB writeback reaches the regfile in time for EX1's fresh-read bypass, so no explicit WB forward.
// 00 = no forward (use fresh regfile read with WB bypass),
// 01 = from EX2 (1 ahead, exclude loads and in-progress MDU),
// 10 = from MEM1 (2 ahead, exclude loads -- dmem data not ready until MEM2),
// 11 = from MEM2 (3 ahead, includes loads -- dmem data captured in pipe_mem1_mem2).
// Priority: EX2 > MEM1 > MEM2 (EX2 is most recent).

module forwarding_unit (
  input logic [4:0] ex1_rs1_addr, ex1_rs2_addr,
  input logic [4:0] ex2_rd_addr,
  input logic ex2_reg_write,
  input logic ex2_mem_read,
  input logic ex2_is_mext,
  input logic ex2_mdu_valid,
  input logic [4:0] mem1_rd_addr,
  input logic mem1_reg_write,
  input logic mem1_mem_read,
  input logic [4:0] mem2_rd_addr,
  input logic mem2_reg_write,
  output logic [1:0] forward_a,
  output logic [1:0] forward_b
);

  always_comb begin
    forward_a = 2'b00;
    forward_b = 2'b00;

    // from MEM2 (lowest explicit priority, includes loads)
    if (mem2_reg_write && mem2_rd_addr != 0 && mem2_rd_addr == ex1_rs1_addr)
      forward_a = 2'b11;
    if (mem2_reg_write && mem2_rd_addr != 0 && mem2_rd_addr == ex1_rs2_addr)
      forward_b = 2'b11;

    // from MEM1 (overrides MEM2, but excludes loads -- dmem data not ready)
    if (mem1_reg_write && !mem1_mem_read && mem1_rd_addr != 0 && mem1_rd_addr == ex1_rs1_addr)
      forward_a = 2'b10;
    if (mem1_reg_write && !mem1_mem_read && mem1_rd_addr != 0 && mem1_rd_addr == ex1_rs2_addr)
      forward_b = 2'b10;

    // from EX2 (highest priority, excludes loads and in-progress M-ext)
    if (ex2_reg_write && !ex2_mem_read && !(ex2_is_mext && !ex2_mdu_valid) &&
        ex2_rd_addr != 0 && ex2_rd_addr == ex1_rs1_addr)
      forward_a = 2'b01;
    if (ex2_reg_write && !ex2_mem_read && !(ex2_is_mext && !ex2_mdu_valid) &&
        ex2_rd_addr != 0 && ex2_rd_addr == ex1_rs2_addr)
      forward_b = 2'b01;
  end

endmodule
