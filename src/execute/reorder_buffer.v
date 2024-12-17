// module reorder_buffer.v

module RoB #(
    parameter RoB_WIDTH = 3,
    parameter RoB_SIZE = 1 << RoB_WIDTH,

    // already decoded in Decoder/Dispatcher
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
    parameter andr = 7'd37,

    parameter EMPTY = 0,
    parameter REGISTER = 1,
    parameter BRANCH = 2,
    parameter JALR = 3,
    parameter STORE = 4
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with Dispatcher
    input wire new_entry_en,
    input wire [6 : 0] new_entry_opcode,
    input wire [4 : 0] new_entry_rd, // if rd == 0, means NON_DEP
    input wire [31 : 0] new_entry_pc,
    input wire [31 : 0] new_entry_next_pc,
    input wire new_entry_predict_result,

    input wire already_ready,
    input wire [31 : 0] ready_data,
    
    // with CDB
    input wire CDB_update_en,
    input wire [RoB_WIDTH - 1 : 0] CDB_update_index,
    input wire [31 : 0] CDB_update_data,

    // notify RF
    output reg RF_update_en,
    output reg [4 : 0] RF_update_reg,
    output reg [RoB_WIDTH - 1 : 0] RF_update_index,
    output reg [31 : 0] RF_update_data,

    // notify IF when jalr / branch goes wrong
    output reg jalr_feedback_en,
    output reg [31 : 0] jalr_feedback_data,

    output reg branch_fail_en,
    output reg [31 : 0] correct_next_pc,

    // notify branch predictor
    output reg branch_predictor_en,
    output reg [31 : 0] branch_predictor_pc,
    output reg branch_predictor_result,

    // self state
    output wire isFull,
    output wire [RoB_WIDTH - 1 : 0] new_entry_index, // the index of the new entry in RoB
    output reg flush_signal // high when predict goes wrong
);

    integer head_ptr, tail_ptr;

