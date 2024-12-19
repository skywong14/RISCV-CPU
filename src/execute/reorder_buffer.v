// module reorder_buffer.v

module RoB #(
    parameter RoB_WIDTH = 3,
    parameter RoB_SIZE = 1 << RoB_WIDTH,
    parameter NON_DEP = 1 << RoB_WIDTH,

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

    input wire [RoB_WIDTH : 0] query_Qj_index,
    output wire query_Qj_isReady,
    output wire [31 : 0] query_Qj_data,
    input wire [RoB_WIDTH : 0] query_Qk_index,
    output wire query_Qk_isReady,
    output wire [31 : 0] query_Qk_data,

    // debug
    output reg debug_en,
    output reg [31 : 0] debug_commit_id,
    
    // with CDB
    input wire CDB_RS_update_en,
    input wire [RoB_WIDTH - 1 : 0] CDB_RS_update_index,
    input wire [31 : 0] CDB_RS_update_data,
    input wire CDB_LSB_update_en,
    input wire [RoB_WIDTH - 1 : 0] CDB_LSB_update_index,
    input wire [31 : 0] CDB_LSB_update_data,

    // notify RF
    output reg RF_update_en,
    output reg [4 : 0] RF_update_reg,
    output reg [RoB_WIDTH - 1 : 0] RF_update_index,
    output reg [31 : 0] RF_update_data,

    // notify IF when jalr / branch goes wrong
    output reg jalr_feedback_en,
    output reg [31 : 0] jalr_feedback_data,

    output reg [31 : 0] correct_next_pc,

    // notify branch predictor
    output reg bp_update_en,
    output reg [31 : 0] bp_update_pc,
    output reg bp_update_result,

    // self state
    output wire isFull,
    output wire [RoB_WIDTH - 1 : 0] RoB_headIndex, // the head of RoB
    output wire [RoB_WIDTH - 1 : 0] RoB_tailIndex, // the index of the new entry in RoB
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
    reg isReady[RoB_SIZE : 0];
    reg [2 : 0] opType[RoB_SIZE - 1 : 0];
    reg [6 : 0] opcode[RoB_SIZE - 1 : 0];
    reg [31 : 0] rd[RoB_SIZE - 1 : 0]; // also used as addr?
    reg [31 : 0] pc[RoB_SIZE - 1 : 0];
    reg [31 : 0] next_pc[RoB_SIZE - 1 : 0];
    reg predict_result[RoB_SIZE - 1 : 0];
    reg [31 : 0] data[RoB_SIZE : 0];
    reg [31 : 0] extra_data[RoB_SIZE - 1 : 0];

    integer i, j;

    assign isFull = (head_ptr == tail_ptr) && isBusy[head_ptr];
    assign RoB_headIndex = head_ptr;
    assign RoB_tailIndex = tail_ptr;

    reg extra_wait;

    assign query_Qj_isReady = isReady[query_Qj_index];
    assign query_Qj_data = data[query_Qj_index];
    assign query_Qk_isReady = isReady[query_Qk_index];
    assign query_Qk_data = data[query_Qk_index];

    // for debug
    /*
    wire [2 : 0] debug_0_opType;
    wire [31 : 0] debug_0_data;
    wire [31 : 0] debug_0_extra_data;
    wire [31 : 0] debug_0_pc;
    wire [31 : 0] debug_0_next_pc;
    wire [31 : 0] debug_0_predict_result;
    wire [6 : 0] debug_0_opcode;
    wire [31 : 0] debug_0_rd;
    wire debug_0_isReady;
    wire debug_0_isBusy;
    assign debug_0_opType = opType[0];
    assign debug_0_data = data[0];
    assign debug_0_extra_data = extra_data[0];
    assign debug_0_pc = pc[0];
    assign debug_0_next_pc = next_pc[0];
    assign debug_0_predict_result = predict_result[0];
    assign debug_0_opcode = opcode[0];
    assign debug_0_rd = rd[0];
    assign debug_0_isBusy = isBusy[0];
    assign debug_0_isReady = isReady[0];
    wire [2 : 0] debug_1_opType;
    wire [31 : 0] debug_1_data;
    wire [31 : 0] debug_1_extra_data;
    wire [31 : 0] debug_1_pc;
    wire [31 : 0] debug_1_next_pc;
    wire [31 : 0] debug_1_predict_result;
    wire [6 : 0] debug_1_opcode;
    wire [31 : 0] debug_1_rd;
    wire debug_1_isReady;
    wire debug_1_isBusy;
    assign debug_1_opType = opType[1];
    assign debug_1_data = data[1];
    assign debug_1_extra_data = extra_data[1];
    assign debug_1_pc = pc[1];
    assign debug_1_next_pc = next_pc[1];
    assign debug_1_predict_result = predict_result[1];
    assign debug_1_opcode = opcode[1];
    assign debug_1_rd = rd[1];
    assign debug_1_isBusy = isBusy[1];
    assign debug_1_isReady = isReady[1];
    wire [2 : 0] debug_2_opType;
    wire [31 : 0] debug_2_data;
    wire [31 : 0] debug_2_extra_data;
    wire [31 : 0] debug_2_pc;
    wire [31 : 0] debug_2_next_pc;
    wire [31 : 0] debug_2_predict_result;
    wire [6 : 0] debug_2_opcode;
    wire [31 : 0] debug_2_rd;
    wire debug_2_isReady;
    wire debug_2_isBusy;
    assign debug_2_opType = opType[2];
    assign debug_2_data = data[2];
    assign debug_2_extra_data = extra_data[2];
    assign debug_2_pc = pc[2];
    assign debug_2_next_pc = next_pc[2];
    assign debug_2_predict_result = predict_result[2];
    assign debug_2_opcode = opcode[2];
    assign debug_2_rd = rd[2];
    assign debug_2_isBusy = isBusy[2];
    assign debug_2_isReady = isReady[2];
    wire [2 : 0] debug_3_opType;
    wire [31 : 0] debug_3_data;
    wire [31 : 0] debug_3_extra_data;
    wire [31 : 0] debug_3_pc;
    wire [31 : 0] debug_3_next_pc;
    wire [31 : 0] debug_3_predict_result;
    wire [6 : 0] debug_3_opcode;
    wire [31 : 0] debug_3_rd;
    wire debug_3_isReady;
    wire debug_3_isBusy;
    assign debug_3_opType = opType[3];
    assign debug_3_data = data[3];
    assign debug_3_extra_data = extra_data[3];
    assign debug_3_pc = pc[3];
    assign debug_3_next_pc = next_pc[3];
    assign debug_3_predict_result = predict_result[3];
    assign debug_3_opcode = opcode[3];
    assign debug_3_rd = rd[3];
    assign debug_3_isBusy = isBusy[3];
    assign debug_3_isReady = isReady[3];
    */
    integer commit_num, file;
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
            bp_update_en <= 0;
            extra_wait <= 0;
            
            debug_en <= 0;
            commit_num <= 1;

            isReady[NON_DEP] <= 0;
            data[NON_DEP] <= 0;

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
            // flush, wait an extra cycle
            if (extra_wait) begin
                extra_wait <= 0;
                flush_signal <= 0;
            end
            else begin
                extra_wait <= 1;
                
                head_ptr <= 0;
                tail_ptr <= 0;
                RF_update_en <= 0;
                RF_update_reg <= 0;
                jalr_feedback_en <= 0;
                bp_update_en <= 0;

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
        end
        else begin
            // reset enable signals
            flush_signal <= 0;
            RF_update_en <= 0;
            RF_update_reg <= 0;
            jalr_feedback_en <= 0;
            bp_update_en <= 0;
            debug_en <= 0;

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
            if (CDB_RS_update_en) begin
                isReady[CDB_RS_update_index] <= 1;
                data[CDB_RS_update_index] <= CDB_RS_update_data;
            end
            if (CDB_LSB_update_en) begin
                isReady[CDB_LSB_update_index] <= 1;
                data[CDB_LSB_update_index] <= CDB_LSB_update_data;
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
                        // predict_result: 1 jump, 0 not jump
                        if (data[head_ptr] != predict_result[head_ptr]) begin
                            // FLUSH
                            flush_signal <= 1;
                            // tell IF to jump to correct_next_pc
                            if (data[head_ptr]) begin
                                correct_next_pc <= next_pc[head_ptr];
                            end
                            else begin
                                correct_next_pc <= pc[head_ptr] + 4;
                            end
                        end 
                        // branch_predictor update
                        bp_update_en <= 1;
                        bp_update_pc <= pc[head_ptr];
                        bp_update_result <= data[head_ptr];
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


                // debug, print commit info
                /*
                commit_num <= commit_num + 1;
                if (commit_num <= 3000) begin
                    debug_en <= 1;
                    debug_commit_id <= commit_num;
                    file = $fopen("RoB_debug.txt", "a");
                    $fdisplay(file, "commit_id = [%d]: ", commit_num);
                    for (j = 0; j < RoB_SIZE; j = j + 1) 
                    if (isBusy[j]) begin
                        case (opcode[j])
                            lui: $fdisplay(file, "lui"); auipc: $fdisplay(file, "auipc"); jal: $fdisplay(file, "jal"); jalr: $fdisplay(file, "jalr"); beq: $fdisplay(file, "beq"); bne: $fdisplay(file, "bne");
                            blt: $fdisplay(file, "blt"); bge: $fdisplay(file, "bge"); bltu: $fdisplay(file, "bltu"); bgeu: $fdisplay(file, "bgeu"); lb: $fdisplay(file, "lb"); lh: $fdisplay(file, "lh");
                            lw: $fdisplay(file, "lw"); lbu: $fdisplay(file, "lbu"); lhu: $fdisplay(file, "lhu"); sb: $fdisplay(file, "sb"); sh: $fdisplay(file, "sh"); sw: $fdisplay(file, "sw");
                            addi: $fdisplay(file, "addi"); slti: $fdisplay(file, "slti"); sltiu: $fdisplay(file, "sltiu"); xori: $fdisplay(file, "xori"); ori: $fdisplay(file, "ori"); andi: $fdisplay(file, "andi");
                            slli: $fdisplay(file, "slli"); srli: $fdisplay(file, "srli"); srai: $fdisplay(file, "srai"); add: $fdisplay(file, "add"); sub: $fdisplay(file, "sub"); sll: $fdisplay(file, "sll");
                            slt: $fdisplay(file, "slt"); sltu: $fdisplay(file, "sltu"); xorr: $fdisplay(file, "xorr"); srl: $fdisplay(file, "srl"); sra: $fdisplay(file, "sra"); orr: $fdisplay(file, "orr");
                            andr: $fdisplay(file, "andr"); default: $fdisplay(file, "unknown");
                        endcase
                        $fdisplay(file, "{%d} opType = %d, data = %d, extra_data = %d, pc = 0x%h, next_pc = 0x%h, predict_result = %d, opcode = %d, rd = %d, isReady = %d, isBusy = %d", j, opType[j], data[j], extra_data[j], pc[j], next_pc[j], predict_result[j], opcode[j], rd[j], isReady[j], isBusy[j]);
                    end
                    $fclose(file);
                end
                */
            end
        end
    end



endmodule