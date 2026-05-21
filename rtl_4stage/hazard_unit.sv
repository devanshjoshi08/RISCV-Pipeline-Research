// 4-stage hazard control: IF → ID → EX → MW
// No load-use stall: MW forwards dmem result combinationally to EX.
// branch/jump/trap resolved in EX → flush IF, ID (2 instructions).
// MDU busy → stall everything from EX back.

module hazard_unit (
  input logic [4:0] ex_rs1_addr, ex_rs2_addr,
  input logic branch_taken, jal_ex, jalr_ex,
  input logic mdu_busy,
  input logic trap_flush,
  input logic mret_flush,
  output logic pc_stall, if_id_stall, id_ex_stall,
  output logic if_id_flush, id_ex_flush
);

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
