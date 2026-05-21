// 115200 baud 8N1 UART transmitter. CLKS_PER_BIT = 100MHz / 115200.

module uart_tx #(parameter CLKS_PER_BIT = 868) (
  input logic clk, rst_n,
  input logic start,
  input logic [7:0] din,
  output logic tx,
  output logic busy
);

  typedef enum logic [1:0] { IDLE, START_BIT, DATA_BITS, STOP_BIT } state_t;

  state_t state;
  logic [$clog2(CLKS_PER_BIT)-1:0] clk_count;
  logic [2:0] bit_idx;
  logic [7:0] shift;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      tx <= 1;
      busy <= 0;
      clk_count <= 0;
      bit_idx <= 0;
      shift <= 0;
    end else begin
      case (state)
        IDLE: begin
          tx <= 1;
          busy <= 0;
          if (start) begin
            state <= START_BIT;
            shift <= din;
            busy <= 1;
            clk_count <= 0;
          end
        end
        START_BIT: begin
          tx <= 0;
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            bit_idx <= 0;
            state <= DATA_BITS;
          end else
            clk_count <= clk_count + 1;
        end
        DATA_BITS: begin
          tx <= shift[bit_idx];
          if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            if (bit_idx == 7)
              state <= STOP_BIT;
            else
              bit_idx <= bit_idx + 1;
          end else
            clk_count <= clk_count + 1;
        end
        STOP_BIT: begin
          tx <= 1;
          if (clk_count == CLKS_PER_BIT - 1)
            state <= IDLE;
          else
            clk_count <= clk_count + 1;
        end
      endcase
    end
  end

endmodule
