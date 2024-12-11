// module memory_controller.v

// WORK_STATE: 0: IDLE, 1: WRITING, 2: READING

// load datas [head_addr, head_addr + length) from memory


module Memory_Controller #(



    parameter IDLE = 0,
    parameter WRITING = 1,
    parameter READING = 2
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    input wire uart_isFull, // (io_buffer_full signal from cpu): 1 if uart buffer is full

    // memory


    // icache
    input wire icache_query_en,

    // LSB
    input wire LSB_query_en,
    input wire LSB_query_type, // 0: read, 1: write
    input wire [31 : 0] LSB_query_addr, // address to read/write, valid address ranging from 0x0 to 0x20000 or 0x30000 / 0x30004
    input wire [2 : 0] LSB_data_length, // 0:byte, 1:halfword, 2:word
    input wire [31 : 0] LSB_query_data, // data to write
    output reg LSB_result_en, // 1 if read data is ready, or write data is written
    output reg [31 : 0] LSB_result_data // read data
);

    reg [1 : 0] state;
    reg last_module; // 0: LSB, 1: ICache

    wire uart_write_delay;
    assign uart_write_delay = (uart_isFull) && (LSB_query_en && LSB_query_type && (LSB_query_addr == 32'h30000 || LSB_query_addr == 32'h30004)); // 1 if (uart buffer full) && (writing to 0x30000 / 0x30004)

 always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            state <= IDLE;
            last_module <= 0;
            LSB_result_en <= 0;
            LSB_result_data <= 0;
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (state == IDLE) begin
                if (LSB_query_en && (!icache_query_en || last_module == 1)) begin
                    // work on query from LSB
                    if (LSB_query_type) begin
                        // LSB write
                        if (LSB_query_addr == 32'h30000 || LSB_query_addr == 32'h30004) begin
                            // write to uart

                        end
                        else begin
                            // write to memory

                        end
                    end
                    else begin
                        // LSB read
                        if (LSB_query_addr == 32'h30000 || LSB_query_addr == 32'h30004) begin
                            // read from uart

                        end
                        else begin
                            // read from memory

                        end
                    end
                end 
                else if (icache_query_en) begin
                    // work on query from ICache

                end
            end
            else if (state == WRITING) begin
                // todo
            end 
            else if (state == READING) begin
                // with infomation: cur_addr, cur (from 0 to length - 1), length
                // read datas until cur == length
                if (cur == length) begin
                    state <= IDLE;
                    // todo: return datas
                end 
                else begin 
                    // read data from memory
                    cur <= cur + 1;
                    cur_addr <= cur_addr + 4;
                    // todo
                end
            end
        end
    end    



endmodule