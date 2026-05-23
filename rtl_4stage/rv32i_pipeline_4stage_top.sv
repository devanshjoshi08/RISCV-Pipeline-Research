// 4-stage RV32IM pipeline: IF → ID → EX → MW
// EX1 and EX2 from the 6-stage design are merged into a single EX stage.
// MEM and WB are merged into a single MW (memory/writeback) stage.
// Branch resolution in EX → 2-cycle mispredict penalty (flush IF, ID).
// Forwarding: 1 source (MW → EX). No load-use stall — MW forwards
// dmem result combinationally, accepting the longer critical path.
// MDU remains multi-cycle (2-cycle multiply, 32-cycle divide), stalls pipeline.

import pkg_riscv::*;

module rv32i_pipeline_4stage_top (
  input logic clk,
  input logic rst_n,
  output logic [31:0] debug_pc,
  output logic [31:0] debug_instr,
  output logic [31:0] debug_alu_result
);

    // hazard / forwarding control
    logic        pc_stall, if_id_stall, id_ex_stall;
    logic        if_id_flush, id_ex_flush;
    logic [1:0]  forward_a, forward_b;

    // IF stage
    logic [31:0] if_pc, if_pc_plus4, if_instr;
    logic [31:0] pc_next;
    logic        if_predict_taken;
    logic [31:0] if_predict_target;
    logic        if_predict_valid;
    logic        icache_hit;
    logic [31:0] imem_raw_instr, icache_mem_addr;

    // IF/ID outputs
    logic [31:0] id_pc, id_pc_plus4, id_instr;

    // ID stage
    logic [6:0]  id_opcode;
    logic [4:0]  id_rd, id_rs1, id_rs2;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [11:0] id_funct12;
    logic [31:0] id_rs1_data, id_rs2_data, id_imm;
    logic        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    logic        id_alu_src, id_branch, id_jal, id_jalr, id_lui, id_auipc;
    imm_type_t   id_imm_type;
    alu_op_t     id_alu_op;
    logic        id_is_mext;
    mdu_op_t     id_mdu_op;
    csr_op_t     id_csr_op;
    logic        id_csr_zimm;
    logic        id_is_ecall, id_is_ebreak, id_is_mret;
    logic        id_illegal_instr;
    logic        id_predict_taken;
    logic [1:0]  ras_ptr_current;
    logic        id_ras_push, id_is_call, id_is_ret;

    // ID/EX outputs
    logic [31:0] ex_pc, ex_pc_plus4, ex_rs1_data, ex_rs2_data, ex_imm;
    logic [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    logic [2:0]  ex_funct3;
    logic        ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    logic        ex_alu_src, ex_branch, ex_jal, ex_jalr, ex_lui, ex_auipc;
    alu_op_t     ex_alu_op;
    logic        ex_is_mext;
    mdu_op_t     ex_mdu_op;
    csr_op_t     ex_csr_op;
    logic        ex_csr_zimm;
    logic [11:0] ex_csr_addr;
    logic        ex_is_ecall, ex_is_ebreak, ex_is_mret;
    logic        ex_illegal_instr;
    logic        ex_predicted_taken;
    logic [1:0]  ex_ras_ptr;

    // EX stage (forwarding + ALU + branch + CSR + MDU — all in one stage)
    logic [31:0] ex_fwd_rs1, ex_fwd_rs2;
    logic [31:0] ex_alu_a, ex_alu_b;
    logic [31:0] ex_csr_wdata;
    logic [31:0] ex_alu_result;
    logic        ex_alu_zero;
    logic [31:0] ex_branch_target, ex_jalr_target;
    logic        ex_branch_taken, ex_do_branch;
    logic        ex_mispredict;
    logic [31:0] ex_result;
    logic [31:0] mdu_result;
    logic        mdu_busy, mdu_valid, mdu_start;
    logic [31:0] csr_rdata, mtvec, mepc_out;
    logic        mstatus_mie;
    logic        ex_trap;
    logic [31:0] ex_trap_cause, ex_trap_val;

    // EX/MW outputs (pipe_ex_mem register outputs)
    logic [31:0] mw_pc_plus4, mw_alu_result, mw_rs2_data;
    logic [4:0]  mw_rd_addr;
    logic [2:0]  mw_funct3;
    logic        mw_reg_write, mw_mem_read, mw_mem_write, mw_mem_to_reg;
    logic        mw_jal, mw_jalr;
    logic        mw_is_csr;
    logic [31:0] mw_csr_rdata;

    // MW stage (merged memory + writeback)
    logic [31:0] mw_read_data;
    logic [31:0] mw_rd_data;
    logic mw_retire;
    assign mw_retire = (mw_reg_write && mw_rd_addr != 5'b0) ||
                       mw_mem_write || mw_mem_read ||
                       mw_jal || mw_jalr;

    // IF

    assign if_pc_plus4 = if_pc + 32'd4;

    always_comb begin
        if (ex_trap)
            pc_next = mtvec;
        else if (ex_is_mret)
            pc_next = mepc_out;
        else if (ex_jal)
            pc_next = ex_branch_target;
        else if (ex_jalr)
            pc_next = ex_jalr_target;
        else if (ex_do_branch && !ex_predicted_taken)
            pc_next = ex_branch_target;
        else if (ex_branch && !ex_branch_taken && ex_predicted_taken)
            pc_next = ex_pc_plus4;
        else if (if_predict_valid && if_predict_taken)
            pc_next = if_predict_target;
        else
            pc_next = if_pc_plus4;
    end

    assign ex_mispredict = ex_branch && (ex_branch_taken != ex_predicted_taken);

    btb_type_t bp_update_type;
    always_comb begin
        if (ex_branch)    bp_update_type = BTB_BRANCH;
        else if (ex_jal)  bp_update_type = BTB_JAL;
        else              bp_update_type = BTB_BRANCH;
    end

    branch_predictor u_bp (
        .clk            (clk),
        .rst_n          (rst_n),
        .pc_if          (if_pc),
        .predict_taken  (if_predict_taken),
        .predict_target (if_predict_target),
        .predict_valid  (if_predict_valid),
        .ras_push_en    (id_ras_push && !if_id_flush),
        .ras_push_addr  (id_pc_plus4),
        .update_en      (ex_branch || ex_jal),
        .update_pc      (ex_pc),
        .actual_taken   (ex_branch_taken || ex_jal),
        .actual_target  (ex_branch_target),
        .update_type    (bp_update_type),
        .flush          (ex_mispredict || ex_jal || ex_jalr),
        .flush_ras_ptr  (ex_ras_ptr),
        .ras_ptr_out    (ras_ptr_current)
    );

    pc u_pc (
        .clk      (clk),
        .rst_n    (rst_n),
        .pc_write (!pc_stall),
        .pc_next  (pc_next),
        .pc_out   (if_pc)
    );

    imem u_imem (
        .addr  (icache_mem_addr),
        .instr (imem_raw_instr),
        .data_addr (32'b0),
        .data_out  ()
    );

    icache u_icache (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (if_pc),
        .instr    (if_instr),
        .hit      (icache_hit),
        .mem_addr (icache_mem_addr),
        .mem_data (imem_raw_instr)
    );

    assign debug_pc    = if_pc;
    assign debug_instr = id_instr;

    // IF/ID

    pipe_if_id u_if_id (
        .clk               (clk),
        .rst_n             (rst_n),
        .stall             (if_id_stall),
        .flush             (if_id_flush),
        .pc_in             (if_pc),
        .pc_plus4_in       (if_pc_plus4),
        .instr_in          (if_instr),
        .predict_taken_in  (if_predict_taken && if_predict_valid),
        .pc_out            (id_pc),
        .pc_plus4_out      (id_pc_plus4),
        .instr_out         (id_instr),
        .predict_taken_out (id_predict_taken)
    );

    // ID

    assign id_opcode  = id_instr[6:0];
    assign id_rd      = id_instr[11:7];
    assign id_funct3  = id_instr[14:12];
    assign id_rs1     = id_instr[19:15];
    assign id_rs2     = id_instr[24:20];
    assign id_funct7  = id_instr[31:25];
    assign id_funct12 = id_instr[31:20];

    control u_control (
        .opcode(id_opcode), .funct3(id_funct3), .funct7(id_funct7), .funct12(id_funct12),
        .reg_write(id_reg_write), .mem_read(id_mem_read), .mem_write(id_mem_write),
        .mem_to_reg(id_mem_to_reg), .alu_src(id_alu_src), .branch(id_branch),
        .jal(id_jal), .jalr(id_jalr), .lui(id_lui), .auipc(id_auipc),
        .imm_type(id_imm_type), .alu_op(id_alu_op),
        .is_mext(id_is_mext), .mdu_op(id_mdu_op),
        .csr_op(id_csr_op), .csr_zimm(id_csr_zimm),
        .is_ecall(id_is_ecall), .is_ebreak(id_is_ebreak),
        .is_mret(id_is_mret), .illegal_instr(id_illegal_instr)
    );

    imm_gen u_imm_gen (.instr(id_instr), .imm_type(id_imm_type), .imm(id_imm));

    // Regfile writes from MW stage directly (merged writeback)
    regfile u_regfile (
        .clk(clk), .rst_n(rst_n), .we(mw_reg_write),
        .rs1_addr(id_rs1), .rs2_addr(id_rs2),
        .rd_addr(mw_rd_addr), .rd_data(mw_rd_data),
        .rs1_data(id_rs1_data), .rs2_data(id_rs2_data)
    );

    assign id_is_call = (id_jal || id_jalr) && (id_rd == 5'd1 || id_rd == 5'd5);
    assign id_is_ret  = id_jalr && (id_rs1 == 5'd1 || id_rs1 == 5'd5) && (id_rd != id_rs1);
    assign id_ras_push = id_is_call;

    // ID/EX

    pipe_id_ex u_id_ex (
        .clk(clk), .rst_n(rst_n), .flush(id_ex_flush), .stall(id_ex_stall),
        .reg_write_in(id_reg_write), .mem_read_in(id_mem_read),
        .mem_write_in(id_mem_write), .mem_to_reg_in(id_mem_to_reg),
        .alu_src_in(id_alu_src), .branch_in(id_branch),
        .jal_in(id_jal), .jalr_in(id_jalr), .lui_in(id_lui), .auipc_in(id_auipc),
        .alu_op_in(id_alu_op),
        .pc_in(id_pc), .pc_plus4_in(id_pc_plus4),
        .rs1_data_in(id_rs1_data), .rs2_data_in(id_rs2_data), .imm_in(id_imm),
        .rs1_addr_in(id_rs1), .rs2_addr_in(id_rs2), .rd_addr_in(id_rd),
        .funct3_in(id_funct3), .predict_taken_in(id_predict_taken),
        .is_mext_in(id_is_mext), .mdu_op_in(id_mdu_op),
        .csr_op_in(id_csr_op), .csr_zimm_in(id_csr_zimm), .csr_addr_in(id_funct12),
        .is_ecall_in(id_is_ecall), .is_ebreak_in(id_is_ebreak),
        .is_mret_in(id_is_mret), .illegal_instr_in(id_illegal_instr),
        .ras_ptr_in(ras_ptr_current),
        .reg_write_out(ex_reg_write), .mem_read_out(ex_mem_read),
        .mem_write_out(ex_mem_write), .mem_to_reg_out(ex_mem_to_reg),
        .alu_src_out(ex_alu_src), .branch_out(ex_branch),
        .jal_out(ex_jal), .jalr_out(ex_jalr), .lui_out(ex_lui), .auipc_out(ex_auipc),
        .alu_op_out(ex_alu_op),
        .pc_out(ex_pc), .pc_plus4_out(ex_pc_plus4),
        .rs1_data_out(ex_rs1_data), .rs2_data_out(ex_rs2_data), .imm_out(ex_imm),
        .rs1_addr_out(ex_rs1_addr), .rs2_addr_out(ex_rs2_addr), .rd_addr_out(ex_rd_addr),
        .funct3_out(ex_funct3), .predict_taken_out(ex_predicted_taken),
        .is_mext_out(ex_is_mext), .mdu_op_out(ex_mdu_op),
        .csr_op_out(ex_csr_op), .csr_zimm_out(ex_csr_zimm), .csr_addr_out(ex_csr_addr),
        .is_ecall_out(ex_is_ecall), .is_ebreak_out(ex_is_ebreak),
        .is_mret_out(ex_is_mret), .illegal_instr_out(ex_illegal_instr),
        .ras_ptr_out(ex_ras_ptr)
    );

    // EX: forwarding + ALU + branch + CSR + MDU (merged single stage)

    // MW result for forwarding (combinational, includes dmem read for loads)
    logic [31:0] mw_fwd_result;
    always_comb begin
        if (mw_jal || mw_jalr) mw_fwd_result = mw_pc_plus4;
        else if (mw_mem_to_reg) mw_fwd_result = mw_read_data;
        else if (mw_is_csr)     mw_fwd_result = mw_csr_rdata;
        else                     mw_fwd_result = mw_alu_result;
    end

    forwarding_unit u_forward (
        .ex_rs1_addr  (ex_rs1_addr),
        .ex_rs2_addr  (ex_rs2_addr),
        .mw_rd_addr   (mw_rd_addr),
        .mw_reg_write (mw_reg_write),
        .forward_a    (forward_a),
        .forward_b    (forward_b)
    );

    // Fresh register file reads with MW bypass (handles stale pipe_id_ex values
    // during multi-cycle MDU stalls)
    logic [31:0] ex_rf_rs1, ex_rf_rs2;
    assign ex_rf_rs1 = (ex_rs1_addr == 5'b0) ? 32'b0 :
                       (mw_reg_write && mw_rd_addr == ex_rs1_addr) ? mw_rd_data :
                       u_regfile.regs[ex_rs1_addr];
    assign ex_rf_rs2 = (ex_rs2_addr == 5'b0) ? 32'b0 :
                       (mw_reg_write && mw_rd_addr == ex_rs2_addr) ? mw_rd_data :
                       u_regfile.regs[ex_rs2_addr];

    // Forwarding mux (single source: MW)
    always_comb begin
        case (forward_a)
            2'b01:   ex_fwd_rs1 = mw_fwd_result;
            default: ex_fwd_rs1 = ex_rf_rs1;
        endcase

        case (forward_b)
            2'b01:   ex_fwd_rs2 = mw_fwd_result;
            default: ex_fwd_rs2 = ex_rf_rs2;
        endcase
    end

    // Operand select
    assign ex_alu_a = (ex_auipc) ? ex_pc : ex_fwd_rs1;
    assign ex_alu_b = (ex_alu_src) ? ex_imm : ex_fwd_rs2;
    assign ex_csr_wdata = ex_csr_zimm ? {27'b0, ex_rs1_addr} : ex_fwd_rs1;

    // ALU
    alu u_alu (
        .a(ex_alu_a), .b(ex_alu_b), .op(ex_alu_op),
        .result(ex_alu_result), .zero(ex_alu_zero)
    );

    // MDU
    logic mdu_stall;
    assign mdu_stall = ex_is_mext && !mdu_valid;
    assign mdu_start = ex_is_mext && !mdu_busy && !mdu_valid;

    mdu u_mdu (
        .clk(clk), .rst_n(rst_n), .start(mdu_start), .op(ex_mdu_op),
        .rs1(ex_fwd_rs1), .rs2(ex_fwd_rs2),
        .result(mdu_result), .busy(mdu_busy), .valid(mdu_valid)
    );

    // Traps
    assign ex_trap = ex_illegal_instr || ex_is_ecall || ex_is_ebreak;
    always_comb begin
        if (ex_illegal_instr)  ex_trap_cause = EXC_ILLEGAL_INSTR;
        else if (ex_is_ecall)  ex_trap_cause = EXC_ECALL_M;
        else if (ex_is_ebreak) ex_trap_cause = EXC_BREAKPOINT;
        else                   ex_trap_cause = 32'b0;
    end
    assign ex_trap_val = ex_illegal_instr ? ex_pc : 32'b0;

    // CSR
    csr_unit u_csr (
        .clk(clk), .rst_n(rst_n),
        .addr(ex_csr_addr), .op(ex_trap ? CSR_NONE : ex_csr_op),
        .wdata(ex_csr_wdata), .rdata(csr_rdata),
        .trap_en(ex_trap), .trap_cause(ex_trap_cause),
        .trap_pc(ex_pc), .trap_val(ex_trap_val),
        .mtvec_out(mtvec), .mret_en(ex_is_mret), .mepc_out(mepc_out),
        .mstatus_mie(mstatus_mie),
        .retire_en(mw_retire), .branch_en(ex_branch), .mispredict_en(ex_mispredict)
    );

    // Result mux
    always_comb begin
        if (ex_lui)          ex_result = ex_imm;
        else if (ex_is_mext) ex_result = mdu_result;
        else                 ex_result = ex_alu_result;
    end

    // Branch
    assign ex_branch_target = ex_pc + ex_imm;
    assign ex_jalr_target   = (ex_fwd_rs1 + ex_imm) & ~32'b1;

    branch_unit u_branch (
        .funct3(ex_funct3), .rs1_data(ex_fwd_rs1), .rs2_data(ex_fwd_rs2),
        .taken(ex_branch_taken)
    );

    assign ex_do_branch = ex_branch & ex_branch_taken;
    assign debug_alu_result = ex_alu_result;

    // Hazard detection (2-stage flush on branch, no load-use stall)

    hazard_unit u_hazard (
        .ex_rs1_addr   (ex_rs1_addr),
        .ex_rs2_addr   (ex_rs2_addr),
        .branch_taken  (ex_mispredict),
        .jal_ex        (ex_jal),
        .jalr_ex       (ex_jalr),
        .mdu_busy      (mdu_stall),
        .trap_flush    (ex_trap),
        .mret_flush    (ex_is_mret),
        .pc_stall      (pc_stall),
        .if_id_stall   (if_id_stall),
        .id_ex_stall   (id_ex_stall),
        .if_id_flush   (if_id_flush),
        .id_ex_flush   (id_ex_flush)
    );

    // EX/MW (reuses pipe_ex_mem to carry signals into merged MEM/WB stage)

    logic ex_suppress;
    assign ex_suppress = ex_trap || mdu_stall;

    pipe_ex_mem u_ex_mw (
        .clk(clk), .rst_n(rst_n),
        .reg_write_in  (ex_suppress ? 1'b0 : ex_reg_write),
        .mem_read_in   (ex_suppress ? 1'b0 : ex_mem_read),
        .mem_write_in  (ex_suppress ? 1'b0 : ex_mem_write),
        .mem_to_reg_in (ex_mem_to_reg),
        .jal_in(ex_jal), .jalr_in(ex_jalr),
        .pc_plus4_in(ex_pc_plus4), .alu_result_in(ex_result),
        .rs2_data_in(ex_fwd_rs2), .rd_addr_in(ex_rd_addr), .funct3_in(ex_funct3),
        .is_csr_in(ex_csr_op != CSR_NONE), .csr_rdata_in(csr_rdata),
        .reg_write_out(mw_reg_write), .mem_read_out(mw_mem_read),
        .mem_write_out(mw_mem_write), .mem_to_reg_out(mw_mem_to_reg),
        .jal_out(mw_jal), .jalr_out(mw_jalr),
        .pc_plus4_out(mw_pc_plus4), .alu_result_out(mw_alu_result),
        .rs2_data_out(mw_rs2_data), .rd_addr_out(mw_rd_addr), .funct3_out(mw_funct3),
        .is_csr_out(mw_is_csr), .csr_rdata_out(mw_csr_rdata)
    );

    // MW: merged memory access + writeback

    dmem u_dmem (
        .clk(clk), .mem_read(mw_mem_read), .mem_write(mw_mem_write),
        .funct3(mw_funct3), .addr(mw_alu_result),
        .write_data(mw_rs2_data), .read_data(mw_read_data)
    );

    // Writeback mux (result written to regfile at next posedge)
    always_comb begin
        if (mw_jal || mw_jalr)  mw_rd_data = mw_pc_plus4;
        else if (mw_mem_to_reg) mw_rd_data = mw_read_data;
        else if (mw_is_csr)     mw_rd_data = mw_csr_rdata;
        else                    mw_rd_data = mw_alu_result;
    end

endmodule
