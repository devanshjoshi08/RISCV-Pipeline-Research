// 0x0_______ = memory, 0x10000000+ = peripherals
import pkg_riscv::*;

module mmio (
  input logic clk, rst_n,
  input logic mem_read, mem_write,
  input logic [2:0] funct3,
  input logic [31:0] addr, write_data,
  output logic [31:0] read_data,
  input logic [15:0] switches,
  output logic [15:0] leds,
  output logic uart_start,
  output logic [7:0] uart_din,
  input logic uart_busy,
  output logic [31:0] imem_data_addr,
  input logic [31:0] imem_data_out
);

  logic is_mem, is_led, is_switch, is_uart_data, is_uart_status;
  assign is_mem = (addr[31:28] == 4'h0);
  assign is_led = (addr == 32'h10000000);
  assign is_switch = (addr == 32'h10000004);
  assign is_uart_data = (addr == 32'h10000008);
  assign is_uart_status = (addr == 32'h1000000C);

  assign imem_data_addr = addr;

  logic [31:0] dmem_rdata;
  dmem u_dmem (
    .clk(clk), .mem_read(mem_read & is_mem), .mem_write(mem_write & is_mem),
    .funct3(funct3), .addr(addr), .write_data(write_data), .read_data(dmem_rdata)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      leds <= 0;
    else if (mem_write && is_led)
      leds <= write_data[15:0];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uart_start <= 0;
      uart_din <= 0;
    end else if (mem_write && is_uart_data && !uart_busy) begin
      uart_start <= 1;
      uart_din <= write_data[7:0];
    end else begin
      uart_start <= 0;
    end
  end

  // for memory reads, use DMEM result. if DMEM returns 0 and the address
  // is in the code region, check IMEM instead (for .rodata like strings).
  // IMEM word needs byte extraction since strings are read with lbu.
  logic [31:0] imem_byte;
  logic [1:0] boff;
  assign boff = addr[1:0];

  always_comb begin
    case (boff)
      2'b00: imem_byte = {24'b0, imem_data_out[7:0]};
      2'b01: imem_byte = {24'b0, imem_data_out[15:8]};
      2'b10: imem_byte = {24'b0, imem_data_out[23:16]};
      2'b11: imem_byte = {24'b0, imem_data_out[31:24]};
    endcase
  end

  always_comb begin
    if (is_mem) begin
      if (dmem_rdata != 0)
        read_data = dmem_rdata;
      else if (funct3 == F3_BYTEU || funct3 == F3_BYTE)
        read_data = imem_byte;
      else
        read_data = imem_data_out;
    end
    else if (is_switch) read_data = {16'b0, switches};
    else if (is_uart_status) read_data = {31'b0, uart_busy};
    else read_data = 0;
  end

endmodule