// Entry: isBusy, isReady, opcode, rd, pc, next_pc, predict_result(1 or 0), data, extra_data, 
/* opType:  
 * REGISTER (save data to rd)
 * BRANCH (data equals 0: not jump/ 1: jump, if predict_result != data, then FLUSH)
 * JALR (rd <= pc + 4, pc <= (Vj + imm) & ~1, i.e. data)
 * STORE (save data to memory, addr is saved in rd, extra_data is used to store length)
 * JAL will be transformed to REGISTER in Dispatcher
 */
    reg isBusy[RoB_SIZE - 1 : 0];
    reg isReady[RoB_SIZE - 1 : 0];
    reg [2 : 0] opType[RoB_SIZE - 1 : 0];
    reg [6 : 0] opcode[RoB_SIZE - 1 : 0];
    reg [31 : 0] rd[RoB_SIZE - 1 : 0]; // also used as addr?
    reg [31 : 0] pc[RoB_SIZE - 1 : 0];
    reg [31 : 0] next_pc[RoB_SIZE - 1 : 0];
    reg predict_result[RoB_SIZE - 1 : 0];
    reg [31 : 0] data[RoB_SIZE - 1 : 0];
    reg [31 : 0] extra_data[RoB_SIZE - 1 : 0];

    integer i, j;

    assign isFull = (head_ptr == tail_ptr) && isBusy[head_ptr];
    assign new_entry_index = tail_ptr;

    // for debug
    wire [2 : 0] debug_opType;
    wire [31 : 0] debug_data;
    wire [31 : 0] debug_extra_data;
    wire [31 : 0] debug_pc;
    wire [31 : 0] debug_next_pc;
    wire [31 : 0] debug_predict_result;
    wire [6 : 0] debug_opcode;
    wire [31 : 0] debug_rd;
    wire debug_isReady;
    wire debug_isBusy;
    assign debug_opType = opType[head_ptr];
    assign debug_data = data[head_ptr];
    assign debug_extra_data = extra_data[head_ptr];
    assign debug_pc = pc[head_ptr];
    assign debug_next_pc = next_pc[head_ptr];
    assign debug_predict_result = predict_result[head_ptr];
    assign debug_opcode = opcode[head_ptr];
    assign debug_rd = rd[head_ptr];
    assign debug_isBusy = isBusy[head_ptr];
    assign debug_isReady = isReady[head_ptr];

    // three things to do: 1. get new entry 2. update RoB 3. try to commit head entry
    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            head_ptr <= 0;
            tail_ptr <= 0;

            flush_signal <= 0;
            RF_update_en <= 0;
            RF_update_reg <= 0;
            jalr_feedback_en <= 0;
            branch_fail_en <= 0;
            branch_predictor_en <= 0;

            for (i = 0; i < RoB_SIZE; i = i + 1) begin
                isBusy[i] <= 0;
                isReady[i] <= 0;
                opType[i] <= EMPTY;
                rd[i] <= 0;
                pc[i] <= 0;
                next_pc[i] <= 0;
                predict_result[i] <= 0;
                data[i] <= 0;
                extra_data[i] <= 0;
                opcode[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause
        end
        else if (flush_signal) begin
            // flush
            head_ptr <= 0;
            tail_ptr <= 0;

            flush_signal <= 0;
            RF_update_en <= 0;
            RF_update_reg <= 0;
            jalr_feedback_en <= 0;
            branch_fail_en <= 0;
            branch_predictor_en <= 0;

            for (i = 0; i < RoB_SIZE; i = i + 1) begin
                isBusy[i] <= 0;
                isReady[i] <= 0;
                opType[i] <= EMPTY;
                rd[i] <= 0;
                pc[i] <= 0;
                next_pc[i] <= 0;
                predict_result[i] <= 0;
                data[i] <= 0;
                extra_data[i] <= 0;
                opcode[i] <= 0;
            end
        end
        else begin
            // reset enable signals
            flush_signal <= 0;
            RF_update_en <= 0;
            RF_update_reg <= 0;
            jalr_feedback_en <= 0;
            branch_fail_en <= 0;
            branch_predictor_en <= 0;

            // get new entry
            if (!isFull && new_entry_en) begin
                isBusy[tail_ptr] <= 1;
                isReady[tail_ptr] <= already_ready;
                data[tail_ptr] <= already_ready ? ready_data : 0;
                rd[tail_ptr] <= new_entry_rd;
                pc[tail_ptr] <= new_entry_pc;
                next_pc[tail_ptr] <= new_entry_next_pc;
                predict_result[tail_ptr] <= new_entry_predict_result;
                opcode[tail_ptr] <= new_entry_opcode;
                case (new_entry_opcode)
                    jalr : begin
                        opType[tail_ptr] <= JALR;
                    end
                    lui, auipc, jal, lb, lh, lw, lbu, lhu, addi, slti, sltiu, xori, ori, andi, slli, srli, srai, add, sub, sll, slt, sltu, xorr, srl, sra, orr, andr: begin
                        opType[tail_ptr] <= REGISTER;
                    end
                    beq, bne, blt, bge, bltu, bgeu: begin
                        opType[tail_ptr] <= BRANCH;
                    end
                    sb, sh, sw: begin
                        opType[tail_ptr] <= STORE;
                    end
                    default: begin
                        opType[tail_ptr] <= EMPTY;
                    end
                endcase
                tail_ptr <= (tail_ptr + 1) % RoB_SIZE;
            end

            // monitor CDB, update data
            if (CDB_update_en) begin
                isReady[CDB_update_index] <= 1;
                data[CDB_update_index] <= CDB_update_data;
            end

            // commit head entry
            if (isReady[head_ptr]) begin
                // data is ready
                case (opType[head_ptr])
                    REGISTER: begin
                        // write data[head_ptr] to rd[head_ptr]
                        RF_update_en <= 1;
                        RF_update_reg <= rd[head_ptr];
                        RF_update_index <= head_ptr;
                        RF_update_data <= data[head_ptr];
                    end
                    BRANCH: begin
                        if (data[head_ptr] != predict_result[head_ptr]) begin
                            // FLUSH
                            flush_signal <= 1;
                            // tell IF to jump to correct_next_pc
                            branch_fail_en <= 1;
                            if (opcode[head_ptr] == beq || opcode[head_ptr] == bne) begin
                                correct_next_pc <= next_pc[head_ptr];
                            end
                            else begin
                                correct_next_pc <= pc[head_ptr] + 4;
                            end
                        end 
                        // branch_predictor update
                        branch_predictor_en <= 1;
                        branch_predictor_pc <= pc[head_ptr];
                        branch_predictor_result <= data[head_ptr];
                    end
                    JALR: begin
                        // write back to RF
                        RF_update_en <= 1;
                        RF_update_reg <= rd[head_ptr];
                        RF_update_index <= head_ptr;
                        RF_update_data <= pc[head_ptr] + 4;
                        // jump to next_pc
                        jalr_feedback_en <= 1;
                        jalr_feedback_data <= data[head_ptr]; // next_pc
                    end
                    STORE: begin
                        // has been committed by LSB
                    end
                    default: begin
                        // something goes wrong
                    end
                endcase
                isBusy[head_ptr] <= 0;
                isReady[head_ptr] <= 0;
                head_ptr <= (head_ptr + 1) % RoB_SIZE;
                opType[head_ptr] <= EMPTY;
                rd[head_ptr] <= 0;
                pc[head_ptr] <= 0;
                next_pc[head_ptr] <= 0;
                predict_result[head_ptr] <= 0;
                data[head_ptr] <= 0;
                extra_data[head_ptr] <= 0;
                opcode[head_ptr] <= 0;
            end
        end
    end



endmodule