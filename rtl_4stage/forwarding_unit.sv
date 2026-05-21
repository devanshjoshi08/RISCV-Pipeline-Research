// 1-source forwarding for 4-stage pipeline (IF -> ID -> EX -> MEM/WB).
// 00 = no forward, 01 = from MEM/WB (1 ahead).
// Only one forwarding source since MEM and WB are merged.

module forwarding_unit (
  input logic [4:0] ex_rs1_addr, ex_rs2_addr,
  input logic [4:0] mw_rd_addr,
  input logic mw_reg_write,
  output logic [1:0] forward_a,
  output logic [1:0] forward_b
);

  always_comb begin
    forward_a = 2'b00;
    forward_b = 2'b00;

    // from MEM/WB (only source -- 1 stage ahead)
    if (mw_reg_write && mw_rd_addr != 0 && mw_rd_addr == ex_rs1_addr)
      forward_a = 2'b01;
    if (mw_reg_write && mw_rd_addr != 0 && mw_rd_addr == ex_rs2_addr)
      forward_b = 2'b01;
  end

endmodule
