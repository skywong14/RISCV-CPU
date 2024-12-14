// module register_file.v

// interface mainly with Dispatcher & RoB
// from RoB: set value, get FLUSH signal
// with Dispatcher: query {RoBEntry, rs1, rs2, rd}, return {Vj, Vk, Qj, Qk}
// rs1, rs2, rd: wire[5:0], wire[5] is valid signal
// RoBEntry: wire[RoBWIDTH:0], wire[RoBWIDTH] is valid signal


module RF #(
    parameter RoB_WIDTH = 3,
    parameter REG_SIZE = 32,
    
    parameter NON_DEP = 1 << 5
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,
    
    // FLUSH from RoB
    input wire flush_signal,

    // notified by RoB
    input wire RoB_update_en,
    input wire[5 : 0] RoB_update_reg, 
    input wire [RoB_WIDTH - 1 : 0] RoB_update_index,
    input wire [31 : 0] RoB_update_data,

    // with Dispatcher
    input wire [5 : 0] rs1, rs2, // wire[5] is valid signal
    output wire [RoB_WIDTH : 0] Qj, Qk, // wire[RoB_WIDTH] is valid signal
    output wire [31 : 0] Vj, Vk,
    
    input new_entry_en,
    input [RoB_WIDTH - 1 : 0] new_entry_robEntry,
    input [4 : 0] occupied_rd
);

    reg [31 : 0] registers[REG_SIZE - 1:0]; // value
    reg [RoB_WIDTH : 0] dependency[REG_SIZE - 1:0]; // reg[RoB_WIDTH] is valid signal

    // ATTENTION: if RoB notify RF to update and query at the same time, the update should be done first

    assign Qj = (flush_signal || rs1 == NON_DEP || RoB_update_en && dependency[rs1] == RoB_update_index) ? NON_DEP : dependency[rs1];
    assign Qk = (flush_signal || rs2 == NON_DEP || RoB_update_en && dependency[rs2] == RoB_update_index) ? NON_DEP : dependency[rs2];
    
    // if (Qj == NON_DEP && dependency[rs1] != NON_DEP) Vj = RoB_update_data;
    // else Vj = (Qj == NON_DEP) ? registers[rs1] : 0;

    assign Vj = (Qj == NON_DEP && dependency[rs1] != NON_DEP) ? RoB_update_data : ((Qj == NON_DEP) ? registers[rs1] : 0);
    assign Vk = (Qk == NON_DEP && dependency[rs2] != NON_DEP) ? RoB_update_data : ((Qk == NON_DEP) ? registers[rs2] : 0);

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            for (i = 0; i < REG_SIZE; i = i + 1) begin
                registers[i] <= 0;
                dependency[i] <= NON_DEP;
            end
        end
        else if (!rdy_in) begin
            // pause
        end 
        else if (flush_signal) begin
            // flush
                for (i = 0; i < REG_SIZE; i = i + 1) begin
                   dependency[i] <= NON_DEP;
                end
            end
        else begin
            // run
            // if RoB_update_en && dependency[RoB_update_index] == RoB_update_index, update registers[RoB_update_index] and dependency[RoB_update_index]
            if (RoB_update_en && RoB_update_reg != NON_DEP && RoB_update_reg != 6'b000000) begin
                registers[RoB_update_index] <= RoB_update_data;
                if (dependency[RoB_update_index] == RoB_update_index) begin
                    dependency[RoB_update_index] <= NON_DEP;
                end
            end

            // new entry, occcupy rd
            if (new_entry_en && occupied_rd != 5'b000000) begin
                dependency[occupied_rd] <= new_entry_robEntry;
            end
        end

    end

endmodule