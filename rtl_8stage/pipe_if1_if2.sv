// IF1/IF2 pipeline register for 8-stage pipeline.
// IF1 generates PC and reads icache (combinational).
// This register captures the instruction + PC for IF2 (branch prediction).

module pipe_if1_if2 (
  input logic clk, rst_n, stall, flush,
  input logic [31:0] pc_in, pc_plus4_in, instr_in,
  output logic [31:0] pc_out, pc_plus4_out, instr_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      pc_out <= 32'b0;
      pc_plus4_out <= 32'b0;
      instr_out <= 32'h00000013; // NOP
    end else if (!stall) begin
      pc_out <= pc_in;
      pc_plus4_out <= pc_plus4_in;
      instr_out <= instr_in;
    end
  end

endmodule
