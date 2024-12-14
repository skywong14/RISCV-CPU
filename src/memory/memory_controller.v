// module memory_controller.v

// WORK_STATE: 0: IDLE, 1: WRITING, 2: READING

// load datas [head_addr, head_addr + length) from memory


module Memory_Controller #(

    parameter BLOCK_WIDTH = 2, // 4 words, 16 bytes in a block(i.e. 4 instructions per block), this parameter should not be modified
    parameter BLOCK_SIZE = 1 << BLOCK_WIDTH, 

    parameter IDLE = 0,
    parameter LSB_WRITING = 1,
    parameter LSB_READING = 2,
    parameter ICACHE_READING = 3
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    input wire uart_isFull, // (io_buffer_full signal from cpu): 1 if uart buffer is full

    // memory
    input wire [7 : 0] ram_dout, // data output from memory
    output reg [7 : 0] ram_din, // data input to memory
    output reg [16 : 0] ram_addr_in, // ram(a_in), address input to memory
    output reg ram_query_type, // ram(r_nw_in), read/write select (read: 1, write: 0)

    // icache
    input wire icache_query_en,
    input wire [31 : 0] head_addr, // head address to read 
    output reg icache_block_en, // 1 if data is ready
    output reg [32 * BLOCK_SIZE - 1 : 0] icache_block_data, // block data

    // LSB
    input wire LSB_query_en,
    input wire LSB_query_type, // 0: read, 1: write
    input wire [31 : 0] LSB_query_addr, // address to read/write, valid address ranging from 0x0 to 0x20000 or 0x30000 / 0x30004
    input wire [1 : 0] LSB_data_width, // 0:byte, 1:halfword, 2:word (1/2/4 bytes)
    input wire [31 : 0] LSB_query_data, // data to write
    output reg LSB_result_en, // 1 if read data is ready, or write data is written
    output reg [31 : 0] LSB_result_data // read data
);

    reg [1 : 0] state;
    reg last_module; // 0: LSB, 1: ICache

    wire uart_write_delay;
    reg uart_state; // 0: IDLE / READING, 1: WRITING
    assign uart_write_delay = uart_isFull && uart_state; // 1 if (uart buffer full) && (writing to 0x30000 / 0x30004)

    // read mode
    reg [31 : 0] r_cur, r_length;

    // write mode
    reg [31 : 0] w_data;
    reg [31 : 0] w_cur, w_length;

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            last_module <= 0;
            LSB_result_en <= 0;
            LSB_result_data <= 0;
            uart_state <= 0;
            ram_addr_in <= 0;
            icache_block_en <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (state == IDLE) begin
                LSB_result_en <= 0;
                icache_block_en <= 0;
                if (LSB_query_en && (!icache_query_en || last_module == 1)) begin
                    // work on query from LSB
                    if (LSB_query_type) begin
                        // LSB write
                        if (LSB_query_addr == 32'h30000 || LSB_query_addr == 32'h30004) begin
                            // write to uart
                            uart_state <= 1;
                        end
                        else begin
                            // write to memory
                            uart_state <= 0;
                        end
                        state <= LSB_WRITING;
                        w_data <= LSB_query_data;
                        w_cur <= 0;
                        w_length <= 1 << LSB_data_width;
                        ram_query_type <= 0;
                        ram_addr_in <= LSB_query_addr;
                        // also write the first byte to memory
                        ram_din <= LSB_query_data[7 : 0];
                    end
                    else begin
                        // LSB read
                        // no need to differentiate 32'h3000x or lower addresses
                        state <= LSB_READING;
                        uart_state <= 0;
                        r_cur <= 0;
                        r_length <= 1 << LSB_data_width;
                        ram_query_type <= 1;
                        ram_addr_in <= LSB_query_addr;
                    end
                end 
                else if (icache_query_en) begin
                    // work on query from ICache
                    state <= ICACHE_READING;
                    r_cur <= 0;
                    r_length <= BLOCK_SIZE << 2;
                    ram_query_type <= 1;
                    ram_addr_in <= head_addr;
                end
            end
            else if (state == LSB_WRITING) begin
                if (uart_write_delay) begin
                    // wait for uart buffer 
                end
                else begin
                    // write to memory
                    if (w_cur == w_length) begin
                        // finish writing
                        state <= IDLE;
                        LSB_result_en <= 1;
                        uart_state <= 0;
                        ram_addr_in <= 0;
                    end
                    else begin
                        case (w_cur)
                            1: ram_din <= w_data[15 : 8];
                            2: ram_din <= w_data[23 : 16];
                            3: ram_din <= w_data[31 : 24];
                        endcase
                        w_cur <= w_cur + 1;
                        ram_addr_in <= ram_addr_in + 1;
                    end
                end
            end 
            else if (state == LSB_READING) begin
                // read one word/halfword/byte from memory
                if (r_cur == r_length) begin
                    // finish reading
                    state <= IDLE;
                    LSB_result_en <= 1;
                    uart_state <= 0;
                    ram_addr_in <= 0;
                end 
                else begin
                    // read data from memory
                    case (r_cur)
                        0: LSB_result_data[7 : 0] <= ram_dout;
                        1: LSB_result_data[15 : 8] <= ram_dout;
                        2: LSB_result_data[23 : 16] <= ram_dout;
                        3: LSB_result_data[31 : 24] <= ram_dout;
                    endcase
                    r_cur <= r_cur + 1;
                    ram_addr_in <= ram_addr_in + 1;
                end
            end
            else if (state == ICACHE_READING) begin
                // read a block 
                if (r_cur == r_length) begin
                    state <= IDLE;
                    icache_block_en <= 1;
                    ram_addr_in <= 0;
                end 
                else begin
                    case (r_cur)
                        0: icache_block_data[7 : 0] <= ram_dout;
                        1: icache_block_data[15 : 8] <= ram_dout;
                        2: icache_block_data[23 : 16] <= ram_dout;
                        3: icache_block_data[31 : 24] <= ram_dout;
                        4: icache_block_data[39 : 32] <= ram_dout;
                        5: icache_block_data[47 : 40] <= ram_dout;
                        6: icache_block_data[55 : 48] <= ram_dout;
                        7: icache_block_data[63 : 56] <= ram_dout;
                        8: icache_block_data[71 : 64] <= ram_dout;
                        9: icache_block_data[79 : 72] <= ram_dout;
                        10: icache_block_data[87 : 80] <= ram_dout;
                        11: icache_block_data[95 : 88] <= ram_dout;
                        12: icache_block_data[103 : 96] <= ram_dout;
                        13: icache_block_data[111 : 104] <= ram_dout;
                        14: icache_block_data[119 : 112] <= ram_dout;
                        15: icache_block_data[127 : 120] <= ram_dout;
                    endcase
                    r_cur <= r_cur + 1;
                    ram_addr_in <= ram_addr_in + 1;
                end    
            end    
        end
    end    



endmodule