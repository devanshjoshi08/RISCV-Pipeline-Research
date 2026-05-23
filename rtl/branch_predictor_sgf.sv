// gshare predictor with a speculative GHR. spec_ghr updates at prediction time,
// committed_ghr at resolution; predictions index on spec_ghr, PHT updates index on
// a per-branch GHR checkpoint forwarded through the pipeline, and spec_ghr is
// restored from committed_ghr on flush. Adds ghr_checkpoint_out/ghr_checkpoint_in
// to the branch_predictor.sv interface.

import pkg_riscv::*;

module branch_predictor_sgf #(
  parameter PHT_DEPTH  = 64,
  parameter BTB_DEPTH  = 32,
  parameter RAS_DEPTH  = 4
)(
  input  logic        clk, rst_n,

  // IF/IF2 stage: prediction
  input  logic [31:0] pc_if,
  output logic        predict_taken,
  output logic [31:0] predict_target,
  output logic        predict_valid,

  // Speculative GHR checkpoint: save at prediction, return at resolution
  output logic [$clog2(PHT_DEPTH)-1:0] ghr_checkpoint_out,

  // ID stage: RAS push
  input  logic        ras_push_en,
  input  logic [31:0] ras_push_addr,

  // EX2 stage: update on resolution
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic        actual_taken,
  input  logic [31:0] actual_target,
  input  btb_type_t   update_type,
  input  logic [$clog2(PHT_DEPTH)-1:0] ghr_checkpoint_in, // checkpointed GHR from prediction time

  // flush: restore speculative state on mispredict
  input  logic        flush,
  input  logic [1:0]  flush_ras_ptr,
  input  logic [$clog2(PHT_DEPTH)-1:0] flush_ghr, // committed GHR to restore on flush

  output logic [1:0]  ras_ptr_out
);

  localparam PHT_IDX  = $clog2(PHT_DEPTH);
  localparam BTB_IDX  = $clog2(BTB_DEPTH);
  localparam BTB_TAG  = 32 - BTB_IDX - 2;

  // Two-GHR architecture
  // spec_ghr: updated speculatively at prediction time (fresh for next prediction)
  // committed_ghr: updated at branch resolution (ground truth)
  logic [PHT_IDX-1:0] spec_ghr;
  logic [PHT_IDX-1:0] committed_ghr;

  // PHT: 2-bit saturating counters
  logic [1:0] pht [0:PHT_DEPTH-1];

  // BTB
  logic              btb_valid [0:BTB_DEPTH-1];
  logic [BTB_TAG-1:0] btb_tag [0:BTB_DEPTH-1];
  logic [31:0]       btb_target[0:BTB_DEPTH-1];
  btb_type_t         btb_type  [0:BTB_DEPTH-1];

  // RAS
  logic [31:0] ras [0:RAS_DEPTH-1];
  logic [1:0]  ras_ptr;
  assign ras_ptr_out = ras_ptr;

  // Prediction indexing (uses SPECULATIVE GHR)
  logic [PHT_IDX-1:0] pht_predict_idx;
  logic [BTB_IDX-1:0] btb_predict_idx;
  logic [BTB_TAG-1:0] btb_predict_tag;

  assign pht_predict_idx = pc_if[PHT_IDX+1:2] ^ spec_ghr;
  assign btb_predict_idx = pc_if[BTB_IDX+1:2];
  assign btb_predict_tag = pc_if[31:BTB_IDX+2];

  logic btb_hit;
  assign btb_hit = btb_valid[btb_predict_idx] &&
                   (btb_tag[btb_predict_idx] == btb_predict_tag);

  logic pht_taken;
  assign pht_taken = pht[pht_predict_idx][1];

  // Export current spec_ghr as checkpoint for pipeline forwarding
  assign ghr_checkpoint_out = spec_ghr;

  // Prediction outputs (identical logic to baseline)
  always_comb begin
    predict_valid = btb_hit;
    if (btb_hit && btb_type[btb_predict_idx] == BTB_RET) begin
      predict_taken  = 1'b1;
      predict_target = ras[ras_ptr - 2'd1];
    end else if (btb_hit && (btb_type[btb_predict_idx] == BTB_JAL ||
                              btb_type[btb_predict_idx] == BTB_CALL)) begin
      predict_taken  = 1'b1;
      predict_target = btb_target[btb_predict_idx];
    end else begin
      predict_taken  = btb_hit & pht_taken;
      predict_target = btb_target[btb_predict_idx];
    end
  end

  // Update indexing (uses CHECKPOINTED GHR from prediction time)
  logic [PHT_IDX-1:0] pht_update_idx;
  logic [BTB_IDX-1:0] btb_update_idx;
  logic [BTB_TAG-1:0] btb_update_tag;

  assign pht_update_idx = update_pc[PHT_IDX+1:2] ^ ghr_checkpoint_in;
  assign btb_update_idx = update_pc[BTB_IDX+1:2];
  assign btb_update_tag = update_pc[31:BTB_IDX+2];

  // Determine if this prediction is on a conditional branch (for spec GHR update)
  logic is_conditional_branch;
  assign is_conditional_branch = btb_hit &&
    (btb_type[btb_predict_idx] == BTB_BRANCH);

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spec_ghr <= 0;
      committed_ghr <= 0;
      ras_ptr <= 0;
      for (i = 0; i < PHT_DEPTH; i++)
        pht[i] <= 2'b01;
      for (i = 0; i < BTB_DEPTH; i++)
        btb_valid[i] <= 0;
      for (i = 0; i < RAS_DEPTH; i++)
        ras[i] <= 0;
    end else begin

      // Speculative GHR update at prediction time
      // On every conditional branch prediction, shift the predicted direction
      // into spec_ghr. This keeps the history fresh for the next prediction,
      // even if the current branch hasn't resolved yet.
      if (is_conditional_branch && !flush) begin
        spec_ghr <= {spec_ghr[PHT_IDX-2:0], predict_taken};
      end

      // Committed GHR update at resolution time
      if (update_en) begin
        committed_ghr <= {committed_ghr[PHT_IDX-2:0], actual_taken};
      end

      // Restore speculative GHR on misprediction
      // On flush, the speculative path was wrong. Restore spec_ghr from
      // the committed state (shifted by the actual outcome of the flushing branch).
      if (flush) begin
        if (update_en)
          spec_ghr <= {committed_ghr[PHT_IDX-2:0], actual_taken};
        else
          spec_ghr <= committed_ghr;
        ras_ptr <= flush_ras_ptr;
      end

      // RAS push from ID stage
      if (ras_push_en && !flush) begin
        ras[ras_ptr] <= ras_push_addr;
        ras_ptr <= ras_ptr + 1;
      end

      // PHT update using CHECKPOINTED GHR (precise indexing)
      if (update_en) begin
        if (actual_taken && pht[pht_update_idx] < 2'b11)
          pht[pht_update_idx] <= pht[pht_update_idx] + 1;
        else if (!actual_taken && pht[pht_update_idx] > 2'b00)
          pht[pht_update_idx] <= pht[pht_update_idx] - 1;

        // BTB update
        if (actual_taken) begin
          btb_valid [btb_update_idx] <= 1;
          btb_tag   [btb_update_idx] <= btb_update_tag;
          btb_target[btb_update_idx] <= actual_target;
          btb_type  [btb_update_idx] <= update_type;
        end
      end
    end
  end

endmodule
