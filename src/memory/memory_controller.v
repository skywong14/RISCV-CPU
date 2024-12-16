// module memory_controller.v

// WORK_STATE: 0: IDLE, 1: WRITING, 2: READING

// load datas [head_addr, head_addr + length) from memory


module Memory_Controller #(
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
    input wire [7 : 0] ram_din, // data from memory
    output reg [7 : 0] ram_dout, // data to memory
    output reg [17 : 0] ram_addr_in, // ram(a_in), address input to memory
    output reg ram_query_type, // ram(r_nw_in), read/write select (read: 1, write: 0)

    // icache
    input wire icache_query_en,
    input wire [31 : 0] head_addr, // head address to read 
    output reg icache_block_en, // 1 if data is ready
    output reg [31 : 0] icache_block_data, // 4 bytes data, two blocks

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

    reg wait_to_comfirm;

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
            ram_query_type <= 1;
            ram_dout <= 0;
            wait_to_comfirm <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (state == IDLE) begin
                LSB_result_en <= 0;
                icache_block_en <= 0;
                if (wait_to_comfirm) begin
                    // wait one cycle for ICache/LSB to cancel query_en
                    wait_to_comfirm <= 0;
                end
                else
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
                        ram_dout <= LSB_query_data[7 : 0];
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
                    r_length <= 4;
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
                        wait_to_comfirm <= 1;
                        LSB_result_en <= 1;
                        uart_state <= 0;
                        ram_addr_in <= 0;
                    end
                    else begin
                        case (w_cur)
                            1: ram_dout <= w_data[15 : 8];
                            2: ram_dout <= w_data[23 : 16];
                            3: ram_dout <= w_data[31 : 24];
                        endcase
                        w_cur <= w_cur + 1;
                        ram_addr_in <= ram_addr_in + 1;
                    end
                end
            end 
            else if (state == LSB_READING) begin
                // read one word/halfword/byte from memory
                if (r_cur == r_length + 1) begin
                    // finish reading
                    state <= IDLE;
                    wait_to_comfirm <= 1;
                    LSB_result_en <= 1;
                    uart_state <= 0;
                    ram_addr_in <= 0;
                end 
                else begin
                    // read data from memory
                    case (r_cur)
                        1: LSB_result_data[7 : 0] <= ram_din;
                        2: LSB_result_data[15 : 8] <= ram_din;
                        3: LSB_result_data[23 : 16] <= ram_din;
                        4: LSB_result_data[31 : 24] <= ram_din;
                    endcase
                    r_cur <= r_cur + 1;
                    if (r_cur < r_length) begin
                        ram_addr_in <= ram_addr_in + 1;
                    end
                end
            end
            else if (state == ICACHE_READING) begin
                // read a block 
                if (r_cur == r_length + 1) begin
                    state <= IDLE;
                    wait_to_comfirm <= 1;
                    icache_block_en <= 1;
                    ram_addr_in <= 0;
                end 
                else begin
                    case (r_cur)
                        1: icache_block_data[7 : 0] <= ram_din;
                        2: icache_block_data[15 : 8] <= ram_din;
                        3: icache_block_data[23 : 16] <= ram_din;
                        4: icache_block_data[31 : 24] <= ram_din;
                    endcase
                    r_cur <= r_cur + 1;
                    if (r_cur < r_length) begin
                        ram_addr_in <= ram_addr_in + 1;
                    end
                end    
            end    
        end
    end    



endmodule