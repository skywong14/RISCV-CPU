// module LSB.v

// STATE: IDLE, WAITING

// each Entry contains: opcode, Vj, Vk, Qj, Qk, isBusy, RoBEntry, imm(memory_addr), isReady = isBusy & Qj == NON_DEP & Qk == NON_DEP

// get new instruction from dispatcher: new_inst_en && !LSB_is_full, then get values from dispatcher

// if Entry.isReady == 1 && STATE == IDLE: 向Memory_Controller发送对应的R/W信号, STATE <= WAITING

// if STATE == WAITING && Mem_Controller_reply_r/w_en == 1: 当前R/W操作完成，更新，发送对应的RoBEntry给RoB

// 细节：注意接收RoB的FLUSH信号

// 循环队列[head_ptr, tail_ptr), is_full = isBusy[tail_ptr]


module LSB #(
    parameter LSB_WIDTH = 2,
    parameter LSB_SIZE = 1 << LSB_WIDTH,

    parameter RoB_WIDTH = 3, // RoBEntry width
    parameter RoB_SIZE = 1 << RoB_WIDTH, // [0, RoBSIZE - 1] is valid
    parameter NON_DEP = 1 << RoB_WIDTH, // NON_DEP signal


    parameter IDLE = 0,
    parameter WAITING = 1
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with Memory Controller
    input wire mem_reply_W_en,
    input wire mem_reply_R_en, // R/W finished
    output reg mem_query_W_en,
    output reg mem_query_R_en, // R/W query signal


    // FLUSH signal from RoB
    input wire flush_signal, // predict goes wrong

    // with CDB
    



    // self state
    output wire isFull
);
    reg STATE;

    // Entry
    reg [6 : 0] opcode[LSB_SIZE - 1 : 0];
    reg [31 : 0] Vj[LSB_SIZE - 1 : 0], Vk[LSB_SIZE - 1 : 0];
    reg [RoB_WIDTH : 0] Qj[LSB_SIZE - 1 : 0], Qk[LSB_SIZE - 1 : 0]; // reg[RoB_WIDTH] is valid signal
    reg [RoB_WIDTH - 1 : 0] RoBEntry[LSB_SIZE - 1 : 0];
    reg isBusy[LSB_SIZE - 1 : 0];
    wire isReady[LSB_SIZE - 1 : 0];

    integer head_ptr, tail_ptr; // init: 0, 0

    assign isFull = isBusy[tail_ptr];


    // isReady = isBusy & Qj == NON_DEP & Qk == NON_DEP
    genvar i;
    generate
        for (i = 0; i < LSB_SIZE; i = i + 1) begin: isReady_generate
            assign isReady[i] = isBusy[i] && (Qj[i] == NON_DEP) && (Qk[i] == NON_DEP);
        end
    endgenerate

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
        end

    end    


endmodule