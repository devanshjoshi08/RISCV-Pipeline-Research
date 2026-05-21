// 5-stage hazard control: IF → ID → EX → MEM → WB
// load-use: load in MEM, dependent in EX → stall 1 cycle.
// branch/jump/trap resolved in EX → flush IF, ID (2 instructions).
// MDU busy → stall everything from EX back.

module hazard_unit (
  input logic mem_mem_read,
  input logic [4:0] mem_rd_addr,
  input logic [4:0] ex_rs1_addr, ex_rs2_addr,
  input logic branch_taken, jal_ex, jalr_ex,
  input logic mdu_busy,
  input logic trap_flush,
  input logic mret_flush,
  output logic pc_stall, if_id_stall, id_ex_stall,
  output logic if_id_flush, id_ex_flush
);

  logic load_use;
  assign load_use = mem_mem_read && (mem_rd_addr != 0) &&
                    ((mem_rd_addr == ex_rs1_addr) || (mem_rd_addr == ex_rs2_addr));

  always_comb begin
    pc_stall = 0;
    if_id_stall = 0;
    id_ex_stall = 0;
    if_id_flush = 0;
    id_ex_flush = 0;

    if (mdu_busy) begin
      pc_stall = 1;
      if_id_stall = 1;
      id_ex_stall = 1;
    end else if (load_use) begin
      pc_stall = 1;
      if_id_stall = 1;
      id_ex_flush = 1;
    end

    if (trap_flush || mret_flush || branch_taken || jal_ex || jalr_ex) begin
      if_id_flush = 1;
      id_ex_flush = 1;
      pc_stall = 0;
      if_id_stall = 0;
      id_ex_stall = 0;
    end
  end

endmodule
