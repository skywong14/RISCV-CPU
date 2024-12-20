// module instruction_fetcher.v

// use module_Decoder to decode the instruction
// interface with Branch_Predictor to get the next PC
// interface with ICache to get the instruction at PC
// interface with Dispatcher to send the instruction to Dispatcher
// FLUSH: when predict goes wrong

module Instruction_Fetcher #(
    parameter RoB_WIDTH = 3,
    parameter RoB_SIZE = 1 << RoB_WIDTH,

    parameter IDLE = 0,
    parameter WAITING_ICACHE = 1,
    parameter WAITING_JALR = 2,
    parameter ISSUING = 3,

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
    parameter andr = 7'd37,     // AND: result = Vj & Vk

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
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with ICache
    output reg icache_query_en,
    output reg [31 : 0] icache_query_pc,
    input wire icache_data_en,
    // input wire [31 : 0] icache_addr_comfirm,
    input wire [31 : 0] icache_data,

    // with RoB
    input wire rob_isFull,
    input wire [RoB_WIDTH - 1 : 0] new_entry_index, // an empty RoB entry, but it will be issued by Dispatcher rather than IF

    input wire jalr_result_en, // ATTENTION: special case for jalr feedback, at this time state == WAITING_JALR
    input wire [31 : 0] jalr_result, // next pc
    input wire flush_signal, // FLUSH signal from RoB
    input wire [31 : 0] correct_next_pc, // the correct next pc

    // with Dispatcher
    input wire new_instruction_able, // able to issue new instruction, then IF will be launched

    output reg new_instruction_en,
    output reg [31 : 0] new_pc,
    output reg [6 : 0] new_opcode,
    output reg [4 : 0] new_rs1,
    output reg [4 : 0] new_rs2,
    output reg [4 : 0] new_rd,
    output reg [31 : 0] new_imm,
    output reg new_predict_result,

    output reg [2 : 0] new_ins_width, // 2 or 4

    // with Branch_Predictor
    output reg branch_predictor_query_en,
    output reg [31 : 0] predict_query_pc,
    input wire predict_result // 0: not jump, 1: jump
);
    reg [1 : 0] state;

    reg [31 : 0] pc;
    reg [31 : 0] cur_instruction;

    wire [6 : 0] opcode;
    wire [4 : 0] rs1;
    wire [4 : 0] rs2;
    wire [4 : 0] rd;
    wire [31 : 0] imm;
    wire cur_predict_result;

    wire [4 : 0] opcode_ctype; // 0 ~ 25
    wire [31 : 0] c_uimm;
    wire [31 : 0] c_imm;
    wire [4 : 0] c_rs1;
    wire [4 : 0] c_rs2;
    wire [4 : 0] c_rd;
    CType_Decoder module_CType_Decoder (
        .instruction(cur_instruction[15 : 0]),
        .opcode_ctype(opcode_ctype),
        .uimm(c_uimm),
        .imm(c_imm),
        .rs1(c_rs1),
        .rs2(c_rs2),
        .rd(c_rd)
    );
    Decoder module_Decoder (
        .instruction(cur_instruction),
        .opcode(opcode),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm)
    );

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            pc <= 0;
            cur_instruction <= 0;
            icache_query_en <= 0;
            new_instruction_en <= 0;

            icache_query_pc <= 0;
            new_pc <= 0;
            new_opcode <= 0;
            new_rs1 <= 0;
            new_rs2 <= 0;
            new_rd <= 0;
            new_imm <= 0;
            new_predict_result <= 0;
            branch_predictor_query_en <= 0;
            new_ins_width <= 4;
        end
        else if (!rdy_in) begin
            // pause
        end if (flush_signal) begin
            // flush
            state <= IDLE;
            pc <= correct_next_pc;
            cur_instruction <= 0;
            icache_query_en <= 0;
            new_instruction_en <= 0;
        end
        else begin
            // run
            if (state == WAITING_JALR) begin
                // waiting for jalr result
                new_instruction_en <= 0;
                if (jalr_result_en) begin
                    pc <= jalr_result;
                    state <= IDLE;
                end
            end
            else if (state == WAITING_ICACHE) begin
                // waiting
                new_instruction_en <= 0;
                if (icache_data_en) begin
                    cur_instruction <= icache_data;
                    state <= ISSUING;
                    icache_query_en <= 0;
                end
            end
            else if (state == IDLE) begin
                // pc is ready
                // try to fetch the instruction at pc (ask ICache)
                new_instruction_en <= 0;
                icache_query_en <= 1;
                icache_query_pc <= pc;
                state <= WAITING_ICACHE;

                predict_query_pc <= pc;
            end
            else if (state == ISSUING && new_instruction_able) begin
                // pc and instruction are ready
                // use module_Decoder to decode the instruction
                if (opcode_ctype != 0) begin
                    // ctype instruction
                    case (opcode_ctype)
                        c_addi: begin
                            new_opcode <= addi;
                            new_imm <= c_imm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_jal: begin
                            new_opcode <= jal;
                            new_imm <= c_imm;
                            new_rs1 <= 0;
                            new_rs2 <= 0;
                            new_rd <= 1; // x1, ra
                            pc <= pc + c_imm;
                        end
                        c_li: begin
                            new_opcode <= addi;
                            new_imm <= c_imm;
                            new_rs1 <= 0;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_addi16sp: begin
                            new_opcode <= addi;
                            new_imm <= c_imm;
                            new_rs1 <= 2; // x2, sp
                            new_rs2 <= 0;
                            new_rd <= 2; // x2, sp
                            pc <= pc + 2;
                        end
                        c_lui: begin
                            new_opcode <= lui;
                            new_imm <= c_imm;
                            new_rs1 <= 0;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_srli, c_srai: begin
                            new_opcode <= (opcode_ctype == c_srli) ? srli : srai;
                            new_imm <= c_uimm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_andi: begin
                            new_opcode <= andi;
                            new_imm <= c_imm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_sub, c_xor, c_or, c_and: begin
                            new_opcode <= (opcode_ctype == c_sub) ? sub : 
                                          (opcode_ctype == c_xor) ? xorr : 
                                          (opcode_ctype == c_or) ? orr : 
                                          (opcode_ctype == c_and) ? andr : 0;
                            new_imm <= 0;
                            new_rs1 <= c_rs1;
                            new_rs2 <= c_rs2;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_j: begin
                            new_opcode <= jal;
                            new_imm <= c_imm;
                            new_rs1 <= 0;
                            new_rs2 <= 0;
                            new_rd <= 0;
                            pc <= pc + c_imm;
                        end
                        c_beqz: begin
                            new_opcode <= beq;
                            new_imm <= c_imm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= 0;
                            pc <= (predict_result) ? pc + c_imm : pc + 2;
                        end
                        c_bnez: begin
                            new_opcode <= bne;
                            new_imm <= c_imm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= 0;
                            pc <= (predict_result) ? pc + c_imm : pc + 2;
                        end
                        c_addi4spn: begin
                            new_opcode <= addi;
                            new_imm <= c_uimm;
                            new_rs1 <= 2; // x2, sp
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_lw, c_sw: begin
                            new_opcode <= (opcode_ctype == c_lw) ? lw : sw;
                            new_imm <= c_uimm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= c_rs2;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_slli: begin
                            new_opcode <= slli;
                            new_imm <= c_uimm;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_jr: begin
                            new_opcode <= jalr;
                            new_imm <= 0;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= 0;
                        end
                        c_mv: begin
                            new_opcode <= addi;
                            new_imm <= 0;
                            new_rs1 <= c_rs2;
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_jalr: begin
                            new_opcode <= jalr;
                            new_imm <= 0;
                            new_rs1 <= c_rs1;
                            new_rs2 <= 0;
                            new_rd <= 1; // x1, ra
                        end
                        c_add: begin
                            new_opcode <= add;
                            new_imm <= 0;
                            new_rs1 <= c_rs1;
                            new_rs2 <= c_rs2;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_lwsp: begin
                            new_opcode <= lw;
                            new_imm <= c_uimm;
                            new_rs1 <= 2; // x2, sp
                            new_rs2 <= 0;
                            new_rd <= c_rd;
                            pc <= pc + 2;
                        end
                        c_swsp: begin
                            new_opcode <= sw;
                            new_imm <= c_uimm;
                            new_rs1 <= 2; // x2, sp
                            new_rs2 <= c_rs2;
                            new_rd <= 0;
                            pc <= pc + 2;
                        end
                    endcase
                    if (opcode_ctype == c_jalr || opcode_ctype == c_jr)
                        state <= WAITING_JALR;
                    else 
                        state <= IDLE;
                    new_instruction_en <= 1;
                    new_pc <= pc;
                    new_ins_width <= 2;
                    new_predict_result <= predict_result;
                end 
                else begin
                    case (opcode)
                        jalr: begin
                            state <= WAITING_JALR;
                        end
                        jal: begin
                            pc <= pc + imm;
                            state <= IDLE;
                        end
                        beq, bne, blt, bge, bltu, bgeu: begin
                            pc <= (predict_result) ? pc + imm : pc + 4;
                            state <= IDLE;
                        end
                        default: begin
                            pc <= pc + 4;
                            state <= IDLE;
                        end
                    endcase
                    // issue the instruction to Dispatcher
                    new_instruction_en <= 1;
                    new_opcode <= opcode;
                    new_pc <= pc;
                    new_rs1 <= rs1;
                    new_rs2 <= rs2;
                    new_rd <= rd;
                    new_imm <= imm;
                    new_ins_width <= 4;
                    new_predict_result <= predict_result;
                end
            end else begin
                new_instruction_en <= 0;
            end
        end
    end

endmodule