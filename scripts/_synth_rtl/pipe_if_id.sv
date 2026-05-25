module pipe_if_id (
  input logic clk, rst_n, stall, flush,
  input logic [31:0] pc_in, pc_plus4_in, instr_in,
  input logic predict_taken_in,
  output logic [31:0] pc_out, pc_plus4_out, instr_out,
  output logic predict_taken_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || flush) begin
      pc_out <= 32'b0;
      pc_plus4_out <= 32'b0;
      instr_out <= 32'h00000013; // NOP
      predict_taken_out <= 0;
    end else if (!stall) begin
      pc_out <= pc_in;
      pc_plus4_out <= pc_plus4_in;
      instr_out <= instr_in;
      predict_taken_out <= predict_taken_in;
    end
  end

endmodule
