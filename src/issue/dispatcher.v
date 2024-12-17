// module dispatcher.v
// is responsible for distributing instructions to LSB/RS
module Dispatcher #(
    parameter LSB_WIDTH = 2,
    parameter RS_WIDTH = 2,
    parameter RoB_WIDTH = 3,

    parameter NON_DEP = 1 << RoB_WIDTH,

    parameter lui = 7'd1,      // Load Upper Immediate: result = imm << 12
    parameter auipc = 7'd2,    // Add Upper Immediate to PC: result = PC + (imm << 12)
    parameter jal = 7'd3,      // Jump and Link: result = PC + 4 (next instruction address)
    parameter jalr = 7'd4,     // Jump and Link Register: result = (Vj + imm) & ~1
    // B type
    parameter beq = 7'd5,      // Branch if Equal: if (Vj == Vk) PC = PC + imm
    parameter bne = 7'd6,      // Branch if Not Equal: if (Vj != Vk) PC = PC + imm
    parameter blt = 7'd7,      // Branch if Less Than: if (Vj < Vk) PC = PC + imm
    parameter bge = 7'd8,      // Branch if Greater or Equal: if (Vj >= Vk) PC = PC + imm
    parameter bltu = 7'd9,     // Branch if Less Than Unsigned: if (Vj < Vk) PC = PC + imm
    parameter bgeu = 7'd10,    // Branch if Greater or Equal Unsigned: if (Vj >= Vk) PC = PC + imm
    // L type
    parameter lb = 7'd11,      // Load Byte: result = MEM[Vj + imm]
    parameter lh = 7'd12,      // Load Halfword: result = MEM[Vj + imm]
    parameter lw = 7'd13,      // Load Word: result = MEM[Vj + imm]
    parameter lbu = 7'd14,     // Load Byte Unsigned: result = MEM[Vj + imm]
    parameter lhu = 7'd15,     // Load Halfword Unsigned: result = MEM[Vj + imm]
    // S type
    parameter sb = 7'd16,      // Store Byte: MEM[Vj + imm] = Vk
    parameter sh = 7'd17,      // Store Halfword: MEM[Vj + imm] = Vk
    parameter sw = 7'd18,      // Store Word: MEM[Vj + imm] = Vk
    // I type
    parameter addi = 7'd19,    // Add Immediate: result = Vj + imm
    parameter slti = 7'd20,    // Set Less Than Immediate: result = (Vj < imm) ? 1 : 0
    parameter sltiu = 7'd21,   // Set Less Than Immediate Unsigned: result = (Vj < imm) ? 1 : 0
    parameter xori = 7'd22,    // XOR Immediate: result = Vj ^ imm
    parameter ori = 7'd23,     // OR Immediate: result = Vj | imm
    parameter andi = 7'd24,    // AND Immediate: result = Vj & imm
    parameter slli = 7'd25,    // Shift Left Logical Immediate: result = Vj << imm
    parameter srli = 7'd26,    // Shift Right Logical Immediate: result = Vj >> imm
    parameter srai = 7'd27,    // Shift Right Arithmetic Immediate: result = Vj >>> imm
    // R type
    parameter add = 7'd28,     // Add: result = Vj + Vk
    parameter sub = 7'd29,     // Subtract: result = Vj - Vk
    parameter sll = 7'd30,     // Shift Left Logical: result = Vj << Vk
    parameter slt = 7'd31,     // Set Less Than: result = (Vj < Vk) ? 1 : 0
    parameter sltu = 7'd32,    // Set Less Than Unsigned: result = (Vj < Vk) ? 1 : 0
    parameter xorr = 7'd33,    // XOR: result = Vj ^ Vk
    parameter srl = 7'd34,     // Shift Right Logical: result = Vj >> Vk
    parameter sra = 7'd35,     // Shift Right Arithmetic: result = Vj >>> Vk
    parameter orr = 7'd36,     // OR: result = Vj | Vk
    parameter andr = 7'd37     // AND: result = Vj & Vk
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // from IF
    input wire new_instruction_en,
    input wire [31 : 0] new_pc,
    input wire [6 : 0] new_opcode,
    input wire [4 : 0] new_rs1,
    input wire [4 : 0] new_rs2,
    input wire [4 : 0] new_rd,
    input wire [31 : 0] new_imm,
    input wire new_predict_result,

    output wire new_instruction_able,

    // with RS
    output reg RS_newEntry_en,
    output reg [RoB_WIDTH - 1 : 0] RS_robEntry,
    output reg [6 : 0] RS_opcode,
    output reg [31 : 0] RS_Vj,
    output reg [31 : 0] RS_Vk,
    output reg [RoB_WIDTH : 0] RS_Qj,
    output reg [RoB_WIDTH : 0] RS_Qk,
    output reg [31 : 0] RS_imm,
    output reg [31 : 0] RS_pc,
    input wire RS_isFull,

    // with LSB
    output reg LSB_newEntry_en,
    output reg [RoB_WIDTH - 1 : 0] LSB_RoBIndex,
    output reg [6 : 0] LSB_opcode,
    output reg [31 : 0] LSB_Vj,
    output reg [31 : 0] LSB_Vk,
    output reg [RoB_WIDTH : 0] LSB_Qj,
    output reg [RoB_WIDTH : 0] LSB_Qk,
    output reg [31 : 0] LSB_imm,
    output reg [31 : 0] LSB_pc,
    input wire LSB_isFull,

    // with RoB
    input wire RoB_isFull,
    input wire [RoB_WIDTH - 1 : 0] RoB_newEntryIndex,
    input wire RoB_flush_signal,

    output reg RoB_newEntry_en,
    output reg [6 : 0] RoB_opcode,
    output reg [4 : 0] RoB_rd,
    output reg [31 : 0] RoB_pc,
    output reg [31 : 0] RoB_next_pc, // branch jump destination
    output reg RoB_predict_result,

    output reg RoB_already_ready,
    output reg [31 : 0] RoB_ready_data,

    // with RF
    output wire [4 : 0] RF_rs1,
    output wire [4 : 0] RF_rs2,
    input wire [RoB_WIDTH : 0] RF_Qj,
    input wire [RoB_WIDTH : 0] RF_Qk,
    input wire [31 : 0] RF_Vj,
    input wire [31 : 0] RF_Vk,

    output reg RF_newEntry_en,
    output reg [RoB_WIDTH - 1 : 0] RF_newEntry_robIndex,
    output reg [4 : 0] RF_occupied_rd
);

    assign RF_rs1 = (new_opcode == lui || new_opcode == auipc || new_opcode == jal) ? 0 : new_rs1;
    assign RF_rs2 = (new_opcode == lui || new_opcode == auipc || new_opcode == jal || new_opcode == jalr
        || new_opcode == lb || new_opcode == lh || new_opcode == lw || new_opcode == lbu || new_opcode == lhu
        || new_opcode == addi || new_opcode == slti || new_opcode == sltiu || new_opcode == xori || new_opcode == ori
        || new_opcode == andi || new_opcode == slli || new_opcode == srli || new_opcode == srai) ? 0 : new_rs2;

    assign new_instruction_able = (!RoB_isFull) && (!RS_isFull) && (!LSB_isFull);

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            RF_newEntry_en <= 0;
            RS_newEntry_en <= 0;
            LSB_newEntry_en <= 0;
            RoB_newEntry_en <= 0;
            RoB_already_ready <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end if (RoB_flush_signal) begin
            // flush
            RF_newEntry_en <= 0;
            RS_newEntry_en <= 0;
            LSB_newEntry_en <= 0;
            RoB_newEntry_en <= 0;
            RoB_already_ready <= 0;
        end
        else begin
            // run
            RF_newEntry_en <= 0;
            RS_newEntry_en <= 0;
            LSB_newEntry_en <= 0;
            RoB_newEntry_en <= 0;
            RoB_already_ready <= 0;

            if (new_instruction_en) begin
                // issue new instruction
                RF_newEntry_robIndex <= RoB_newEntryIndex;
                RF_occupied_rd <= new_rd;
                case (new_opcode)
                    lui: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RoB
                        RoB_already_ready <= 1;
                        RoB_ready_data <= new_imm;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= lui;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    auipc: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RoB
                        RoB_already_ready <= 1;
                        RoB_ready_data <= new_pc + new_imm;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= auipc;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    jal: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RoB
                        RoB_already_ready <= 1;
                        RoB_ready_data <= new_pc + 4;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= jal;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + new_imm;
                        RoB_predict_result <= 0;
                    end
                    jalr: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RS
                        RS_newEntry_en <= 1;
                        RS_robEntry <= RoB_newEntryIndex;
                        RS_opcode <= jalr;
                        RS_Vj <= RF_Vj;
                        RS_Vk <= 0;
                        RS_Qj <= RF_Qj;
                        RS_Qk <= NON_DEP;
                        RS_imm <= new_imm;
                        RS_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= jalr;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    beq, bne, blt, bge, bltu, bgeu: begin
                        // RF
                        RF_newEntry_en <= 0;

                        // RS
                        RS_newEntry_en <= 1;
                        RS_robEntry <= RoB_newEntryIndex;
                        RS_opcode <= new_opcode;
                        RS_Vj <= RF_Vj;
                        RS_Vk <= RF_Vk;
                        RS_Qj <= RF_Qj;
                        RS_Qk <= RF_Qk;
                        RS_imm <= new_imm;
                        RS_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= new_opcode;
                        RoB_rd <= 0; // reg 0 means NON_DEP
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + new_imm;
                        RoB_predict_result <= new_predict_result;
                    end
                    lb, lh, lw, lbu, lhu: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // LSB
                        LSB_newEntry_en <= 1;
                        LSB_RoBIndex <= RoB_newEntryIndex;
                        LSB_opcode <= new_opcode;
                        LSB_Vj <= RF_Vj;
                        LSB_Vk <= 0;
                        LSB_Qj <= RF_Qj;
                        LSB_Qk <= NON_DEP;
                        LSB_imm <= new_imm;
                        LSB_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= new_opcode;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    sb, sh, sw: begin
                        // RF
                        RF_newEntry_en <= 0;

                        // LSB
                        LSB_newEntry_en <= 1;
                        LSB_RoBIndex <= RoB_newEntryIndex;
                        LSB_opcode <= new_opcode;
                        LSB_Vj <= RF_Vj;
                        LSB_Vk <= RF_Vk;
                        LSB_Qj <= RF_Qj;
                        LSB_Qk <= RF_Qk;
                        LSB_imm <= new_imm;
                        LSB_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= new_opcode;
                        RoB_rd <= 0;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    addi, slti, sltiu, xori, ori, andi, slli, srli, srai: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RS
                        RS_newEntry_en <= 1;
                        RS_robEntry <= RoB_newEntryIndex;
                        RS_opcode <= new_opcode;
                        RS_Vj <= RF_Vj;
                        RS_Vk <= 0;
                        RS_Qj <= RF_Qj;
                        RS_Qk <= NON_DEP;
                        RS_imm <= new_imm;
                        RS_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= new_opcode;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                    add, sub, sll, slt, sltu, xorr, srl, sra, orr, andr: begin
                        // RF
                        RF_newEntry_en <= 1;

                        // RS
                        RS_newEntry_en <= 1;
                        RS_robEntry <= RoB_newEntryIndex;
                        RS_opcode <= new_opcode;
                        RS_Vj <= RF_Vj;
                        RS_Vk <= RF_Vk;
                        RS_Qj <= RF_Qj;
                        RS_Qk <= RF_Qk;
                        RS_imm <= 0;
                        RS_pc <= new_pc;

                        // RoB
                        RoB_already_ready <= 0;
                        RoB_ready_data <= 0;

                        RoB_newEntry_en <= 1;
                        RoB_opcode <= new_opcode;
                        RoB_rd <= new_rd;
                        RoB_pc <= new_pc;
                        RoB_next_pc <= new_pc + 4;
                        RoB_predict_result <= 0;
                    end
                endcase
            end
        end
    end

endmodule