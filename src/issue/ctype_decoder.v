// module ctype_decoder.v
/*
#### 需要实现的边长指令

- c.addi      000 | imm[5]  | rs1/rd != 0   | imm[4:0]      | 01
- c.jal       001 | imm[11|4|9:8|10|6|7|3:1|5]              | 01
- c.li        010 | imm[5]  | rd!=0         | imm[4:0]      | 01
- c.addi16sp  011 | imm[9]  | 2             | imm[4|6|8:7|5]| 01
- c.lui       011 | imm[17] | rd!={0,2}     | imm[16:12]    | 01
- c.srli      100 | uimm[5] | 00 | rs1'/rd' | uimm[4:0]     | 01
- c.srai      100 | uimm[5] | 01 | rs1'/rd' | uimm[4:0]     | 01
- c.andi      100 | imm[5]  | 10 | rs1'/rd' | imm[4:0]      | 01
- c.sub       100 | 0       | 11 | rs1'/rd' | 00 | rs2'     | 01
- c.xor       100 | 0       | 11 | rs1'/rd' | 01 | rs2'     | 01
- c.or        100 | 0       | 11 | rs1'/rd' | 10 | rs2'     | 01
- c.and       100 | 1       | 11 | rs1'/rd' | 11 | rs2'     | 01
- c.j         101 | imm[11|4|9:8|10|6|7|3:1|5]              | 01
- c.beqz      110 | imm[8|4:3]   | rs1'     | imm[7:6|2:1|5]| 01
- c.bnez      111 | imm[8|4:3]   | rs1'     | imm[7:6|2:1|5]| 01
- c.addi4spn  000 | uimm[5:4|9:6|2|3]                  |rd' | 00
- c.lw        010 | uimm[5:3]    | rs1'     | uimm[2|6]|rd' | 00  
- c.sw        110 | uimm[5:3]    | rs1'     | uimm[7:6]|rs2'| 00
- c.slli      000 | uimm[5] | rs1/rd != 0   | uimm[4:0]     | 10
- c.jr        100 | 0       | rs1 != 0      | 0             | 10
- c.mv        100 | 0       | rd != 0       | rs2 != 0      | 10
- c.jalr      100 | 1       | rs1 != 0      | 0             | 10
- c.add       100 | 1       | rs1/rd != 0   | rs2 != 0      | 10
- c.lwsp      010 | uimm[5] | rd != 0       | uimm[4:2|7:6] | 10
- c.swsp      110 | uimm[5:2|7:6]           | rs2           | 10
100 01111100010 01
*/

module CType_Decoder #(
    parameter c_addi = 1,
    parameter c_jal = 2,
    parameter c_li = 3,
    parameter c_addi16sp = 4,
    parameter c_lui = 5,
    parameter c_srli = 6,
    parameter c_srai = 7,
    parameter c_andi = 8,
    parameter c_sub = 9,
    parameter c_xor = 10,
    parameter c_or = 11,
    parameter c_and = 12,
    parameter c_j = 13,
    parameter c_beqz = 14,
    parameter c_bnez = 15,
    parameter c_addi4spn = 16,
    parameter c_lw = 17,
    parameter c_sw = 18,
    parameter c_slli = 19,
    parameter c_jr = 20,
    parameter c_mv = 21,
    parameter c_jalr = 22,
    parameter c_add = 23,
    parameter c_lwsp = 24,
    parameter c_swsp = 25
) (
    input wire [15 : 0] instruction,
    output [4 : 0] opcode_ctype,
    output [31 : 0] uimm,
    output [31 : 0] imm,
    output [4 : 0] rs1,
    output [4 : 0] rs2,
    output [4 : 0] rd
);

wire [2 : 0] funct3_part;
wire [1 : 0] funct2_part;
assign funct3_part = instruction[15 : 13];
assign funct2_part = instruction[1 : 0];


