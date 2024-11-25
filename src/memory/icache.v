// module icache.v
// 
// WORK_STATE: IDLE, BUSY (if not int cache and waiting for memory_controller)

// 对于一个地址query_addr, 最后两位一定为00，规定一个块包含了内有 [ BLOCK_WIDTH + 1 : 2] 共 2 ^ BLOCK_WIDTH 个地址 (一个块的大小为 2 ^ BLOCK_WIDTH * 4 Byte)
// ICACHE有 2 ^ CACHE_WIDTH 个块
// 故 index_block = query_addr[BLOCK_WIDTH + 1 + CACHE_WIDTH : BLOCK_WIDTH + 2], index_addr = query_addr[BLOCK_WIDTH + 1 : 2]
// query_addr: ... | <CACHE_WIDTH> | <BLOCK_WIDTH> | 00

// 缓存方式：根据index_block查询，如果cache_valid[index_block]且cache_addr[index_block]与query_addr[:BLOCK_WIDTH + 2]相同，则命中，返回cache_data[index_block][index_addr]，state still IDLE
//          否则未命中，state <= BUSY，向memory_controller发送请求； 等待返回数据，返回数据后，将cache_data[index_block]更新，state <= IDLE，返回数据

// 返回数据： IF_data_out_en <= 1, IF_data_out <= cache_data[index_block][index_addr] (if hit) or later (if miss)

// 向memory_controller发送请求：MC_query_en <= 1, MC_query_addr <= query_addr[:BLOCK_WIDTH + 2]
// 从memory_controller接收数据, if MC_data_en == 1: cache_data[index_block] <= MC_data, cache_valid[index_block] <= 1; IF_data_out_en <= 1, IF_data_out <= MC_data[index_addr] ; state <= IDLE

module ICache #(
    parameter CACHE_WIDTH = 2,
    parameter BLOCK_WIDTH = 2,

    parameter CACHE_SIZE = 1 << CACHE_WIDTH,
    parameter BLOCK_SIZE = 1 << BLOCK_WIDTH,
    
    parameter IDLE = 0,
    parameter BUSY = 1
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // query to Memory Controller
    output reg MC_query_en,
    output reg [31 : 0] MC_query_addr, // MC_query_size == BLOCK_WIDTH

    // data(block information) from Memory Controller
    input wire MC_data_en,
    input wire [32 * BLOCK_SIZE - 1 : 0] MC_data,

    // output to IF
    output reg IF_data_out_en,
    output reg [31 : 0] IF_data_out
);

    reg state;
    reg data_valid[CACHE_SIZE - 1 : 0];
    reg[31 : 0] cache_data[CACHE_SIZE - 1 : 0][BLOCK_SIZE - 1 : 0];

    integer i, j;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                data_valid[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause

        end
        else begin
            // run

        end
    end    




endmodule