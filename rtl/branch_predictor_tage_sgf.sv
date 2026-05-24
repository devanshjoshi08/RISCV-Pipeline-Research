// Downscaled TAGE predictor with Speculative GHR Forwarding. As in
// branch_predictor_sgf.sv, a speculative global history (spec_ghr) is updated at
// prediction time and used for the prediction-time folds, while a committed
// history (committed_ghr) tracks resolved outcomes; the per-branch speculative
// history is forwarded as a checkpoint and used to recompute every component's
// index and tag at update time, so all three tagged tables are corrected by one
// forwarded history. The checkpoint widens to the longest geometric history
// (HIST bits), the only growing cost over gshare, and recovery stays ROB-free:
// one checkpoint per in-flight branch, restored from committed_ghr on flush.

import pkg_riscv::*;

module branch_predictor_tage_sgf #(
  parameter PHT_DEPTH  = 64,
  parameter BTB_DEPTH  = 32,
  parameter RAS_DEPTH  = 4,
  parameter HIST       = 16            // longest global-history length / checkpoint width
)(
  input  logic        clk, rst_n,
  input  logic [31:0] pc_if,
  output logic        predict_taken,
  output logic [31:0] predict_target,
  output logic        predict_valid,
  output logic [HIST-1:0] ghr_checkpoint_out,
  input  logic        ras_push_en,
  input  logic [31:0] ras_push_addr,
  input  logic        update_en,
  input  logic [31:0] update_pc,
  input  logic        actual_taken,
  input  logic [31:0] actual_target,
  input  btb_type_t   update_type,
  input  logic [HIST-1:0] ghr_checkpoint_in,
  input  logic        flush,
  input  logic [1:0]  flush_ras_ptr,
  input  logic [HIST-1:0] flush_ghr,
  output logic [1:0]  ras_ptr_out
);
  localparam PHT_IDX = $clog2(PHT_DEPTH);
  localparam BTB_IDX = $clog2(BTB_DEPTH);
  localparam BTB_TAG = 32 - BTB_IDX - 2;

  logic [HIST-1:0] spec_ghr, committed_ghr;

  logic [1:0] bim [0:PHT_DEPTH-1];
  logic [7:0] t0_tag [0:PHT_DEPTH-1];  logic [2:0] t0_ctr [0:PHT_DEPTH-1];  logic t0_u [0:PHT_DEPTH-1];  logic t0_v [0:PHT_DEPTH-1];
  logic [7:0] t1_tag [0:PHT_DEPTH-1];  logic [2:0] t1_ctr [0:PHT_DEPTH-1];  logic t1_u [0:PHT_DEPTH-1];  logic t1_v [0:PHT_DEPTH-1];
  logic [7:0] t2_tag [0:PHT_DEPTH-1];  logic [2:0] t2_ctr [0:PHT_DEPTH-1];  logic t2_u [0:PHT_DEPTH-1];  logic t2_v [0:PHT_DEPTH-1];

  logic               btb_valid [0:BTB_DEPTH-1];
  logic [BTB_TAG-1:0] btb_tag   [0:BTB_DEPTH-1];
  logic [31:0]        btb_target[0:BTB_DEPTH-1];
  btb_type_t          btb_type  [0:BTB_DEPTH-1];
  logic [31:0] ras [0:RAS_DEPTH-1];
  logic [1:0]  ras_ptr;
  assign ras_ptr_out = ras_ptr;

  function automatic [PHT_IDX-1:0] fold_idx0(input [31:0] pc, input [HIST-1:0] h);
    fold_idx0 = pc[PHT_IDX+1:2] ^ {2'b0, h[3:0]};
  endfunction
  function automatic [PHT_IDX-1:0] fold_idx1(input [31:0] pc, input [HIST-1:0] h);
    fold_idx1 = pc[PHT_IDX+1:2] ^ h[5:0] ^ {4'b0, h[7:6]};
  endfunction
  function automatic [PHT_IDX-1:0] fold_idx2(input [31:0] pc, input [HIST-1:0] h);
    fold_idx2 = pc[PHT_IDX+1:2] ^ h[5:0] ^ h[11:6] ^ {2'b0, h[15:12]};
  endfunction
  function automatic [7:0] fold_tag0(input [31:0] pc, input [HIST-1:0] h);
    fold_tag0 = pc[15:8] ^ {4'b0, h[3:0]};
  endfunction
  function automatic [7:0] fold_tag1(input [31:0] pc, input [HIST-1:0] h);
    fold_tag1 = pc[15:8] ^ h[7:0];
  endfunction
  function automatic [7:0] fold_tag2(input [31:0] pc, input [HIST-1:0] h);
    fold_tag2 = pc[15:8] ^ h[7:0] ^ h[15:8];
  endfunction

  // --- prediction: folds use the speculative history ---
  logic [PHT_IDX-1:0] bidx, idx0, idx1, idx2, btb_pidx;
  logic [7:0]         tag0, tag1, tag2;
  logic [BTB_TAG-1:0] btb_ptag;
  assign bidx     = pc_if[PHT_IDX+1:2];
  assign idx0     = fold_idx0(pc_if, spec_ghr);
  assign idx1     = fold_idx1(pc_if, spec_ghr);
  assign idx2     = fold_idx2(pc_if, spec_ghr);
  assign tag0     = fold_tag0(pc_if, spec_ghr);
  assign tag1     = fold_tag1(pc_if, spec_ghr);
  assign tag2     = fold_tag2(pc_if, spec_ghr);
  assign btb_pidx = pc_if[BTB_IDX+1:2];
  assign btb_ptag = pc_if[31:BTB_IDX+2];
  assign ghr_checkpoint_out = spec_ghr;

  logic hit0, hit1, hit2, dir_taken;
  assign hit0 = t0_v[idx0] && (t0_tag[idx0] == tag0);
  assign hit1 = t1_v[idx1] && (t1_tag[idx1] == tag1);
  assign hit2 = t2_v[idx2] && (t2_tag[idx2] == tag2);
  assign dir_taken = hit2 ? t2_ctr[idx2][2] :
                     hit1 ? t1_ctr[idx1][2] :
                     hit0 ? t0_ctr[idx0][2] : bim[bidx][1];

  logic btb_hit;
  assign btb_hit = btb_valid[btb_pidx] && (btb_tag[btb_pidx] == btb_ptag);

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

  // --- update: folds use the per-branch checkpoint (precise history) ---
  logic [PHT_IDX-1:0] ubidx, uidx0, uidx1, uidx2, btb_uidx;
  logic [7:0]         utag0, utag1, utag2;
  logic [BTB_TAG-1:0] btb_utag;
  assign ubidx    = update_pc[PHT_IDX+1:2];
  assign uidx0    = fold_idx0(update_pc, ghr_checkpoint_in);
  assign uidx1    = fold_idx1(update_pc, ghr_checkpoint_in);
  assign uidx2    = fold_idx2(update_pc, ghr_checkpoint_in);
  assign utag0    = fold_tag0(update_pc, ghr_checkpoint_in);
  assign utag1    = fold_tag1(update_pc, ghr_checkpoint_in);
  assign utag2    = fold_tag2(update_pc, ghr_checkpoint_in);
  assign btb_uidx = update_pc[BTB_IDX+1:2];
  assign btb_utag = update_pc[31:BTB_IDX+2];

  logic uhit0, uhit1, uhit2;
  logic [2:0] prov_level;
  logic prov_pred, prov_correct;
  assign uhit0 = t0_v[uidx0] && (t0_tag[uidx0] == utag0);
  assign uhit1 = t1_v[uidx1] && (t1_tag[uidx1] == utag1);
  assign uhit2 = t2_v[uidx2] && (t2_tag[uidx2] == utag2);
  assign prov_level = uhit2 ? 3'd3 : uhit1 ? 3'd2 : uhit0 ? 3'd1 : 3'd0;
  assign prov_pred  = uhit2 ? t2_ctr[uidx2][2] :
                      uhit1 ? t1_ctr[uidx1][2] :
                      uhit0 ? t0_ctr[uidx0][2] : bim[ubidx][1];
  assign prov_correct = (prov_pred == actual_taken);

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spec_ghr <= 0; committed_ghr <= 0; ras_ptr <= 0;
      for (i = 0; i < PHT_DEPTH; i++) begin
        bim[i] <= 2'b01;
        t0_v[i] <= 0; t0_u[i] <= 0; t0_ctr[i] <= 3'b011; t0_tag[i] <= 0;
        t1_v[i] <= 0; t1_u[i] <= 0; t1_ctr[i] <= 3'b011; t1_tag[i] <= 0;
        t2_v[i] <= 0; t2_u[i] <= 0; t2_ctr[i] <= 3'b011; t2_tag[i] <= 0;
      end
      for (i = 0; i < BTB_DEPTH; i++) btb_valid[i] <= 0;
      for (i = 0; i < RAS_DEPTH; i++) ras[i] <= 0;
    end else begin
      // Speculative history advances at prediction time.
      if (is_conditional_branch && !flush)
        spec_ghr <= {spec_ghr[HIST-2:0], predict_taken};

      // Committed history advances at resolution.
      if (update_en)
        committed_ghr <= {committed_ghr[HIST-2:0], actual_taken};

      // Restore speculative history from committed on a misprediction flush.
      if (flush) begin
        if (update_en) spec_ghr <= {committed_ghr[HIST-2:0], actual_taken};
        else           spec_ghr <= committed_ghr;
        ras_ptr <= flush_ras_ptr;
      end

      if (ras_push_en && !flush) begin ras[ras_ptr] <= ras_push_addr; ras_ptr <= ras_ptr + 1; end

      if (update_en) begin
        case (prov_level)
          3'd3: if (actual_taken) begin if (t2_ctr[uidx2] < 3'b111) t2_ctr[uidx2] <= t2_ctr[uidx2] + 1; end
                else              begin if (t2_ctr[uidx2] > 3'b000) t2_ctr[uidx2] <= t2_ctr[uidx2] - 1; end
          3'd2: if (actual_taken) begin if (t1_ctr[uidx1] < 3'b111) t1_ctr[uidx1] <= t1_ctr[uidx1] + 1; end
                else              begin if (t1_ctr[uidx1] > 3'b000) t1_ctr[uidx1] <= t1_ctr[uidx1] - 1; end
          3'd1: if (actual_taken) begin if (t0_ctr[uidx0] < 3'b111) t0_ctr[uidx0] <= t0_ctr[uidx0] + 1; end
                else              begin if (t0_ctr[uidx0] > 3'b000) t0_ctr[uidx0] <= t0_ctr[uidx0] - 1; end
          default: if (actual_taken) begin if (bim[ubidx] < 2'b11) bim[ubidx] <= bim[ubidx] + 1; end
                   else              begin if (bim[ubidx] > 2'b00) bim[ubidx] <= bim[ubidx] - 1; end
        endcase

        if (prov_correct) begin
          if (prov_level == 3'd3) t2_u[uidx2] <= 1;
          else if (prov_level == 3'd2) t1_u[uidx1] <= 1;
          else if (prov_level == 3'd1) t0_u[uidx0] <= 1;
        end

        if (!prov_correct) begin
          if (prov_level <= 3'd0) begin
            if      (!t0_u[uidx0]) begin t0_v[uidx0] <= 1; t0_tag[uidx0] <= utag0; t0_ctr[uidx0] <= actual_taken ? 3'b100 : 3'b011; t0_u[uidx0] <= 0; end
            else if (!t1_u[uidx1]) begin t1_v[uidx1] <= 1; t1_tag[uidx1] <= utag1; t1_ctr[uidx1] <= actual_taken ? 3'b100 : 3'b011; t1_u[uidx1] <= 0; end
            else if (!t2_u[uidx2]) begin t2_v[uidx2] <= 1; t2_tag[uidx2] <= utag2; t2_ctr[uidx2] <= actual_taken ? 3'b100 : 3'b011; t2_u[uidx2] <= 0; end
            else begin t0_u[uidx0] <= 0; t1_u[uidx1] <= 0; t2_u[uidx2] <= 0; end
          end else if (prov_level == 3'd1) begin
            if      (!t1_u[uidx1]) begin t1_v[uidx1] <= 1; t1_tag[uidx1] <= utag1; t1_ctr[uidx1] <= actual_taken ? 3'b100 : 3'b011; t1_u[uidx1] <= 0; end
            else if (!t2_u[uidx2]) begin t2_v[uidx2] <= 1; t2_tag[uidx2] <= utag2; t2_ctr[uidx2] <= actual_taken ? 3'b100 : 3'b011; t2_u[uidx2] <= 0; end
            else begin t1_u[uidx1] <= 0; t2_u[uidx2] <= 0; end
          end else if (prov_level == 3'd2) begin
            if (!t2_u[uidx2]) begin t2_v[uidx2] <= 1; t2_tag[uidx2] <= utag2; t2_ctr[uidx2] <= actual_taken ? 3'b100 : 3'b011; t2_u[uidx2] <= 0; end
            else t2_u[uidx2] <= 0;
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
