// module reorder_buffer.v

// when predict goes wrong, send a high flush_signal to the CPU(CDB), and reset itself

// FLUSH (when predict goes wrong, or sys_rst is high): clear current instructions in rob



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

    parameter REGISTER = 0,
    parameter BRANCH = 1,
    parameter JALR = 2,
    parameter STORE = 3,
    parameter EXIT = 4
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,



    // self state
    output wire isFull,
    output wire [RoB_WIDTH - 1 : 0] new_entry_index, // the index of the new entry in RoB
    output reg flush_signal, // high when predict goes wrong
    output reg falt_sign
);

    reg [RoB_WIDTH - 1 : 0] head_ptr, tail_ptr;

// Entry: RoB_index, isBusy, isReady, opType, rd, pc, next_pc, predict_result(1 or 0), data, extra_data
/* opType:  
 * REGISTER (save data to rd)
 * BRANCH (data equals 0: not jump/ 1: jump, if predict_result != data, then FLUSH)
 * JALR (save next_pc to rd)
 * STORE (save data to memory, addr is saved in rd, extra_data is used to store length)
 * EXIT todo
 * JAL will be transformed to REGISTER in Dispatcher
 */
    reg [RoB_WIDTH - 1 : 0] RoB_index[RoB_SIZE - 1 : 0];
    reg isBusy[RoB_SIZE - 1 : 0];
    reg isReady[RoB_SIZE - 1 : 0];
    reg [2 : 0] opType[RoB_SIZE - 1 : 0];
    reg [31 : 0] rd[RoB_SIZE - 1 : 0]; // also used as addr
    reg [31 : 0] pc[RoB_SIZE - 1 : 0];
    reg [31 : 0] next_pc[RoB_SIZE - 1 : 0];
    reg predict_result[RoB_SIZE - 1 : 0];
    reg [31 : 0] data[RoB_SIZE - 1 : 0];
    reg [31 : 0] extra_data[RoB_SIZE - 1 : 0];

    integer i, j;

    assign isFull = (head_ptr == tail_ptr) && isBusy[head_ptr];
    assign new_entry_index = tail_ptr;

    // three things to do: 1. get new entry 2. update RoB 3. try to commit head entry
    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            head_ptr <= 0;
            tail_ptr <= 0;
            flush_signal <= 0;
            falt_sign <= 0;
            for (i = 0; i < RoB_SIZE; i = i + 1) begin
                RoB_index[i] <= 0;
                isBusy[i] <= 0;
                isReady[i] <= 0;
                opType[i] <= 0;
                rd[i] <= 0;
                pc[i] <= 0;
                next_pc[i] <= 0;
                predict_result[i] <= 0;
                data[i] <= 0;
                extra_data[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause

        end
        else begin
            // run
            // get new entry


            // update RoB


            // commit head entry
            if (isReady[head_ptr]) begin
                // data is ready
                case (opType[head_ptr])
                    REGISTER: begin
                        // write back to RF

                    end
                    BRANCH: begin
                        // branch predict success
                        
                        // branch predict fail

                    end
                    JALR: begin
                        // write back to RF

                        // jump to next_pc

                        // send signal to IF

                    end
                    STORE: begin
                        // if not finished, ask LSB to write, wait for response

                        // if done, pop entry

                    end
                    default: begin
                        // EXIT
                    end
                endcase
                isBusy[head_ptr] <= 0;
                head_ptr <= head_ptr + 1;
            end    
        end
    end



endmodule