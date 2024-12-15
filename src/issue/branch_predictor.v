// module branch_predictor.v

// 00: Strongly Not Taken
// 01: Weakly Not Taken
// 10: Weakly Taken
// 11: Strongly Taken

module Branch_Predictor #(
    parameter WIDTH = 2,
    parameter SIZE = 1 << WIDTH
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // update infomation from RoB
    input wire update_en,
    input wire [31 : 0] update_PC,
    input wire update_result, // 0: not jump, 1: jump

    // with IF
    input wire [31 : 0] query_PC,
    output wire result_out // 0: not jump, 1: jump
);
    reg [1 : 0] regList[SIZE - 1 : 0];

    assign result_out = regList[query_PC[WIDTH + 1 : 2]][1];

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            for (i = 0; i < SIZE; i = i + 1) begin
                regList[i] <= 2'b10;
            end
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (update_en) begin
                if (update_result) begin
                    // jump, add
                    if (regList[update_PC[WIDTH + 1 : 2]] < 3) begin
                        regList[update_PC[WIDTH + 1 : 2]] <= regList[update_PC[WIDTH + 1 : 2]] + 1;
                    end
                end
                else begin
                    // not jump, dec
                    if (regList[update_PC[WIDTH + 1 : 2]] > 0) begin
                        regList[update_PC[WIDTH + 1 : 2]] <= regList[update_PC[WIDTH + 1 : 2]] - 1;
                    end
                end
            end
        end
    end

endmodule