// 8-stage hazard control: IF1 -> IF2 -> ID -> EX1 -> EX2 -> MEM1 -> MEM2 -> WB
// Load-use: check BOTH EX2 and MEM1 for load hazards against EX1 sources.
//   - load in EX2, dependent in EX1 -> stall (data not ready until MEM2, 2 cycles away)
//   - load in MEM1, dependent in EX1 -> stall (data not ready until MEM2, 1 cycle away)
//   This naturally produces 2 stall cycles for a load immediately followed by dependent instr.
// Branch/jump/trap resolved in EX2 -> flush IF1, IF2, ID, EX1 (4 instructions), same as 7-stage.
// MDU busy -> stall everything from EX2 back.

module hazard_unit (
  input logic ex2_mem_read,
  input logic [4:0] ex2_rd_addr,
  input logic mem1_mem_read,
  input logic [4:0] mem1_rd_addr,
  input logic [4:0] ex1_rs1_addr, ex1_rs2_addr,
  input logic branch_taken, jal_ex2, jalr_ex2,
  input logic mdu_busy,
  input logic trap_flush,
  input logic mret_flush,
  output logic pc_stall, if1_if2_stall, if_id_stall, id_ex1_stall, ex1_ex2_stall,
  output logic if1_if2_flush, if_id_flush, id_ex1_flush, ex1_ex2_flush
);

  logic load_use_ex2, load_use_mem1, load_use;

  // Load in EX2: data won't be available until MEM2 (2 cycles away)
  assign load_use_ex2 = ex2_mem_read && (ex2_rd_addr != 0) &&
                        ((ex2_rd_addr == ex1_rs1_addr) || (ex2_rd_addr == ex1_rs2_addr));

  // Load in MEM1: data won't be available until MEM2 (1 cycle away)
  assign load_use_mem1 = mem1_mem_read && (mem1_rd_addr != 0) &&
                         ((mem1_rd_addr == ex1_rs1_addr) || (mem1_rd_addr == ex1_rs2_addr));

  assign load_use = load_use_ex2 || load_use_mem1;

  always_comb begin
    pc_stall = 0;
    if1_if2_stall = 0;
    if_id_stall = 0;
    id_ex1_stall = 0;
    ex1_ex2_stall = 0;
    if1_if2_flush = 0;
    if_id_flush = 0;
    id_ex1_flush = 0;
    ex1_ex2_flush = 0;

    if (mdu_busy) begin
      pc_stall = 1;
      if1_if2_stall = 1;
      if_id_stall = 1;
      id_ex1_stall = 1;
      ex1_ex2_stall = 1;
    end else if (load_use) begin
      pc_stall = 1;
      if1_if2_stall = 1;
      if_id_stall = 1;
      id_ex1_stall = 1;
      ex1_ex2_flush = 1;
    end

    // Branch/jump/trap override: flush 4 stages, cancel stalls
    if (trap_flush || mret_flush || branch_taken || jal_ex2 || jalr_ex2) begin
      if1_if2_flush = 1;
      if_id_flush = 1;
      id_ex1_flush = 1;
      ex1_ex2_flush = 1;
      pc_stall = 0;
      if1_if2_stall = 0;
      if_id_stall = 0;
      id_ex1_stall = 0;
      ex1_ex2_stall = 0;
    end
  end

endmodule
