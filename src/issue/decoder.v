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

    parameter lui = 7'd1,
    parameter auipc = 7'd2,
    parameter jal = 7'd3,
    parameter jalr = 7'd4,
    // B type
    parameter beq = 7'd5,
    parameter bne = 7'd6,
    parameter blt = 7'd7,
    parameter bge = 7'd8,
    parameter bltu = 7'd9,
    parameter bgeu = 7'd10,
    // L type
    parameter lb = 7'd11,
    parameter lh = 7'd12,
    parameter lw = 7'd13,
    parameter lbu = 7'd14,
    parameter lhu = 7'd15,
    // S type
    parameter sb = 7'd16,
    parameter sh = 7'd17,
    parameter sw = 7'd18,
    // I type
    parameter addi = 7'd19,
    parameter slti = 7'd20,
    parameter sltiu = 7'd21,
    parameter xori = 7'd22,
    parameter ori = 7'd23,
    parameter andi = 7'd24,
    parameter slli = 7'd25,
    parameter srli = 7'd26,
    parameter srai = 7'd27,
    // R type
    parameter add = 7'd28,
    parameter sub = 7'd29,
    parameter sll = 7'd30,
    parameter slt = 7'd31,
    parameter sltu = 7'd32,
    parameter xorr = 7'd33,
    parameter srl = 7'd34,
    parameter sra = 7'd35,
    parameter orr = 7'd36,
    parameter andr = 7'd37
) (
    input wire[31 : 0] instruction,
    output wire[6 : 0] opcode,
    output wire[5 : 0] rs1, // wire[5] is valid signal
    output wire[5 : 0] rs2, // wire[5] is valid signal
    output wire[5 : 0] rd, // wire[5] is valid signal
    output wire[31 : 0] imm,
    output wire[6 : 0] op_type
);
    assign opcode_part = instruction[6 : 0];
    assign rs1_part = instruction[11 : 7];
    assign rs2_part = instruction[19 : 15];
    assign rd_part = instruction[24 : 20];
    assign opcode = (opcode_part == 7'b0110111) ? lui :
                    (opcode_part == 7'b0010111) ? auipc :
                    (opcode_part == 7'b1101111) ? jal :
                    (opcode_part == 7'b1100111) ? jalr :
                    ;



endmodule