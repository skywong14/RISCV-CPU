// module LSB.v

// STATE: IDLE, WAITING

// each Entry contains: opcode, Vj, Vk, Qj, Qk, isBusy, RoBEntry, imm(memory_addr), isReady = isBusy & Qj == NON_DEP & Qk == NON_DEP

// get new instruction from dispatcher: new_inst_en && !LSB_is_full, then get values from dispatcher

// if Entry.isReady == 1 && STATE == IDLE: 向Memory_Controller发送对应的R/W信号, STATE <= WAITING

// if STATE == WAITING && Mem_Controller_reply_r/w_en == 1: 当前R/W操作完成，更新，发送对应的RoBEntry给RoB

// 细节：注意接收RoB的FLUSH信号

// 循环队列[head_ptr, tail_ptr), is_full = isBusy[tail_ptr]

// commite WRITE command: isBusy && isReady && Head_Entry.RoBIndex == RoB.headIndex


module LSB #(
    parameter LSB_WIDTH = 2,
    parameter LSB_SIZE = 1 << LSB_WIDTH,

    parameter RoB_WIDTH = 3, // RoBEntry width
    parameter RoB_SIZE = 1 << RoB_WIDTH, // [0, RoBSIZE - 1] is valid
    parameter NON_DEP = 1 << RoB_WIDTH, // NON_DEP signal

    parameter NORMAL = 0,
    parameter INTERRUPT = 1,

    // L type
    parameter lb = 7'd11,
    parameter lh = 7'd12,
    parameter lw = 7'd13,
    parameter lbu = 7'd14,
    parameter lhu = 7'd15,
    // S type
    parameter sb = 7'd16,
    parameter sh = 7'd17,
    parameter sw = 7'd18
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with Memory Controller
    input wire mem_reply_en,
    input wire [31 : 0] mem_reply_data, // read data from memory
    output reg mem_query_en,
    output reg mem_query_type, // 0: read, 1: write
    output reg [31 : 0] mem_query_addr, // address to read/write
    output reg [1 : 0] mem_data_width, // 0:byte, 1:halfword, 2:word (1/2/4 bytes)
    output reg [31 : 0] mem_query_data, // data to write

    // with Dispatcher
    input wire new_entry_en,
    input wire [RoB_WIDTH - 1 : 0] new_entry_RoBIndex,
    input wire [6 : 0] new_entry_opcode,
    input wire [31 : 0] new_entry_imm,
    input wire [31 : 0] new_entry_Vj,
    input wire [31 : 0] new_entry_Vk,
    input wire [RoB_WIDTH : 0] new_entry_Qj,
    input wire [RoB_WIDTH : 0] new_entry_Qk,


    // with CDB
    input wire RoB_update_en,
    input wire [RoB_WIDTH - 1 : 0] RoB_update_index,
    input wire [31 : 0] RoB_update_data,
    output reg RoB_write_en,
    output reg [RoB_WIDTH - 1 : 0] RoB_write_index,
    output reg [31 : 0] RoB_write_data,

    // with RoB
    input wire [RoB_WIDTH : 0] RoB_headIndex, // the first entry waiting to commit, might be NON_DEP
    output reg [RoB_WIDTH : 0] lstCommittedWrite, // RoBIndex of the last committed write by LSB, might be NON_DEP

    // FLUSH signal from RoB
    input wire flush_signal,

    // self state
    output wire isFull
);
    reg state;

    // Entry
    reg op_type[LSB_SIZE - 1 : 0]; // 0: L type, 1: S type
    reg [1 : 0] data_width[LSB_SIZE - 1 : 0]; // 0:byte, 1:halfword, 2:word (1/2/4 bytes)
    reg [31 : 0] Vj[LSB_SIZE - 1 : 0], Vk[LSB_SIZE - 1 : 0];
    reg [RoB_WIDTH : 0] Qj[LSB_SIZE - 1 : 0], Qk[LSB_SIZE - 1 : 0]; // reg[RoB_WIDTH] is valid signal
    reg [RoB_WIDTH - 1 : 0] RoBEntry[LSB_SIZE - 1 : 0];
    reg isBusy[LSB_SIZE - 1 : 0];
    reg extend_type[LSB_SIZE - 1 : 0]; // 0: sign extend, 1: zero extend
    wire isReady[LSB_SIZE - 1 : 0];

    integer head_ptr, tail_ptr; // init: 0, 0

    assign isFull = isBusy[tail_ptr];

    // isReady = isBusy & Qj == NON_DEP & Qk == NON_DEP
    genvar gen_i;
    generate
        for (gen_i = 0; gen_i < LSB_SIZE; gen_i = gen_i + 1) begin: isReady_generate
            assign isReady[gen_i] = isBusy[gen_i] && (Qj[gen_i] == NON_DEP) && (Qk[gen_i] == NON_DEP);
        end
    endgenerate

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= NORMAL;
            head_ptr <= 0;
            tail_ptr <= 0;
            mem_query_en <= 0;
            mem_query_addr <= 0;
            RoB_write_en <= 0;
            lstCommittedWrite <= NON_DEP;
            for (i = 0; i < LSB_SIZE; i = i + 1) begin
                op_type[i] <= 0;
                data_width[i] <= 0;
                Vj[i] <= 0;
                Vk[i] <= 0;
                Qj[i] <= NON_DEP;
                Qk[i] <= NON_DEP;
                RoBEntry[i] <= 0;
                isBusy[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (state == NORMAL) begin
                // get a new entry
                if (new_entry_en && !isFull) begin
                    isBusy[tail_ptr] <= 1;
                    tail_ptr <= (tail_ptr + 1) % LSB_SIZE;
                    // get values from dispatcher
                    Vj[tail_ptr] <= new_entry_Vj;
                    Vk[tail_ptr] <= new_entry_Vk;
                    Qj[tail_ptr] <= new_entry_Qj;
                    Qk[tail_ptr] <= new_entry_Qk;
                    RoBEntry[tail_ptr] <= new_entry_RoBIndex;
                    case (new_entry_opcode)
                        lb : begin
                            op_type[tail_ptr] <= 0;
                            data_width[tail_ptr] <= 0;
                            extend_type[tail_ptr] <= 0;
                        end
                        lh : begin
                            op_type[tail_ptr] <= 0;
                            data_width[tail_ptr] <= 1;
                            extend_type[tail_ptr] <= 0;
                        end
                        lw : begin
                            op_type[tail_ptr] <= 0;
                            data_width[tail_ptr] <= 2;
                            extend_type[tail_ptr] <= 0;
                        end
                        lbu : begin
                            op_type[tail_ptr] <= 0;
                            data_width[tail_ptr] <= 2;
                            extend_type[tail_ptr] <= 1;
                        end
                        lhu : begin
                            op_type[tail_ptr] <= 0;
                            data_width[tail_ptr] <= 1;
                            extend_type[tail_ptr] <= 1;
                        end
                        sb : begin
                            op_type[tail_ptr] <= 1;
                            data_width[tail_ptr] <= 0;
                        end
                        sh : begin
                            op_type[tail_ptr] <= 1;
                            data_width[tail_ptr] <= 1;
                        end
                        sw : begin
                            op_type[tail_ptr] <= 1;
                            data_width[tail_ptr] <= 2;
                        end
                    endcase
                end
                
                // READ before the first WRITE
                if (isBusy[head_ptr] && isReady[head_ptr] && op_type[head_ptr] == 0) begin

                end

                // WRITE at head
                if (isBusy[head_ptr] && isReady[head_ptr] && op_type[head_ptr] == 1 && RoB_headIndex == RoBEntry[head_ptr]) begin
                    
                end
            end
        end
    end    


endmodule