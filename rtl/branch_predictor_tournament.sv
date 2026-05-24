// Tournament predictor: a global (gshare-style, PC^GHR) PHT and a local
// (PC-indexed) PHT, selected per-branch by a GHR-indexed 2-bit chooser, plus a
// shared BTB and RAS. Same interface as branch_predictor.sv (drop-in baseline).
// The global component and the chooser are GHR-indexed and therefore exhibit
// Mechanism B; the local component is PC-indexed and does not. This is the
// baseline (committed-GHR) version; branch_predictor_tournament_sgf.sv adds SGF.

import pkg_riscv::*;

module branch_predictor_tournament #(
  parameter PHT_DEPTH  = 64,
  parameter BTB_DEPTH  = 32,
  parameter RAS_DEPTH  = 4
)(
  input  logic        clk, rst_n,
  input  logic [31:0] pc_if,
  output logic        predict_taken,
  output logic [31:0] predict_target,
  output logic        predict_valid,
  input  logic        ras_push_en,
  input  logic [31:0] ras_push_addr,
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic        actual_taken,
  input  logic [31:0] actual_target,
  input  btb_type_t   update_type,
  input  logic        flush,
  input  logic [1:0]  flush_ras_ptr,
  output logic [1:0]  ras_ptr_out
);
  localparam PHT_IDX = $clog2(PHT_DEPTH);
  localparam BTB_IDX = $clog2(BTB_DEPTH);
  localparam BTB_TAG = 32 - BTB_IDX - 2;

  logic [PHT_IDX-1:0] ghr;
  logic [1:0] pht_g   [0:PHT_DEPTH-1];  // global  (PC ^ GHR)
  logic [1:0] pht_l   [0:PHT_DEPTH-1];  // local   (PC only)
  logic [1:0] chooser [0:PHT_DEPTH-1];  // GHR-indexed; MSB=1 selects global

  logic               btb_valid [0:BTB_DEPTH-1];
  logic [BTB_TAG-1:0] btb_tag   [0:BTB_DEPTH-1];
  logic [31:0]        btb_target[0:BTB_DEPTH-1];
  btb_type_t          btb_type  [0:BTB_DEPTH-1];
  logic [31:0] ras [0:RAS_DEPTH-1];
  logic [1:0]  ras_ptr;
  assign ras_ptr_out = ras_ptr;

  // --- prediction indices ---
  logic [PHT_IDX-1:0] gidx, lidx, cidx, btb_pidx;
  logic [BTB_TAG-1:0] btb_ptag;
  assign gidx     = pc_if[PHT_IDX+1:2] ^ ghr;
  assign lidx     = pc_if[PHT_IDX+1:2];
  assign cidx     = ghr;
  assign btb_pidx = pc_if[BTB_IDX+1:2];
  assign btb_ptag = pc_if[31:BTB_IDX+2];

  logic btb_hit, use_global, dir_taken;
  assign btb_hit    = btb_valid[btb_pidx] && (btb_tag[btb_pidx] == btb_ptag);
  assign use_global = chooser[cidx][1];
  assign dir_taken  = use_global ? pht_g[gidx][1] : pht_l[lidx][1];

  always_comb begin
    predict_valid = btb_hit;
    if (btb_hit && btb_type[btb_pidx] == BTB_RET) begin
      predict_taken  = 1'b1;
      predict_target = ras[ras_ptr - 2'd1];
    end else if (btb_hit && (btb_type[btb_pidx] == BTB_JAL ||
                              btb_type[btb_pidx] == BTB_CALL)) begin
      predict_taken  = 1'b1;
      predict_target = btb_target[btb_pidx];
    end else begin
      predict_taken  = btb_hit & dir_taken;
      predict_target = btb_target[btb_pidx];
    end
  end

  // --- update indices (current GHR, i.e. committed; the baseline staleness) ---
  logic [PHT_IDX-1:0] gidx_u, lidx_u, cidx_u, btb_uidx;
  logic [BTB_TAG-1:0] btb_utag;
  assign gidx_u   = update_pc[PHT_IDX+1:2] ^ ghr;
  assign lidx_u   = update_pc[PHT_IDX+1:2];
  assign cidx_u   = ghr;
  assign btb_uidx = update_pc[BTB_IDX+1:2];
  assign btb_utag = update_pc[31:BTB_IDX+2];

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ghr <= 0; ras_ptr <= 0;
      for (i = 0; i < PHT_DEPTH; i++) begin
        pht_g[i] <= 2'b01; pht_l[i] <= 2'b01; chooser[i] <= 2'b10;
      end
      for (i = 0; i < BTB_DEPTH; i++) btb_valid[i] <= 0;
      for (i = 0; i < RAS_DEPTH; i++) ras[i] <= 0;
    end else begin
      if (ras_push_en) begin ras[ras_ptr] <= ras_push_addr; ras_ptr <= ras_ptr + 1; end
      if (flush) ras_ptr <= flush_ras_ptr;

      if (update_en) begin
        ghr <= {ghr[PHT_IDX-2:0], actual_taken};

        if (actual_taken && pht_g[gidx_u] < 2'b11)      pht_g[gidx_u] <= pht_g[gidx_u] + 1;
        else if (!actual_taken && pht_g[gidx_u] > 2'b00) pht_g[gidx_u] <= pht_g[gidx_u] - 1;
        if (actual_taken && pht_l[lidx_u] < 2'b11)      pht_l[lidx_u] <= pht_l[lidx_u] + 1;
        else if (!actual_taken && pht_l[lidx_u] > 2'b00) pht_l[lidx_u] <= pht_l[lidx_u] - 1;

        // Train the chooser only when the two components disagreed (NBA reads
        // the pre-update counters, i.e. the predictions they actually made).
        if (pht_g[gidx_u][1] != pht_l[lidx_u][1]) begin
          if (pht_g[gidx_u][1] == actual_taken) begin
            if (chooser[cidx_u] < 2'b11) chooser[cidx_u] <= chooser[cidx_u] + 1;
          end else begin
            if (chooser[cidx_u] > 2'b00) chooser[cidx_u] <= chooser[cidx_u] - 1;
          end
        end

        if (actual_taken) begin
          btb_valid [btb_uidx] <= 1;
          btb_tag   [btb_uidx] <= btb_utag;
          btb_target[btb_uidx] <= actual_target;
          btb_type  [btb_uidx] <= update_type;
        end
      end
    end
  end
endmodule
