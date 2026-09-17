// Simulation-only observer included inside sgf_evaluation_tb. No DUT writes.
// Capture pre-edge lookup state when a conditional instruction enters IF/ID.
// Metadata uses the exact flush/stall precedence of the real pipeline.
  typedef struct packed {
    logic valid;
    logic [31:0] pc;
    logic sgf_taken, shadow_taken;
    logic [1:0] sgf_counter, shadow_counter;
    logic [1:0] depth;
    logic history_diff, btb_hit;
  } observation_t;
  observation_t obs_id, obs_ex1, obs_ex2;
  wire [31:0] obs_prediction_instr;
`ifdef SGF_SIX_STAGE
  assign obs_prediction_instr = dut.if_instr;
`else
  assign obs_prediction_instr = dut.if2_instr;
`endif
  wire [5:0] obs_shadow_index = dut.u_bp.pc_if[7:2] ^ dut.u_bp.committed_ghr;
  wire [1:0] obs_sgf_counter = dut.u_bp.pht[dut.u_bp.pht_predict_idx];
  wire [1:0] obs_shadow_counter = dut.u_bp.pht[obs_shadow_index];
  // Same BTB gate/type handling as the shipped predictor, different PHT index.
  wire obs_shadow_taken = dut.u_bp.btb_hit &&
    ((dut.u_bp.btb_type[dut.u_bp.btb_predict_idx] != pkg_riscv::BTB_BRANCH) ||
     obs_shadow_counter[1]);
  // Category: 0 both correct, 1 both wrong, 2 SGF-only, 3 committed-only.
  longint unsigned obs_counts [0:3][0:3][0:3][0:1][0:1][0:3];
  longint unsigned obs_issued_bins [0:3][0:3][0:3][0:1][0:1];
  longint unsigned obs_issued_differ_bins [0:3][0:3][0:3][0:1][0:1];
  longint unsigned obs_issued, obs_resolved, obs_sgf_wrong, obs_shadow_wrong;
  integer obs_category;

  initial begin
    if (dut.u_bp.PHT_DEPTH != 64)
      $fatal(1, "CHAR_ERROR monitor assumes the shipped 6-bit GHR/64-entry PHT configuration");
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      obs_id <= '0;
      obs_ex1 <= '0;
      obs_ex2 <= '0;
      obs_issued = 0;
      obs_resolved = 0;
      obs_sgf_wrong = 0;
      obs_shadow_wrong = 0;
      for (int s = 0; s < 4; s++)
        for (int c = 0; c < 4; c++)
          for (int d = 0; d < 4; d++)
            for (int g = 0; g < 2; g++)
              for (int b = 0; b < 2; b++) begin
                obs_issued_bins[s][c][d][g][b] = 0;
                obs_issued_differ_bins[s][c][d][g][b] = 0;
                for (int k = 0; k < 4; k++) obs_counts[s][c][d][g][b][k] = 0;
              end
    end else begin
      // EX2 is the actual resolution/counter boundary (not WB retirement).
      if (dut.ex2_branch) begin
        if (!obs_ex2.valid || obs_ex2.pc != dut.ex2_pc ||
            obs_ex2.sgf_taken != dut.ex2_predicted_taken)
          $fatal(1, "CHAR_ERROR branch metadata does not match EX2");
        obs_resolved = obs_resolved + 1;
        if (obs_ex2.sgf_taken != dut.ex2_branch_taken) obs_sgf_wrong++;
        if (obs_ex2.shadow_taken != dut.ex2_branch_taken) obs_shadow_wrong++;
        if (obs_ex2.sgf_taken == dut.ex2_branch_taken)
          obs_category = (obs_ex2.shadow_taken == dut.ex2_branch_taken) ? 0 : 2;
        else
          obs_category = (obs_ex2.shadow_taken == dut.ex2_branch_taken) ? 3 : 1;
        obs_counts[obs_ex2.sgf_counter][obs_ex2.shadow_counter][obs_ex2.depth]
                  [obs_ex2.history_diff][obs_ex2.btb_hit][obs_category]++;
      end else if (obs_ex2.valid)
        $fatal(1, "CHAR_ERROR metadata valid without EX2 branch");

      if (dut.ex1_ex2_flush) obs_ex2 <= '0;
      else if (!dut.mdu_stall) obs_ex2 <= obs_ex1;
      if (dut.id_ex1_flush) obs_ex1 <= '0;
      else if (!dut.id_ex1_stall) obs_ex1 <= obs_id;
      if (dut.if_id_flush) obs_id <= '0;
      else if (!dut.if_id_stall) begin
        obs_id.valid <= (obs_prediction_instr[6:0] == 7'b1100011);
        obs_id.pc <= dut.u_bp.pc_if;
        obs_id.sgf_taken <= dut.u_bp.predict_taken && dut.u_bp.predict_valid;
        obs_id.shadow_taken <= obs_shadow_taken;
        obs_id.sgf_counter <= obs_sgf_counter;
        obs_id.shadow_counter <= obs_shadow_counter;
        // Older accepted conditional branches present just before this edge,
        // including EX2 if it resolves on this same edge. JAL is not counted.
        obs_id.depth <= int'(obs_id.valid) + int'(obs_ex1.valid) + int'(obs_ex2.valid);
        obs_id.history_diff <= (dut.u_bp.spec_ghr != dut.u_bp.committed_ghr);
        obs_id.btb_hit <= dut.u_bp.btb_hit;
        if (obs_prediction_instr[6:0] == 7'b1100011) begin
          obs_issued++;
          obs_issued_bins[obs_sgf_counter][obs_shadow_counter]
            [int'(obs_id.valid) + int'(obs_ex1.valid) + int'(obs_ex2.valid)]
            [dut.u_bp.spec_ghr != dut.u_bp.committed_ghr][dut.u_bp.btb_hit]++;
          if ((dut.u_bp.predict_taken && dut.u_bp.predict_valid) != obs_shadow_taken)
            obs_issued_differ_bins[obs_sgf_counter][obs_shadow_counter]
              [int'(obs_id.valid) + int'(obs_ex1.valid) + int'(obs_ex2.valid)]
              [dut.u_bp.spec_ghr != dut.u_bp.committed_ghr][dut.u_bp.btb_hit]++;
          if (dut.u_bp.spec_ghr == dut.u_bp.committed_ghr &&
              (dut.u_bp.predict_taken && dut.u_bp.predict_valid) != obs_shadow_taken)
            $fatal(1, "CHAR_ERROR equal histories must give equal predictions");
        end
      end
    end
  end

  task dump_characterization;
    longint unsigned bc, bw, sc, cc;
    integer outstanding;
    outstanding = int'(obs_id.valid) + int'(obs_ex1.valid) + int'(obs_ex2.valid);
    if (obs_resolved != dut.u_csr.hpmcnt4 || obs_sgf_wrong != dut.u_csr.hpmcnt3)
      $fatal(1, "CHAR_ERROR observer totals do not match CSR counters");
    $display("CHAR_TOTAL issued=%0d resolved=%0d outstanding=%0d squashed=%0d sgf_wrong=%0d shadow_wrong=%0d",
      obs_issued, obs_resolved, outstanding, obs_issued - obs_resolved - outstanding,
      obs_sgf_wrong, obs_shadow_wrong);
    for (int s = 0; s < 4; s++)
      for (int c = 0; c < 4; c++)
        for (int d = 0; d < 4; d++)
          for (int g = 0; g < 2; g++)
            for (int b = 0; b < 2; b++) begin
              bc = obs_counts[s][c][d][g][b][0];
              bw = obs_counts[s][c][d][g][b][1];
              sc = obs_counts[s][c][d][g][b][2];
              cc = obs_counts[s][c][d][g][b][3];
              if (obs_issued_bins[s][c][d][g][b] != 0)
                $display("CHAR sgf_counter=%0d shadow_counter=%0d depth=%0d ghr_diff=%0d btb_hit=%0d issued=%0d issued_agree=%0d issued_differ=%0d agree=%0d differ=%0d sgf_only_correct=%0d committed_only_correct=%0d both_correct=%0d both_wrong=%0d",
                  s, c, d, g, b, obs_issued_bins[s][c][d][g][b],
                  obs_issued_bins[s][c][d][g][b] - obs_issued_differ_bins[s][c][d][g][b],
                  obs_issued_differ_bins[s][c][d][g][b], bc + bw, sc + cc, sc, cc, bc, bw);
            end
  endtask
