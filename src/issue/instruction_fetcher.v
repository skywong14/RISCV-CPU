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

    parameter jal = 7'd3,
    parameter jalr = 7'd4,
    // B type
    parameter beq = 7'd5,
    parameter bne = 7'd6,
    parameter blt = 7'd7,
    parameter bge = 7'd8,
    parameter bltu = 7'd9,
    parameter bgeu = 7'd10
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with ICache
    output reg icache_query_en,
    output reg [31 : 0] icache_query_pc,
    input wire icache_data_en,
    input wire [31 : 0] icache_data,

    // with RoB
    input wire rob_isFull,
    input wire [RoB_WIDTH - 1 : 0] new_entry_index, // an empty RoB entry, but it will be issued by Dispatcher rather than IF

    input wire jalr_result_en, // ATTENTION: special case for jalr feedback, at this time state == WAITING_JALR
    input wire [31 : 0] jalr_result,
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

    // with Branch_Predictor
    output wire [31 : 0] predict_query_pc,
    input wire predict_result_en,
    input wire predict_result // 0: not jump, 1: jump
);
    reg [1 : 0] state;

    reg [31 : 0] pc;
    reg [31 : 0] cur_instruction;

    wire[6 : 0] opcode;
    wire[4 : 0] rs1;
    wire[4 : 0] rs2;
    wire[4 : 0] rd;
    wire[31 : 0] imm;
    wire cur_predict_result;

    Decoder module_Decoder (
        .instruction(cur_instruction),
        .opcode(opcode),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .imm(imm)
    );

    assign predict_query_pc = pc;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            pc <= 0;
            cur_instruction <= 0;
            icache_query_en <= 0;
            new_instruction_en <= 0;
            new_predict_result <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end
        else if (state == WAITING_JALR) begin
            // waiting for jalr result
            if (jalr_result_en) begin
                pc <= jalr_result;
                state <= IDLE;
            end
        end
        else if (state == WAITING_ICACHE) begin
            // waiting
            if (icache_data_en) begin
                cur_instruction <= icache_data;
                state <= ISSUING;
                icache_query_en <= 0;
            end
        end
        else if (state == IDLE) begin
            // pc is ready
            // try to fetch the instruction at pc (ask ICache)
            icache_query_en <= 1;
            icache_query_pc <= pc;
            state <= WAITING_ICACHE;
        end
        else if (state == ISSUING && new_instruction_able) begin
            // pc and instruction are ready
            // use module_Decoder to decode the instruction
            case (opcode)
                jalr: begin
                    state <= WAITING_JALR;
                end
                jal: begin
                    pc <= pc + imm;
                    state <= IDLE;
                end
                beq, bne, blt, bge, bltu, bgeu: begin
                    if (predict_result) begin
                        pc <= pc + imm;
                    end
                    else begin
                        pc <= pc + 4;
                    end
                    state <= IDLE;
                end
                default: begin
                    pc <= pc + 4;
                    state <= IDLE;
                end
            endcase
            
            // issue the instruction to Dispatcher
            new_instruction_en <= 1;
            new_pc <= pc;
            new_opcode <= opcode;
            new_rs1 <= rs1;
            new_rs2 <= rs2;
            new_rd <= rd;
            new_imm <= imm;
            new_predict_result <= predict_result;
        end
    end    



endmodule