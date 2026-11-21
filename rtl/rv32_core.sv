// SPDX-License-Identifier: MIT
// OpenRV32 single-cycle RV32I-subset core, Harvard instruction/data ports.
// Simulation-oriented: no architectural traps, interrupts, CSRs, or bus stalls.
// halt_reason_o: 0=running, 1=EBREAK, 2=ECALL, 3=illegal,
//                4=misaligned load/store, 5=misaligned next PC.
module rv32_core (
    input  logic        clk_i,
    input  logic        rst_ni,
    output logic [31:0] instr_addr_o,
    input  logic [31:0] instr_rdata_i,
    output logic        data_valid_o,
    output logic        data_we_o,
    output logic [3:0]  data_wstrb_o,
    output logic [31:0] data_addr_o,
    output logic [31:0] data_wdata_o,
    input  logic [31:0] data_rdata_i,
    output logic        halted_o,
    output logic [2:0]  halt_reason_o
);
    logic [31:0] regs [0:31];
    logic [31:0] pc_q, pc_d;
    logic [31:0] rs1_val, rs2_val, wb_data;
    logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    logic [31:0] ea, shifted_read;
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    logic [4:0] rs1, rs2, rd;
    logic reg_write, illegal_instr, halt_instr, take_branch, misaligned_data;
    logic [2:0] halt_reason_d;
    logic [1:0] lane;
    integer i;

    assign instr_addr_o = pc_q;
    assign opcode = instr_rdata_i[6:0];
    assign rd     = instr_rdata_i[11:7];
    assign funct3 = instr_rdata_i[14:12];
    assign rs1    = instr_rdata_i[19:15];
    assign rs2    = instr_rdata_i[24:20];
    assign funct7 = instr_rdata_i[31:25];

    assign rs1_val = (rs1 == 0) ? 32'b0 : regs[rs1];
    assign rs2_val = (rs2 == 0) ? 32'b0 : regs[rs2];
    assign imm_i = {{20{instr_rdata_i[31]}}, instr_rdata_i[31:20]};
    assign imm_s = {{20{instr_rdata_i[31]}}, instr_rdata_i[31:25], instr_rdata_i[11:7]};
    assign imm_b = {{19{instr_rdata_i[31]}}, instr_rdata_i[31], instr_rdata_i[7],
                    instr_rdata_i[30:25], instr_rdata_i[11:8], 1'b0};
    assign imm_u = {instr_rdata_i[31:12], 12'b0};
    assign imm_j = {{11{instr_rdata_i[31]}}, instr_rdata_i[31], instr_rdata_i[19:12],
                    instr_rdata_i[20], instr_rdata_i[30:21], 1'b0};

    always_comb begin
        pc_d         = pc_q + 32'd4;
        wb_data      = 32'b0;
        reg_write    = 1'b0;
        illegal_instr = 1'b0;
        halt_instr   = 1'b0;
        misaligned_data = 1'b0;
        halt_reason_d = 3'd0;
        take_branch  = 1'b0;
        ea           = 32'b0;
        lane         = 2'b0;
        shifted_read = 32'b0;
        data_valid_o = 1'b0;
        data_we_o    = 1'b0;
        data_wstrb_o = 4'b0000;
        data_addr_o  = 32'b0;
        data_wdata_o = 32'b0;

        case (opcode)
            7'b0110111: begin // LUI
                reg_write = 1'b1;
                wb_data = imm_u;
            end
            7'b0010111: begin // AUIPC
                reg_write = 1'b1;
                wb_data = pc_q + imm_u;
            end
            7'b1101111: begin // JAL
                reg_write = 1'b1;
                wb_data = pc_q + 32'd4;
                pc_d = pc_q + imm_j;
            end
            7'b1100111: begin // JALR
                if (funct3 == 3'b000) begin
                    reg_write = 1'b1;
                    wb_data = pc_q + 32'd4;
                    pc_d = (rs1_val + imm_i) & 32'hffff_fffe;
                end else illegal_instr = 1'b1;
            end
            7'b1100011: begin // Conditional branches
                case (funct3)
                    3'b000: take_branch = (rs1_val == rs2_val);               // BEQ
                    3'b001: take_branch = (rs1_val != rs2_val);               // BNE
                    3'b100: take_branch = ($signed(rs1_val) < $signed(rs2_val)); // BLT
                    3'b101: take_branch = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
                    3'b110: take_branch = (rs1_val < rs2_val);                // BLTU
                    3'b111: take_branch = (rs1_val >= rs2_val);               // BGEU
                    default: illegal_instr = 1'b1;
                endcase
                if (take_branch) pc_d = pc_q + imm_b;
            end
            7'b0000011: begin // Loads
                ea = rs1_val + imm_i;
                lane = ea[1:0];
                data_addr_o = ea;
                data_valid_o = 1'b1;
                reg_write = 1'b1;
                shifted_read = data_rdata_i >> (8 * lane);
                case (funct3)
                    3'b000: wb_data = {{24{shifted_read[7]}}, shifted_read[7:0]}; // LB
                    3'b001: begin // LH
                        if (lane[0]) misaligned_data = 1'b1;
                        wb_data = {{16{shifted_read[15]}}, shifted_read[15:0]};
                    end
                    3'b010: begin // LW
                        if (lane != 0) misaligned_data = 1'b1;
                        wb_data = shifted_read;
                    end
                    3'b100: wb_data = {24'b0, shifted_read[7:0]}; // LBU
                    3'b101: begin // LHU
                        if (lane[0]) misaligned_data = 1'b1;
                        wb_data = {16'b0, shifted_read[15:0]};
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end
            7'b0100011: begin // Stores
                ea = rs1_val + imm_s;
                lane = ea[1:0];
                data_addr_o = ea;
                data_valid_o = 1'b1;
                data_we_o = 1'b1;
                data_wdata_o = rs2_val << (8 * lane);
                case (funct3)
                    3'b000: data_wstrb_o = 4'b0001 << lane; // SB
                    3'b001: begin // SH
                        if (lane[0]) misaligned_data = 1'b1;
                        data_wstrb_o = 4'b0011 << lane;
                    end
                    3'b010: begin // SW
                        if (lane != 0) misaligned_data = 1'b1;
                        data_wstrb_o = 4'b1111;
                    end
                    default: illegal_instr = 1'b1;
                endcase
            end
            7'b0010011: begin // Integer register-immediate
                reg_write = 1'b1;
                case (funct3)
                    3'b000: wb_data = rs1_val + imm_i; // ADDI
                    3'b010: wb_data = {31'b0, ($signed(rs1_val) < $signed(imm_i))}; // SLTI
                    3'b011: wb_data = {31'b0, (rs1_val < imm_i)}; // SLTIU
                    3'b100: wb_data = rs1_val ^ imm_i; // XORI
                    3'b110: wb_data = rs1_val | imm_i; // ORI
                    3'b111: wb_data = rs1_val & imm_i; // ANDI
                    3'b001: begin // SLLI
                        if (funct7 != 7'b0000000) illegal_instr = 1'b1;
                        wb_data = rs1_val << rs2;
                    end
                    3'b101: begin
                        if (funct7 == 7'b0000000) wb_data = rs1_val >> rs2; // SRLI
                        else if (funct7 == 7'b0100000) wb_data = $signed(rs1_val) >>> rs2; // SRAI
                        else illegal_instr = 1'b1;
                    end
                endcase
            end
            7'b0110011: begin // Integer register-register
                reg_write = 1'b1;
                case ({funct7, funct3})
                    10'b0000000_000: wb_data = rs1_val + rs2_val; // ADD
                    10'b0100000_000: wb_data = rs1_val - rs2_val; // SUB
                    10'b0000000_001: wb_data = rs1_val << rs2_val[4:0]; // SLL
                    10'b0000000_010: wb_data = {31'b0, ($signed(rs1_val) < $signed(rs2_val))}; // SLT
                    10'b0000000_011: wb_data = {31'b0, (rs1_val < rs2_val)}; // SLTU
                    10'b0000000_100: wb_data = rs1_val ^ rs2_val; // XOR
                    10'b0000000_101: wb_data = rs1_val >> rs2_val[4:0]; // SRL
                    10'b0100000_101: wb_data = $signed(rs1_val) >>> rs2_val[4:0]; // SRA
                    10'b0000000_110: wb_data = rs1_val | rs2_val; // OR
                    10'b0000000_111: wb_data = rs1_val & rs2_val; // AND
                    default: illegal_instr = 1'b1;
                endcase
            end
            7'b0001111: begin // FENCE: no-op in this simple, in-order memory model.
                if (funct3 != 3'b000) illegal_instr = 1'b1;
            end
            7'b1110011: begin // ECALL/EBREAK: halt for testbench; no architectural trap.
                if (instr_rdata_i == 32'h00000073) begin
                    halt_instr = 1'b1;
                    halt_reason_d = 3'd2; // ECALL
                end else if (instr_rdata_i == 32'h00100073) begin
                    halt_instr = 1'b1;
                    halt_reason_d = 3'd1; // EBREAK
                end else illegal_instr = 1'b1;
            end
            default: illegal_instr = 1'b1;
        endcase

        if (illegal_instr) halt_reason_d = 3'd3;
        else if (misaligned_data) halt_reason_d = 3'd4;
        else if (pc_d[1:0] != 2'b00) halt_reason_d = 3'd5;

        // Prevent an instruction that halts from committing side effects.
        if (halt_reason_d != 3'd0 || halted_o) begin
            reg_write = 1'b0;
            data_valid_o = 1'b0;
            data_we_o = 1'b0;
            data_wstrb_o = 4'b0;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            pc_q <= 32'b0;
            halted_o <= 1'b0;
            halt_reason_o <= 3'd0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
        end else if (!halted_o) begin
            if (halt_reason_d != 3'd0) begin
                halted_o <= 1'b1;
                halt_reason_o <= halt_reason_d;
            end else begin
                pc_q <= pc_d;
                if (reg_write && (rd != 0)) regs[rd] <= wb_data;
            end
        end
    end
endmodule