assign opcode_ctype = (funct3_part == 3'b000 && funct2_part == 2'b01 && instruction[11 : 7] != 5'b0) ? c_addi : 
                        (funct3_part == 3'b001 && funct2_part == 2'b01) ? c_jal :
                        (funct3_part == 3'b010 && funct2_part == 2'b01 && instruction[11 : 7] != 5'b0) ? c_li :
                        (funct3_part == 3'b011 && funct2_part == 2'b01 && instruction[11 : 7] == 5'b10) ? c_addi16sp :
                        (funct3_part == 3'b011 && funct2_part == 2'b01 && instruction[11 : 7] != 5'b0 && instruction[11 : 7] != 5'b10) ? c_lui :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[11 : 10] == 2'b00) ? c_srli :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[11 : 10] == 2'b01) ? c_srai :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[11 : 10] == 2'b10) ? c_andi :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[12] == 1'b0 && instruction[11 : 10] == 2'b11 && instruction[6:5] == 2'b00) ? c_sub :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[12] == 1'b0 && instruction[11 : 10] == 2'b11 && instruction[6:5] == 2'b01) ? c_xor :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[12] == 1'b0 && instruction[11 : 10] == 2'b11 && instruction[6:5] == 2'b10) ? c_or :
                        (funct3_part == 3'b100 && funct2_part == 2'b01 && instruction[12] == 1'b1 && instruction[11 : 10] == 2'b11 && instruction[6:5] == 2'b11) ? c_and :
                        (funct3_part == 3'b101 && funct2_part == 2'b01) ? c_j :
                        (funct3_part == 3'b110 && funct2_part == 2'b01) ? c_beqz :
                        (funct3_part == 3'b111 && funct2_part == 2'b01) ? c_bnez :
                        (funct3_part == 3'b000 && funct2_part == 2'b00) ? c_addi4spn :
                        (funct3_part == 3'b010 && funct2_part == 2'b00) ? c_lw :
                        (funct3_part == 3'b110 && funct2_part == 2'b00) ? c_sw :
                        (funct3_part == 3'b000 && funct2_part == 2'b10 && instruction[11 : 7] != 0) ? c_slli :
                        (funct3_part == 3'b100 && funct2_part == 2'b10 && instruction[12] == 1'b0 && instruction[11 : 7] != 0 && instruction[6 : 2] == 5'b0) ? c_jr :
                        (funct3_part == 3'b100 && funct2_part == 2'b10 && instruction[12] == 1'b0 && instruction[11 : 7] != 0 && instruction[6 : 2] != 5'b0) ? c_mv :
                        (funct3_part == 3'b100 && funct2_part == 2'b10 && instruction[12] == 1'b1 && instruction[11 : 7] != 0 && instruction[6 : 2] == 5'b0) ? c_jalr :
                        (funct3_part == 3'b100 && funct2_part == 2'b10 && instruction[12] == 1'b1 && instruction[11 : 7] != 0 && instruction[6 : 2] != 5'b0) ? c_add :
                        (funct3_part == 3'b010 && funct2_part == 2'b10 && instruction[11 : 7] != 0) ? c_lwsp :
                        (funct3_part == 3'b110 && funct2_part == 2'b10) ? c_swsp : 0;

assign uimm = (opcode_ctype == c_srli || opcode_ctype == c_srai) ? {26'b0, instruction[12], instruction[6 : 2]} :
                (opcode_ctype == c_addi4spn) ? {22'b0, instruction[10:7], instruction[12 : 11], instruction[5], instruction[6], 2'b0} :
                (opcode_ctype == c_lw) ? {25'b0, instruction[5], instruction[12 : 10], instruction[6], 2'b0} :
                (opcode_ctype == c_sw) ? {24'b0, instruction[6 : 5], instruction[12 : 10], 3'b0} :
                (opcode_ctype == c_slli) ? {26'b0, instruction[12], instruction[6 : 2]} :
                (opcode_ctype == c_lwsp) ? {26'b0, instruction[3 : 2], instruction[12], instruction[6 : 4], 2'b0} :
                (opcode_ctype == c_swsp) ? {26'b0, instruction[8 : 7], instruction[12 : 9], 2'b0} : 0;

assign imm = (opcode_ctype == c_addi || opcode_ctype == c_li || opcode_ctype == c_andi) ? {{27{instruction[12]}}, instruction[6 : 2]} :
                (opcode_ctype == c_jal || opcode_ctype == c_j) ? {{21{instruction[12]}}, instruction[8], instruction[10:9], instruction[6], instruction[7], instruction[2], instruction[11], instruction[5 : 3], 1'b0} :
                (opcode_ctype == c_addi16sp) ? {{23{instruction[12]}}, instruction[4:3], instruction[5], instruction[2], instruction[6], 4'b0} :
                (opcode_ctype == c_lui) ? {{15{instruction[12]}}, instruction[6 : 2], 12'b0} :
                (opcode_ctype == c_beqz || opcode_ctype == c_bnez) ? {{21{instruction[12]}}, instruction[6 : 5], instruction[2], instruction[11 : 10], instruction[4 : 3], 1'b0} : 0;

assign rs1 = (opcode_ctype == c_addi || opcode_ctype == c_slli || opcode_ctype == c_jr || opcode_ctype == c_jalr || opcode_ctype == c_add) ? instruction[11 : 7] :
                (opcode_ctype == c_srli || opcode_ctype == c_srai || opcode_ctype == c_andi || opcode_ctype == c_sub 
                || opcode_ctype == c_xor || opcode_ctype == c_or || opcode_ctype == c_and || opcode_ctype == c_beqz
                || opcode_ctype == c_bnez || opcode_ctype == c_lw || opcode_ctype == c_sw) ? {2'b1, instruction[9 : 7]} : 0;

assign rs2 = (opcode_ctype == c_mv || opcode_ctype == c_add || opcode_ctype == c_swsp) ? instruction[6 : 2] :
                (opcode_ctype == c_sub || opcode_ctype == c_xor || opcode_ctype == c_or || opcode_ctype == c_and || opcode_ctype == c_sw) ? {2'b1, instruction[4 : 2]} : 0;

assign rd = (opcode_ctype == c_addi || opcode_ctype == c_li || opcode_ctype == c_lui || opcode_ctype == c_slli || opcode_ctype == c_mv || opcode_ctype == c_add || opcode_ctype == c_lwsp) ? instruction[11 : 7] :
                (opcode_ctype == c_srli || opcode_ctype == c_srai || opcode_ctype == c_andi || opcode_ctype == c_sub 
                || opcode_ctype == c_xor || opcode_ctype == c_or || opcode_ctype == c_and) ? {2'b1, instruction[9 : 7]} :
                (opcode_ctype == c_addi4spn || opcode_ctype == c_lw) ? {2'b1, instruction[4 : 2]} : 0;
endmodule