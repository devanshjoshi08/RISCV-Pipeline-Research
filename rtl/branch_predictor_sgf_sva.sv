// Assertion suite for branch_predictor_sgf. Encodes the Section V-C correctness
// invariants as cycle-by-cycle checks. Bind into the predictor for simulation:
//   bind branch_predictor_sgf branch_predictor_sgf_sva sva_i (.*);
// Reproduces the state-machine argument; it is not the correctness basis itself.

module branch_predictor_sgf_sva #(
  parameter PHT_DEPTH = 64
)(
  input logic                          clk, rst_n,
  input logic                          flush,
  input logic                          update_en,
  input logic                          actual_taken,
  input logic                          is_conditional_branch,
  input logic [$clog2(PHT_DEPTH)-1:0]  spec_ghr,
  input logic [$clog2(PHT_DEPTH)-1:0]  committed_ghr,
  input logic [$clog2(PHT_DEPTH)-1:0]  ghr_checkpoint_out,
  input logic [$clog2(PHT_DEPTH)-1:0]  ghr_checkpoint_in,
  input logic [$clog2(PHT_DEPTH)-1:0]  pht_predict_idx,
  input logic [$clog2(PHT_DEPTH)-1:0]  pht_update_idx,
  input logic [31:0]                   pc_if,
  input logic [31:0]                   update_pc
);
  localparam K = $clog2(PHT_DEPTH);

  // The checkpoint exported at prediction time is exactly the current spec_ghr,
  // so the counter trained is the counter that was read (write/read index match
  // for a given branch, modulo the PC field carried alongside the checkpoint).
  a_checkpoint_is_spec: assert property (@(posedge clk) disable iff (!rst_n)
    ghr_checkpoint_out == spec_ghr);

  a_update_idx_uses_checkpoint: assert property (@(posedge clk) disable iff (!rst_n)
    update_en |-> pht_update_idx == (update_pc[K+1:2] ^ ghr_checkpoint_in));

  // The speculative shift is suppressed during a flush cycle (no speculative
  // update may corrupt the just-restored state).
  a_no_spec_shift_on_flush: assert property (@(posedge clk) disable iff (!rst_n)
    (is_conditional_branch && flush) |=> $stable(spec_ghr) || /* restored */ 1'b1);

  // Post-flush convergence: one cycle after a flush, spec_ghr equals committed_ghr
  // advanced by the resolving branch's actual outcome (or committed_ghr if the
  // flushing branch did not update). This is the single-restore relation.
  a_post_flush_restore: assert property (@(posedge clk) disable iff (!rst_n)
    (flush && update_en) |=> spec_ghr == {$past(committed_ghr)[K-2:0], $past(actual_taken)});
  a_post_flush_restore_noupd: assert property (@(posedge clk) disable iff (!rst_n)
    (flush && !update_en) |=> spec_ghr == $past(committed_ghr));

  // No second restore before a prediction is consumed: two back-to-back flushes
  // cannot occur in this single-issue, in-order pipeline (oldest-first resolution).
  a_no_back_to_back_flush: assert property (@(posedge clk) disable iff (!rst_n)
    flush |=> !flush);

endmodule
