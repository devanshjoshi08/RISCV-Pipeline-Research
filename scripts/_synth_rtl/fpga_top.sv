module fpga_top (
  input logic clk,
  input logic rst_btn,
  input logic [15:0] switches,
  output logic [15:0] leds,
  output logic serial_tx
);

  logic rst_n;
  assign rst_n = ~rst_btn;

  logic rst_sync_0, rst_sync_1;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rst_sync_0 <= 0;
      rst_sync_1 <= 0;
    end else begin
      rst_sync_0 <= 1;
      rst_sync_1 <= rst_sync_0;
    end
  end
  logic sys_rst_n;
  assign sys_rst_n = rst_sync_1;

  logic tx_start, tx_busy;
  logic [7:0] tx_din;
  logic [31:0] debug_pc, debug_instr, debug_alu_result;

  (* dont_touch = "true" *) rv32i_pipeline_mmio_top u_cpu (
    .clk(clk), .rst_n(sys_rst_n),
    .switches(switches), .leds(leds),
    .uart_start(tx_start), .uart_din(tx_din), .uart_busy(tx_busy),
    .debug_pc(debug_pc), .debug_instr(debug_instr),
    .debug_alu_result(debug_alu_result)
  );

  uart_tx u_uart (
    .clk(clk), .rst_n(sys_rst_n),
    .start(tx_start), .din(tx_din),
    .tx(serial_tx), .busy(tx_busy)
  );

endmodule
