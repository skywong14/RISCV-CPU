// module register_file.v

// interact mainly with Dispatcher & RoB
// from RoB: set value, get FLUSH signal
// with Dispatcher: query {RoBEntry, rs1, rs2, rd}, return {Vj, Vk, Qj, Qk}
// rs1, rs2, rd: wire[5:0], wire[5] is valid signal
// RoBEntry: wire[RoBWIDTH:0], wire[RoBWIDTH] is valid signal


module RF #(
    parameter RoB_WIDTH = 3,
    parameter REG_NUM = 32,
    
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,
    
    // FLUSH from RoB
    input wire flush_signal,

    // notify by RoB
    input wire RoB_update_en,
    input wire [RoB_WIDTH - 1 : 0] RoB_update, // RoBEntry index
    input wire [31 : 0] RoB_update_data, // update value

    // with Dispatcher
    input wire query_en,
    input wire [RoB_WIDTH : 0] query,
    output wire [31 : 0] rs1, rs2, rd,
    output wire [RoB_WIDTH : 0] Vj, Vk, Qj, Qk // reg[RoB_WIDTH] is valid signal

);

    reg [REG_NUM - 1 : 0] registers[REG_SIZE - 1:0]; // value
    reg [RoB_WIDTH : 0] dependency[REG_SIZE - 1:0]; // reg[RoB_WIDTH] is valid signal

    assign Vj = 
    assign Vk =
    assign Qj =
    assign Qk =

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