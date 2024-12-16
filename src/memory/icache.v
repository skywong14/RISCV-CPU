// module icache.v
// 
// WORK_STATE: IDLE, BUSY (if not int cache and waiting for memory_controller)

// ICACHE有 2 ^ CACHE_WIDTH 个块
// 故 index_block = query_addr[BLOCK_WIDTH + 1 + CACHE_WIDTH : BLOCK_WIDTH + 2], index_addr = query_addr[BLOCK_WIDTH + 1 : 2]
// query_addr: ... | <CACHE_WIDTH> | <BLOCK_WIDTH> | 00

// 缓存方式：根据index_block查询，如果cache_valid[index_block]且cache_addr[index_block]与query_addr[:BLOCK_WIDTH + 2]相同，则命中，返回cache_data[index_block][index_addr]，state still IDLE
//          否则未命中，state <= BUSY，向memory_controller发送请求； 等待返回数据，返回数据后，将cache_data[index_block]更新，state <= IDLE，返回数据

// 返回数据： IF_data_out_en <= 1, IF_data_out <= cache_data[index_block][index_addr] (if hit) or later (if miss)

// 向memory_controller发送请求：MC_query_en <= 1, MC_query_addr <= query_addr[:BLOCK_WIDTH + 2]
// 从memory_controller接收数据, if MC_data_en == 1: cache_data[index_block] <= MC_data, cache_valid[index_block] <= 1; IF_data_out_en <= 1, IF_data_out <= MC_data[index_addr] ; state <= IDLE

module ICache #(
    parameter CACHE_WIDTH = 3, // 8 blocks in cache
    parameter BLOCK_WIDTH = 2, // 4 words, 16 bytes in a block(i.e. 4 instructions per block), this parameter should not be modified

    parameter CACHE_SIZE = 1 << CACHE_WIDTH,
    parameter BLOCK_SIZE = 1 << BLOCK_WIDTH,
    
    parameter IDLE = 0,
    parameter WAITING = 1
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
    input wire [32 * BLOCK_SIZE - 1 : 0] MC_data, // icache_block_data

    // query from IF
    input wire IF_query_en,
    input wire [31 : 0] IF_query_addr,

    // output to IF
    output reg IF_dout_en,
    output reg [31 : 0] IF_dout
);

    reg state;
    reg data_valid[CACHE_SIZE - 1 : 0];
    reg [31 : 0] cache_block_addr[CACHE_SIZE - 1 : 0];
    reg [32 * BLOCK_SIZE - 1 : 0] cache_block[CACHE_SIZE - 1 : 0];

    integer i, j;
    integer debug_counter, file;

    wire [CACHE_SIZE - 1 : 0] block_index;
    wire [BLOCK_WIDTH + 1 : 0] entry_index;
    wire [31 : 0] block_head_addr;
    assign block_index = IF_query_addr[CACHE_WIDTH + BLOCK_WIDTH + 1 : BLOCK_WIDTH + 2];
    assign entry_index = IF_query_addr[BLOCK_WIDTH + 1 : 2];
    assign block_head_addr = {IF_query_addr[CACHE_WIDTH + BLOCK_WIDTH + 1 : 2], 2'b00};

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            debug_counter = 0;
            state <= IDLE;
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                data_valid[i] <= 0;
            end
            IF_dout_en <= 0;
            IF_dout <= 0;
            MC_query_en <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            debug_counter = debug_counter + 1;
            if (state == IDLE) begin
                // handle query from IF
                IF_dout_en <= 0;
                if (IF_query_en) begin
                    if (data_valid[block_index] && cache_block_addr[block_index] == block_head_addr) begin
                        // hit
                        IF_dout_en <= 1;
                        case (entry_index)
                            0: IF_dout <= cache_block[block_index][31 : 0];
                            1: IF_dout <= cache_block[block_index][63 : 32];
                            2: IF_dout <= cache_block[block_index][95 : 64];
                            3: IF_dout <= cache_block[block_index][127 : 96];
                        endcase
                    end
                    else begin
                        // miss
                        IF_dout_en <= 0;
                        state <= WAITING;
                        MC_query_en <= 1;
                        MC_query_addr <= IF_query_addr[CACHE_WIDTH + BLOCK_WIDTH + 1 : 2];
                    end
                end
            end 
            else if (state == WAITING) begin
                // waiting data from MC
                if (MC_data_en) begin
                    // update cache
                    state <= IDLE;
                    data_valid[block_index] <= 1;
                    cache_block_addr[block_index] <= MC_query_addr;
                    cache_block[block_index] <= MC_data;
                    IF_dout_en <= 1;
                    case (entry_index)
                        0: IF_dout <= MC_data[31 : 0];
                        1: IF_dout <= MC_data[63 : 32];
                        2: IF_dout <= MC_data[95 : 64];
                        3: IF_dout <= MC_data[127 : 96];
                    endcase
                end
                else begin
                    MC_query_en <= 0;
                end
            end

            // debug, print like :
            /* [debug_counter]: [STATE]
             *                  (if MC_query_en ==1 ), MC_query_addr = [MC_query_addr]
             *                  (if IF_dout_en == 1) IF_dout = [IF_dout]
             *                  (if MC_data_en == 1) MC_data = [MC_data]
             *                  (if IF_query_en == 1) IF_query_addr = [IF_query_addr]
             */
            if (debug_counter <= 100) begin
                file = $fopen("icache_debug.txt", "a");
                $fwrite(file, "[%d]: [", debug_counter);
                case (state)
                    IDLE: $fwrite(file, "IDLE");
                    WAITING: $fwrite(file, "WAITING");
                    default: $fwrite(file, "UNKNOWN");
                endcase
                $fwrite(file, "]");
                if (MC_query_en) begin
                    $fwrite(file, " (MC_query_addr = %d)", MC_query_addr);
                end
                if (IF_dout_en) begin
                    $fwrite(file, " (IF_dout = %d)", IF_dout);
                end
                if (MC_data_en) begin
                    $fwrite(file, " (MC_data = %d)", MC_data);
                end
                if (IF_query_en) begin
                    $fwrite(file, " (IF_query_addr = %d)", IF_query_addr);
                end
                $fwrite(file, "\n");
                $fclose(file);
            end
        end
    end    




endmodule