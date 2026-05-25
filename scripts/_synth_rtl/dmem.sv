import pkg_riscv::*;

module dmem #(parameter DEPTH = 2048) (
  input logic clk,
  input logic mem_read, mem_write,
  input logic [2:0] funct3,
  input logic [31:0] addr,
  input logic [31:0] write_data,
  output logic [31:0] read_data
);

  logic [31:0] mem [0:DEPTH-1];
  localparam ADDR_BITS = $clog2(DEPTH);
  logic [1:0] boff;
  logic [ADDR_BITS-1:0] waddr;
  assign boff = addr[1:0];
  assign waddr = addr[ADDR_BITS+1:2];

  always_ff @(posedge clk) begin
    if (mem_write) begin
      case (funct3)
        F3_BYTE:
          case (boff)
            2'b00: mem[waddr][7:0]   <= write_data[7:0];
            2'b01: mem[waddr][15:8]  <= write_data[7:0];
            2'b10: mem[waddr][23:16] <= write_data[7:0];
            2'b11: mem[waddr][31:24] <= write_data[7:0];
          endcase
        F3_HALF:
          case (boff[1])
            1'b0: mem[waddr][15:0]  <= write_data[15:0];
            1'b1: mem[waddr][31:16] <= write_data[15:0];
          endcase
        F3_WORD: mem[waddr] <= write_data;
        default: mem[waddr] <= write_data;
      endcase
    end
  end

  always_comb begin
    read_data = 0;
    if (mem_read) begin
      case (funct3)
        F3_BYTE:
          case (boff)
            2'b00: read_data = {{24{mem[waddr][7]}}, mem[waddr][7:0]};
            2'b01: read_data = {{24{mem[waddr][15]}}, mem[waddr][15:8]};
            2'b10: read_data = {{24{mem[waddr][23]}}, mem[waddr][23:16]};
            2'b11: read_data = {{24{mem[waddr][31]}}, mem[waddr][31:24]};
          endcase
        F3_HALF:
          case (boff[1])
            1'b0: read_data = {{16{mem[waddr][15]}}, mem[waddr][15:0]};
            1'b1: read_data = {{16{mem[waddr][31]}}, mem[waddr][31:16]};
          endcase
        F3_WORD: read_data = mem[waddr];
        F3_BYTEU:
          case (boff)
            2'b00: read_data = {24'b0, mem[waddr][7:0]};
            2'b01: read_data = {24'b0, mem[waddr][15:8]};
            2'b10: read_data = {24'b0, mem[waddr][23:16]};
            2'b11: read_data = {24'b0, mem[waddr][31:24]};
          endcase
        F3_HALFU:
          case (boff[1])
            1'b0: read_data = {16'b0, mem[waddr][15:0]};
            1'b1: read_data = {16'b0, mem[waddr][31:16]};
          endcase
        default: read_data = mem[waddr];
      endcase
    end
  end

endmodule
