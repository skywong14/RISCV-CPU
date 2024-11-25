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
    parameter WAITING = 1,
    parameter PREDICTING = 2,
    parameter PENDING_JALR = 3
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // self state
    output reg [1 : 0] state,

    // interface with ICache
    

    // interface with RoB
    input wire rob_is_full,
    input wire [RoB_SIZE : 0] rob_index, // an empty RoB entry, but it will be issued by Dispatcher rather than IF

    input wire jalr_result_en, // ATTENTION: special case for jalr feedback, at this time state == PENDING_JALR
    input wire [31 : 0] jalr_result,
    input wire [31 : 0] correct_next_pc, // the correct next pc


    // interface with Dispatcher
    input wire new_instruction_en, // able to issue new instruction, then IF will be launched


    // interface with Branch_Predictor, B-type instruction
    output reg predict_query_en,
    output reg [31 : 0] predict_query_pc,
    input wire predict_result_en,
    input wire predict_result // 0: not jump, 1: jump
);


    reg [31 : 0] pc;
    reg [31 : 0] next_pc;
    reg [31 : 0] cur_instruction;
    wire [6 : 0] opcode;
    wire [31 : 0] imm;
    assign opcode = cur_instruction[6 : 0];
    assign imm = (opcode == 7'b1101111) ? {{12{cur_instruction[31]}}, cur_instruction[19:12], cur_instruction[20], cur_instruction[30:21], 1'b0}  // jal imm[20|10:1|11|19:12|0]
                :(opcode == 7'b1100011) ? {{20{cur_instruction[31]}}, cur_instruction[7], cur_instruction[30:25], cur_instruction[11:8], 1'b0}  // branch imm[12|10:5|4:1|11|0]
                : 32'b0;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            pc <= 0;
            next_pc <= 0;
            cur_instruction <= 0;
            predict_query_en <= 0;
        end
        else if (!rdy_in) begin
            // pause

        end
        else if (state == PENDING_JALR) begin
            // waiting for jalr result

        end
        else if (state == WAITING) begin
            // waiting

        end
        else if (state == PREDICTING) begin
            // waiting for predict result

        end
        else begin
            // try to fetch the instruction at pc (ask ICache)
            // judge if Dispatcher able to issue new instruction && RoB is not full

            // run
            if () begin
                // cur_instruction is jalr
                
            end
            else if () begin
                // cur_instruction is branch (envoke Branch_Predictor)


            end
            else if () begin
                // other instructions


            end

        end
    end    



endmodule