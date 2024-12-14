// module decoder.v

// work inside Instruction Fetcher

// a non-pipelined module that decodes the instruction and sends the decoded information to the dispatcher
// so it work without a clock signal

// receive a 32-bit instruction and decode it, return the decoded information to IF

module Decoder #(
    parameter LSB_WIDTH = 2,
    parameter RS_WIDTH = 2,
    parameter RoB_WIDTH = 3,
    parameter REG_NUM = 32,
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
    input wire [31 : 0] instruction,
    output wire [6 : 0] opcode,
    output wire [4 : 0] rs1,
    output wire [4 : 0] rs2,
    output wire [4 : 0] rd,
    output wire [31 : 0] imm
);
    wire [6 : 0] opcode_part;
    wire [2 : 0] funct3_part;
    wire [6 : 0] funct7_part;

    assign opcode_part = instruction[6 : 0];
    assign funct3_part = instruction[14 : 12];
    assign funct7_part = instruction[31 : 25];
    assign rs1 = instruction[11 : 7];
    assign rs2 = instruction[19 : 15];
    assign rd = instruction[24 : 20];
    assign imm = (opcode_part == 7'b0110111 || opcode_part == 7'b0010111) ? {instruction[31 : 12], 12'b0} :
                (opcode_part == 7'b1101111) ? {{12{instruction[31]}}, instruction[19 : 12], instruction[20], instruction[30 : 21], 1'b0} :
                (opcode_part == 7'b1100111) ? {{21{instruction[31]}}, instruction[30 : 20]} :
                (opcode_part == 7'b1100011) ? {{20{instruction[31]}}, instruction[7], instruction[30 : 25], instruction[11 : 8], 1'b0} :
                (opcode_part == 7'b0000011 || opcode_part == 7'b0100011) ? {{21{instruction[31]}}, instruction[30 : 20]} :
                (opcode_part == 7'b0010011) ? {{21{instruction[31]}}, instruction[30 : 20]} :
                (opcode_part == 7'b0110011) ? {{27'b0}, instruction[24 : 20]} :
                32'b0;
    assign opcode = (opcode_part == 7'b0110111) ? lui :
                    (opcode_part == 7'b0010111) ? auipc :
                    (opcode_part == 7'b1101111) ? jal :
                    (opcode_part == 7'b1100111) ? jalr :
                    // B type
                    (opcode_part == 7'b1100011) ? (
                        (funct3_part == 3'b000) ? beq :
                        (funct3_part == 3'b001) ? bne :
                        (funct3_part == 3'b100) ? blt :
                        (funct3_part == 3'b101) ? bge :
                        (funct3_part == 3'b110) ? bltu :
                        (funct3_part == 3'b111) ? bgeu :
                        0
                    ) :
                    // L type
                    (opcode_part == 7'b0000011) ? (
                        (funct3_part == 3'b000) ? lb :
                        (funct3_part == 3'b001) ? lh :
                        (funct3_part == 3'b010) ? lw :
                        (funct3_part == 3'b100) ? lbu :
                        (funct3_part == 3'b101) ? lhu :
                        0
                    ) :
                    // S type
                    (opcode_part == 7'b0100011) ? (
                        (funct3_part == 3'b000) ? sb :
                        (funct3_part == 3'b001) ? sh :
                        (funct3_part == 3'b010) ? sw :
                        0
                    ) :
                    // I type
                    (opcode_part == 7'b0010011) ? (
                        (funct3_part == 3'b000) ? addi :
                        (funct3_part == 3'b010) ? slti :
                        (funct3_part == 3'b011) ? sltiu :
                        (funct3_part == 3'b100) ? xori :
                        (funct3_part == 3'b110) ? ori :
                        (funct3_part == 3'b111) ? andi :
                        (funct3_part == 3'b001) ? slli :
                        (funct3_part == 3'b101) ? (funct7_part[5 : 0] == 6'b000000) ? srli : srai :
                        0
                    ) :
                    // R type
                    (opcode_part == 7'b0110011) ? (
                        (funct3_part == 3'b000) ? (
                            (funct7_part == 7'b0000000) ? add : sub
                        ) :
                        (funct3_part == 3'b001) ? sll :
                        (funct3_part == 3'b010) ? slt :
                        (funct3_part == 3'b011) ? sltu :
                        (funct3_part == 3'b100) ? xorr :
                        (funct3_part == 3'b101) ? (
                            (funct7_part == 7'b0000000) ? srl : sra
                        ) :
                        (funct3_part == 3'b110) ? orr :
                        (funct3_part == 3'b111) ? andr :
                        0
                    ) : 0;
endmodule