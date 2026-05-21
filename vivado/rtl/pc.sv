module pc (
  input logic clk,
  input logic rst_n,
  input logic pc_write,
  input logic [31:0] pc_next,
  output logic [31:0] pc_out
);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc_out <= 32'h0;
    else if (pc_write)
      pc_out <= pc_next;
  end

endmodule
