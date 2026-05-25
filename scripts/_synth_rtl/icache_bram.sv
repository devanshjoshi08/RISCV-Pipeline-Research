// Direct-mapped i-cache for BRAM-backed instruction memory.
// Accounts for 1-cycle BRAM read latency on cache miss.
//
// addr[31:8] = tag, addr[7:2] = index, addr[1:0] = ignored.
//
// On hit:  instr is valid combinationally, valid_o = 1 (no stall).
// On miss: issues address to BRAM, waits 1 cycle for data, fills the
//          cache line, then asserts valid_o. Pipeline must stall when
//          valid_o = 0.

module icache_bram #(
  parameter NUM_LINES  = 64,
  parameter INDEX_BITS = $clog2(NUM_LINES),
  parameter TAG_BITS   = 32 - INDEX_BITS - 2
)(
  input  logic        clk,
  input  logic        rst_n,
  input  logic [31:0] addr,
  output logic [31:0] instr,
  output logic        valid_o,    // 1 = instr is valid this cycle

  // BRAM memory interface
  output logic [31:0] mem_addr,
  input  logic [31:0] mem_data    // arrives 1 cycle after mem_addr is presented
);

  // cache storage
  logic                  valid_arr [0:NUM_LINES-1];
  logic [TAG_BITS-1:0]   tags      [0:NUM_LINES-1];
  logic [31:0]           data      [0:NUM_LINES-1];

  // address decode
  logic [INDEX_BITS-1:0] index;
  logic [TAG_BITS-1:0]   tag;
  assign index = addr[INDEX_BITS+1:2];
  assign tag   = addr[31:INDEX_BITS+2];

  // hit detection
  logic cache_hit;
  assign cache_hit = valid_arr[index] && (tags[index] == tag);

  // FSM
  typedef enum logic [1:0] {
    S_IDLE,       // check cache, serve hit or start miss
    S_WAIT_BRAM   // waiting for BRAM read data (1-cycle latency)
  } state_t;

  state_t state, state_next;

  // Latched address for the miss in flight
  logic [31:0]           miss_addr_r;
  logic [INDEX_BITS-1:0] miss_index_r;
  logic [TAG_BITS-1:0]   miss_tag_r;

  // outputs
  always_comb begin
    // defaults
    mem_addr   = addr;       // speculatively present address to BRAM
    instr      = data[index];
    valid_o    = 1'b0;
    state_next = state;

    case (state)
      S_IDLE: begin
        if (cache_hit) begin
          instr   = data[index];
          valid_o = 1'b1;
          // stay in IDLE
        end else begin
          // Miss: address is already on mem_addr this cycle.
          // BRAM will return data on the NEXT posedge.
          mem_addr   = addr;
          valid_o    = 1'b0;
          state_next = S_WAIT_BRAM;
        end
      end

      S_WAIT_BRAM: begin
        // BRAM data is now available on mem_data.
        // Serve it directly and fill the cache line.
        mem_addr   = miss_addr_r;  // hold address stable (not strictly
                                   // needed since data already latched
                                   // by BRAM, but good practice)
        instr      = mem_data;
        valid_o    = 1'b1;
        state_next = S_IDLE;
      end

      default: state_next = S_IDLE;
    endcase
  end

  // sequential
  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      miss_addr_r  <= '0;
      miss_index_r <= '0;
      miss_tag_r   <= '0;
      for (i = 0; i < NUM_LINES; i++) begin
        valid_arr[i] <= 1'b0;
        tags[i]      <= '0;
        data[i]      <= 32'b0;
      end
    end else begin
      state <= state_next;

      case (state)
        S_IDLE: begin
          if (!cache_hit) begin
            // latch the miss address for use in S_WAIT_BRAM
            miss_addr_r  <= addr;
            miss_index_r <= index;
            miss_tag_r   <= tag;
          end
        end

        S_WAIT_BRAM: begin
          // fill the cache line with BRAM data
          valid_arr[miss_index_r] <= 1'b1;
          tags[miss_index_r]      <= miss_tag_r;
          data[miss_index_r]      <= mem_data;
        end

        default: ;
      endcase
    end
  end

endmodule
