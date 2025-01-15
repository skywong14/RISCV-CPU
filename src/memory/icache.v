// module icache.v

//  address : ... | <CACHE_WIDTH> | 0/1

module ICache #(
    parameter CACHE_WIDTH = 5, // 32 blocks in cache

    parameter CACHE_SIZE = 1 << CACHE_WIDTH,
    
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
    input wire [31 : 0] MC_data, // icache_block_data, two blocks

    // query from IF
    input wire IF_query_en,
    input wire [31 : 0] IF_query_addr,

    // output to IF
    output reg IF_dout_en,
    output reg [31 : 0] IF_dout,

    // flush signal
    input wire flush_signal
);

    reg state;
    reg data_valid[CACHE_SIZE - 1 : 0];
    reg [31 : 0] cache_block_addr[CACHE_SIZE - 1 : 0];
    reg [15 : 0] cache_block[CACHE_SIZE - 1 : 0]; // [15 : 0] in one block, 2 bytes

    integer i, j;

    wire [CACHE_WIDTH - 1 : 0] left_index, right_index;

    assign left_index = IF_query_addr[CACHE_WIDTH + 1 : 1];
    assign right_index = (left_index + 1) & (CACHE_SIZE - 1);

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            IF_dout_en <= 0;
            IF_dout <= 0;
            MC_query_en <= 0;
            MC_query_addr <= 0;
            for (i = 0; i < CACHE_SIZE; i = i + 1) begin
                data_valid[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause
        end 
        else if (flush_signal) begin
            // flush
            state <= IDLE;
            IF_dout_en <= 0;
            IF_dout <= 0;
            MC_query_en <= 0;
            MC_query_addr <= 0;
        end
        else begin
            // run
            if (state == IDLE) begin
                // handle query from IF
                IF_dout_en <= 0;
                IF_dout <= 0;

                if (IF_query_en) begin
                    if (data_valid[left_index] && data_valid[right_index]
                        && cache_block_addr[left_index] == IF_query_addr
                        && cache_block_addr[right_index] == (IF_query_addr + 2)) begin
                        // hit left half && right half, return data
                        IF_dout_en <= 1;
                        IF_dout <= {cache_block[right_index], cache_block[left_index]};
                    end
                    else begin
                        state <= WAITING;
                        MC_query_en <= 1;
                        MC_query_addr <= IF_query_addr;
                    end
                end
            end
            else if (state == WAITING) begin
                // waiting data from MC
                if (MC_data_en) begin
                    // update cache
                    state <= IDLE;

                    data_valid[left_index] <= 1;
                    cache_block_addr[left_index] <= IF_query_addr;
                    cache_block[left_index] <= MC_data[15 : 0];

                    data_valid[right_index] <= 1;
                    cache_block_addr[right_index] <= IF_query_addr + 2;
                    cache_block[right_index] <= MC_data[31 : 16];

                    // return data
                    IF_dout_en <= 1;
                    IF_dout <= MC_data;

                    MC_query_en <= 0;
                    MC_query_addr <= 0;
                end
            end
        end
    end    




endmodule