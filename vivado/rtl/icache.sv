// direct-mapped i-cache, 64 lines x 1 word.
// addr[31:8] = tag, addr[7:2] = index, addr[1:0] = ignored.
// hit = combinational, fill on miss.

module icache #(
  parameter NUM_LINES = 64,
  parameter INDEX_BITS = $clog2(NUM_LINES),
  parameter TAG_BITS = 32 - INDEX_BITS - 2
)(
  input logic clk, rst_n,
  input logic [31:0] addr,
  output logic [31:0] instr,
  output logic hit,
  output logic [31:0] mem_addr,
  input logic [31:0] mem_data
);

  logic valid [0:NUM_LINES-1];
  logic [TAG_BITS-1:0] tags [0:NUM_LINES-1];
  logic [31:0] data [0:NUM_LINES-1];

  logic [INDEX_BITS-1:0] index;
  logic [TAG_BITS-1:0] tag;
  assign index = addr[INDEX_BITS+1:2];
  assign tag = addr[31:INDEX_BITS+2];

  assign hit = valid[index] && (tags[index] == tag);
  assign instr = hit ? data[index] : mem_data;
  assign mem_addr = addr;

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < NUM_LINES; i++) begin
        valid[i] <= 0;
        tags[i] <= '0;
        data[i] <= 0;
      end
    end else if (!hit) begin
      valid[index] <= 1;
      tags[index] <= tag;
      data[index] <= mem_data;
    end
  end

endmodule
