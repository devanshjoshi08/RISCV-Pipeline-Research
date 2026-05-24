// Tournament predictor with Speculative GHR Forwarding applied to its
// GHR-indexed components (the global PHT and the chooser). Same interface as
// branch_predictor_sgf.sv: adds ghr_checkpoint_out (spec_ghr at prediction) and
// ghr_checkpoint_in (the checkpointed history returned at resolution).
// spec_ghr updates at prediction time; the global-PHT and chooser indices use it
// for reads and use the forwarded checkpoint for writes. The local (PC-indexed)
// PHT is untouched by history and needs no checkpoint.

import pkg_riscv::*;

module branch_predictor_tournament_sgf #(
  parameter PHT_DEPTH  = 64,
  parameter BTB_DEPTH  = 32,
  parameter RAS_DEPTH  = 4
)(
  input  logic        clk, rst_n,
  input  logic [31:0] pc_if,
  output logic        predict_taken,
  output logic [31:0] predict_target,
  output logic        predict_valid,
  output logic [$clog2(PHT_DEPTH)-1:0] ghr_checkpoint_out,
  input  logic        ras_push_en,
  input  logic [31:0] ras_push_addr,
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic        actual_taken,
  input  logic [31:0] actual_target,
  input  btb_type_t   update_type,
  input  logic [$clog2(PHT_DEPTH)-1:0] ghr_checkpoint_in,
  input  logic        flush,
  input  logic [1:0]  flush_ras_ptr,
  input  logic [$clog2(PHT_DEPTH)-1:0] flush_ghr,
  output logic [1:0]  ras_ptr_out
);
  localparam PHT_IDX = $clog2(PHT_DEPTH);
  localparam BTB_IDX = $clog2(BTB_DEPTH);
  localparam BTB_TAG = 32 - BTB_IDX - 2;

  // Dual GHR (as in branch_predictor_sgf): spec updates at prediction, committed at resolution.
  logic [PHT_IDX-1:0] spec_ghr, committed_ghr;
  logic [1:0] pht_g   [0:PHT_DEPTH-1];
  logic [1:0] pht_l   [0:PHT_DEPTH-1];
  logic [1:0] chooser [0:PHT_DEPTH-1];

  logic               btb_valid [0:BTB_DEPTH-1];
  logic [BTB_TAG-1:0] btb_tag   [0:BTB_DEPTH-1];
  logic [31:0]        btb_target[0:BTB_DEPTH-1];
  btb_type_t          btb_type  [0:BTB_DEPTH-1];
  logic [31:0] ras [0:RAS_DEPTH-1];
  logic [1:0]  ras_ptr;
  assign ras_ptr_out = ras_ptr;

  // --- prediction: GHR-derived indices use the speculative history ---
  logic [PHT_IDX-1:0] gidx, lidx, cidx, btb_pidx;
  logic [BTB_TAG-1:0] btb_ptag;
  assign gidx     = pc_if[PHT_IDX+1:2] ^ spec_ghr;
  assign lidx     = pc_if[PHT_IDX+1:2];
  assign cidx     = spec_ghr;
  assign btb_pidx = pc_if[BTB_IDX+1:2];
  assign btb_ptag = pc_if[31:BTB_IDX+2];
  assign ghr_checkpoint_out = spec_ghr;

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

  logic is_conditional_branch;
  assign is_conditional_branch = btb_hit && (btb_type[btb_pidx] == BTB_BRANCH);

  // --- update: GHR-derived indices use the per-branch checkpoint (precise) ---
  logic [PHT_IDX-1:0] gidx_u, lidx_u, cidx_u, btb_uidx;
  logic [BTB_TAG-1:0] btb_utag;
  assign gidx_u   = update_pc[PHT_IDX+1:2] ^ ghr_checkpoint_in;
  assign lidx_u   = update_pc[PHT_IDX+1:2];
  assign cidx_u   = ghr_checkpoint_in;
  assign btb_uidx = update_pc[BTB_IDX+1:2];
  assign btb_utag = update_pc[31:BTB_IDX+2];

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spec_ghr <= 0; committed_ghr <= 0; ras_ptr <= 0;
      for (i = 0; i < PHT_DEPTH; i++) begin
        pht_g[i] <= 2'b01; pht_l[i] <= 2'b01; chooser[i] <= 2'b10;
      end
      for (i = 0; i < BTB_DEPTH; i++) btb_valid[i] <= 0;
      for (i = 0; i < RAS_DEPTH; i++) ras[i] <= 0;
    end else begin
      // Speculative GHR update at prediction time (fresh history for next prediction).
      if (is_conditional_branch && !flush)
        spec_ghr <= {spec_ghr[PHT_IDX-2:0], predict_taken};

      // Committed GHR update at resolution.
      if (update_en)
        committed_ghr <= {committed_ghr[PHT_IDX-2:0], actual_taken};

      // Restore speculative history on misprediction flush.
      if (flush) begin
        if (update_en) spec_ghr <= {committed_ghr[PHT_IDX-2:0], actual_taken};
        else           spec_ghr <= committed_ghr;
        ras_ptr <= flush_ras_ptr;
      end

      if (ras_push_en && !flush) begin
        ras[ras_ptr] <= ras_push_addr; ras_ptr <= ras_ptr + 1;
      end

      if (update_en) begin
        if (actual_taken && pht_g[gidx_u] < 2'b11)      pht_g[gidx_u] <= pht_g[gidx_u] + 1;
        else if (!actual_taken && pht_g[gidx_u] > 2'b00) pht_g[gidx_u] <= pht_g[gidx_u] - 1;
        if (actual_taken && pht_l[lidx_u] < 2'b11)      pht_l[lidx_u] <= pht_l[lidx_u] + 1;
        else if (!actual_taken && pht_l[lidx_u] > 2'b00) pht_l[lidx_u] <= pht_l[lidx_u] - 1;

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
