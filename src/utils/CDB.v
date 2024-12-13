// module CDB.v

// broadcast datas to all modules

// [RoBIndex, Value]:
// from: LSB, RS
// to:   LSB, RS, RoB

// [flush_signal]:
// from: RoB (when commit a branch instruction)
// to:   LSB, RS, Dispatcher, IF

module CDB #(
    parameter RoB_WIDTH = 3
) (
    // [RoBIndex, Value]
    // input
    input wire LSB_update_en,
    input wire [RoB_WIDTH - 1 : 0] LSB_update_index,
    input wire [31 : 0] LSB_update_data,

    input wire RS_update_en,
    input wire [RoB_WIDTH - 1 : 0] RS_update_index,
    input wire [31 : 0] RS_update_data,

    // output
    output wire RoBEntry_update_en,
    output wire [RoB_WIDTH - 1 : 0] RoBEntry_update_index,
    output wire [31 : 0] RoBEntry_update_data
);

    assign RoBEntry_update_en = RS_update_data || LSB_update_data;
    assign RoBEntry_update_index = RS_update_data ? RS_update_index : LSB_update_index;
    assign RoBEntry_update_data = RS_update_data ? RS_update_data : LSB_update_data;
    
endmodule