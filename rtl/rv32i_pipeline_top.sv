import pkg_riscv::*;

module rv32i_pipeline_top (
  input logic clk,
  input logic rst_n,
  output logic [31:0] debug_pc,
  output logic [31:0] debug_instr,
  output logic [31:0] debug_alu_result
);

    //
    // wires
    //

    // --- Hazard / Forwarding control ---
    logic        pc_stall, if_id_stall, if_id_flush, id_ex_flush;
    logic [1:0]  forward_a, forward_b;

    // --- IF stage ---
    logic [31:0] if_pc, if_pc_plus4, if_instr;
    logic [31:0] pc_next;
    logic        if_predict_taken;
    logic        icache_hit;
    logic [31:0] imem_raw_instr, icache_mem_addr;

    // --- IF/ID register outputs ---
    logic [31:0] id_pc, id_pc_plus4, id_instr;

    // --- ID stage (decode) ---
    logic [6:0]  id_opcode;
    logic [4:0]  id_rd, id_rs1, id_rs2;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [31:0] id_rs1_data, id_rs2_data, id_imm;
    logic        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    logic        id_alu_src, id_branch, id_jal, id_jalr, id_lui, id_auipc;
    imm_type_t   id_imm_type;
    alu_op_t     id_alu_op;

    // --- Branch prediction pipeline ---
    logic        id_predict_taken;  // prediction latched through IF/ID
    logic        ex_predicted_taken; // prediction in EX stage for misprediction check
    logic        ex_mispredict;      // true when prediction was wrong

    // --- ID/EX register outputs ---
    logic [31:0] ex_pc, ex_pc_plus4, ex_rs1_data, ex_rs2_data, ex_imm;
    logic [4:0]  ex_rs1_addr, ex_rs2_addr, ex_rd_addr;
    logic [2:0]  ex_funct3;
    logic        ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    logic        ex_alu_src, ex_branch, ex_jal, ex_jalr, ex_lui, ex_auipc;
    alu_op_t     ex_alu_op;

    // --- EX stage ---
    logic [31:0] ex_alu_a, ex_alu_b, ex_alu_result;
    logic        ex_alu_zero;
    logic [31:0] ex_fwd_rs1, ex_fwd_rs2;  // forwarded values
    logic [31:0] ex_branch_target, ex_jalr_target;
    logic        ex_branch_taken, ex_do_branch;

    // --- EX/MEM register outputs ---
    logic [31:0] mem_pc_plus4, mem_alu_result, mem_rs2_data;
    logic [4:0]  mem_rd_addr;
    logic [2:0]  mem_funct3;
    logic        mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    logic        mem_jal, mem_jalr;

    // --- MEM stage ---
    logic [31:0] mem_read_data;

    // --- MEM/WB register outputs ---
    logic [31:0] wb_pc_plus4, wb_alu_result, wb_mem_read_data;
    logic [4:0]  wb_rd_addr;
    logic        wb_reg_write, wb_mem_to_reg;
    logic        wb_jal, wb_jalr;

    // --- WB stage ---
    logic [31:0] wb_rd_data;

    //
    // IF
    //

    assign if_pc_plus4 = if_pc + 32'd4;

    // PC next mux: EX-stage corrections override IF-stage predictions
    always_comb begin
        if (ex_jal)
            pc_next = ex_branch_target;     // JAL target (PC + imm)
        else if (ex_jalr)
            pc_next = ex_jalr_target;       // JALR target (rs1 + imm)
        else if (ex_do_branch)
            pc_next = ex_branch_target;     // Branch taken (mispredicted not-taken)
        else if (ex_branch && !ex_branch_taken && ex_predicted_taken)
            pc_next = ex_pc_plus4;          // Branch not taken (mispredicted taken)
        else
            pc_next = if_pc_plus4;          // Sequential: PC + 4
    end

    // Branch Predictor (predicts in IF stage)
    branch_predictor u_bht (
        .clk           (clk),
        .rst_n         (rst_n),
        .pc_if         (if_pc),
        .predict_taken (if_predict_taken),
        .update_en     (ex_branch),
        .update_pc     (ex_pc),
        .actual_taken  (ex_branch_taken)
    );

    // Program Counter
    pc u_pc (
        .clk      (clk),
        .rst_n    (rst_n),
        .pc_write (!pc_stall),
        .pc_next  (pc_next),
        .pc_out   (if_pc)
    );

    // Instruction Memory (backing store)
    imem u_imem (
        .addr  (icache_mem_addr),
        .instr (imem_raw_instr),
        .data_addr (32'b0),
        .data_out  ()
    );

    // L1 Instruction Cache
    icache u_icache (
        .clk      (clk),
        .rst_n    (rst_n),
        .addr     (if_pc),
        .instr    (if_instr),
        .hit      (icache_hit),
        .mem_addr (icache_mem_addr),
        .mem_data (imem_raw_instr)
    );

    // Debug outputs
    assign debug_pc    = if_pc;
    assign debug_instr = id_instr;

    //
    // IF/ID
    //

    pipe_if_id u_if_id (
        .clk               (clk),
        .rst_n             (rst_n),
        .stall             (if_id_stall),
        .flush             (if_id_flush),
        .pc_in             (if_pc),
        .pc_plus4_in       (if_pc_plus4),
        .instr_in          (if_instr),
        .predict_taken_in  (if_predict_taken),
        .pc_out            (id_pc),
        .pc_plus4_out      (id_pc_plus4),
        .instr_out         (id_instr),
        .predict_taken_out (id_predict_taken)
    );

    //
    // ID
    //

    // Instruction field extraction
    assign id_opcode = id_instr[6:0];
    assign id_rd     = id_instr[11:7];
    assign id_funct3 = id_instr[14:12];
    assign id_rs1    = id_instr[19:15];
    assign id_rs2    = id_instr[24:20];
    assign id_funct7 = id_instr[31:25];

    // Control Unit
    control u_control (
        .opcode    (id_opcode),
        .funct3    (id_funct3),
        .funct7    (id_funct7),
        .reg_write (id_reg_write),
        .mem_read  (id_mem_read),
        .mem_write (id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_src   (id_alu_src),
        .branch    (id_branch),
        .jal       (id_jal),
        .jalr      (id_jalr),
        .lui       (id_lui),
        .auipc     (id_auipc),
        .imm_type  (id_imm_type),
        .alu_op    (id_alu_op)
    );

    // Immediate Generator
    imm_gen u_imm_gen (
        .instr    (id_instr),
        .imm_type (id_imm_type),
        .imm      (id_imm)
    );

    // Register File (read in ID, write in WB)
    regfile u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .we       (wb_reg_write),
        .rs1_addr (id_rs1),
        .rs2_addr (id_rs2),
        .rd_addr  (wb_rd_addr),
        .rd_data  (wb_rd_data),
        .rs1_data (id_rs1_data),
        .rs2_data (id_rs2_data)
    );

    //
    // ID/EX
    //

    pipe_id_ex u_id_ex (
        .clk           (clk),
        .rst_n         (rst_n),
        .flush         (id_ex_flush),
        .reg_write_in  (id_reg_write),
        .mem_read_in   (id_mem_read),
        .mem_write_in  (id_mem_write),
        .mem_to_reg_in (id_mem_to_reg),
        .alu_src_in    (id_alu_src),
        .branch_in     (id_branch),
        .jal_in        (id_jal),
        .jalr_in       (id_jalr),
        .lui_in        (id_lui),
        .auipc_in      (id_auipc),
        .alu_op_in     (id_alu_op),
        .pc_in         (id_pc),
        .pc_plus4_in   (id_pc_plus4),
        .rs1_data_in   (id_rs1_data),
        .rs2_data_in   (id_rs2_data),
        .imm_in        (id_imm),
        .rs1_addr_in   (id_rs1),
        .rs2_addr_in   (id_rs2),
        .rd_addr_in    (id_rd),
        .funct3_in          (id_funct3),
        .predict_taken_in   (id_predict_taken),
        .reg_write_out (ex_reg_write),
        .mem_read_out  (ex_mem_read),
        .mem_write_out (ex_mem_write),
        .mem_to_reg_out(ex_mem_to_reg),
        .alu_src_out   (ex_alu_src),
        .branch_out    (ex_branch),
        .jal_out       (ex_jal),
        .jalr_out      (ex_jalr),
        .lui_out       (ex_lui),
        .auipc_out     (ex_auipc),
        .alu_op_out    (ex_alu_op),
        .pc_out        (ex_pc),
        .pc_plus4_out  (ex_pc_plus4),
        .rs1_data_out  (ex_rs1_data),
        .rs2_data_out  (ex_rs2_data),
        .imm_out       (ex_imm),
        .rs1_addr_out  (ex_rs1_addr),
        .rs2_addr_out  (ex_rs2_addr),
        .rd_addr_out   (ex_rd_addr),
        .funct3_out         (ex_funct3),
        .predict_taken_out  (ex_predicted_taken)
    );

    //
    // EX
    //

    // Forwarding muxes for rs1 and rs2
    always_comb begin
        case (forward_a)
            2'b01:   ex_fwd_rs1 = mem_alu_result;   // from EX/MEM
            2'b10:   ex_fwd_rs1 = wb_rd_data;       // from MEM/WB
            default: ex_fwd_rs1 = ex_rs1_data;      // no forward
        endcase

        case (forward_b)
            2'b01:   ex_fwd_rs2 = mem_alu_result;   // from EX/MEM
            2'b10:   ex_fwd_rs2 = wb_rd_data;       // from MEM/WB
            default: ex_fwd_rs2 = ex_rs2_data;      // no forward
        endcase
    end

    // ALU input muxes
    assign ex_alu_a = (ex_auipc) ? ex_pc : ex_fwd_rs1;
    assign ex_alu_b = (ex_alu_src) ? ex_imm : ex_fwd_rs2;

    // ALU
    alu u_alu (
        .a      (ex_alu_a),
        .b      (ex_alu_b),
        .op     (ex_alu_op),
        .result (ex_alu_result),
        .zero   (ex_alu_zero)
    );

    // Branch target and JALR target
    assign ex_branch_target = ex_pc + ex_imm;
    assign ex_jalr_target   = (ex_fwd_rs1 + ex_imm) & ~32'b1;

    // Branch Unit
    branch_unit u_branch (
        .funct3   (ex_funct3),
        .rs1_data (ex_fwd_rs1),
        .rs2_data (ex_fwd_rs2),
        .taken    (ex_branch_taken)
    );

    assign ex_do_branch = ex_branch & ex_branch_taken;

    // Misprediction: predicted taken but actually not, or predicted not-taken but actually taken
    assign ex_mispredict = ex_branch && (ex_branch_taken != ex_predicted_taken);

    // Debug
    assign debug_alu_result = ex_alu_result;

    //
    // forwarding
    //

    forwarding_unit u_forward (
        .ex_rs1_addr  (ex_rs1_addr),
        .ex_rs2_addr  (ex_rs2_addr),
        .mem_rd_addr  (mem_rd_addr),
        .mem_reg_write(mem_reg_write),
        .wb_rd_addr   (wb_rd_addr),
        .wb_reg_write (wb_reg_write),
        .forward_a    (forward_a),
        .forward_b    (forward_b)
    );

    //
    // hazard detection
    //

    hazard_unit u_hazard (
        .ex_mem_read   (ex_mem_read),
        .ex_rd_addr    (ex_rd_addr),
        .id_rs1_addr   (id_rs1),
        .id_rs2_addr   (id_rs2),
        .branch_taken  (ex_mispredict),  // flush only on misprediction, not every taken branch
        .jal_ex        (ex_jal),
        .jalr_ex       (ex_jalr),
        .pc_stall      (pc_stall),
        .if_id_stall   (if_id_stall),
        .if_id_flush   (if_id_flush),
        .id_ex_flush   (id_ex_flush)
    );

    //
    // EX/MEM
    //

    pipe_ex_mem u_ex_mem (
        .clk            (clk),
        .rst_n          (rst_n),
        .reg_write_in   (ex_reg_write),
        .mem_read_in    (ex_mem_read),
        .mem_write_in   (ex_mem_write),
        .mem_to_reg_in  (ex_mem_to_reg),
        .jal_in         (ex_jal),
        .jalr_in        (ex_jalr),
        .pc_plus4_in    (ex_pc_plus4),
        .alu_result_in  (ex_lui ? ex_imm : ex_alu_result),
        .rs2_data_in    (ex_fwd_rs2),
        .rd_addr_in     (ex_rd_addr),
        .funct3_in      (ex_funct3),
        .reg_write_out  (mem_reg_write),
        .mem_read_out   (mem_mem_read),
        .mem_write_out  (mem_mem_write),
        .mem_to_reg_out (mem_mem_to_reg),
        .jal_out        (mem_jal),
        .jalr_out       (mem_jalr),
        .pc_plus4_out   (mem_pc_plus4),
        .alu_result_out (mem_alu_result),
        .rs2_data_out   (mem_rs2_data),
        .rd_addr_out    (mem_rd_addr),
        .funct3_out     (mem_funct3)
    );

    //
    // MEM
    //

    dmem u_dmem (
        .clk        (clk),
        .mem_read   (mem_mem_read),
        .mem_write  (mem_mem_write),
        .funct3     (mem_funct3),
        .addr       (mem_alu_result),
        .write_data (mem_rs2_data),
        .read_data  (mem_read_data)
    );

    //
    // MEM/WB
    //

    pipe_mem_wb u_mem_wb (
        .clk               (clk),
        .rst_n             (rst_n),
        .reg_write_in      (mem_reg_write),
        .mem_to_reg_in     (mem_mem_to_reg),
        .jal_in            (mem_jal),
        .jalr_in           (mem_jalr),
        .pc_plus4_in       (mem_pc_plus4),
        .alu_result_in     (mem_alu_result),
        .mem_read_data_in  (mem_read_data),
        .rd_addr_in        (mem_rd_addr),
        .reg_write_out     (wb_reg_write),
        .mem_to_reg_out    (wb_mem_to_reg),
        .jal_out           (wb_jal),
        .jalr_out          (wb_jalr),
        .pc_plus4_out      (wb_pc_plus4),
        .alu_result_out    (wb_alu_result),
        .mem_read_data_out (wb_mem_read_data),
        .rd_addr_out       (wb_rd_addr)
    );

    //
    // WB
    //

    always_comb begin
        if (wb_jal || wb_jalr)
            wb_rd_data = wb_pc_plus4;           // JAL/JALR: return address
        else if (wb_mem_to_reg)
            wb_rd_data = wb_mem_read_data;      // Load: data from memory
        else
            wb_rd_data = wb_alu_result;          // ALU result (includes LUI)
    end

endmodule
