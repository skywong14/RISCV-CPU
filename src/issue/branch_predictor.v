// module branch_predictor.v

// 00: Strongly Not Taken
// 01: Weakly Not Taken
// 10: Weakly Taken
// 11: Strongly Taken

module branch_predictor #(
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

    // query from IF
    input wire query_en,
    input wire [31 : 0] query_PC,

    // output to IF
    output reg result_out_en,
    output reg result_out // 0: not jump, 1: jump
);
    reg [1 : 0] regList[SIZE - 1 : 0];

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            result_out_en <= 0;
            result_out <= 0;
            for (i = 0; i < SIZE; i = i + 1) begin
                regList[i] <= 2'b10;
            end
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            // update
            if (update_en) begin
                if (update_result) begin
                    // jump, add
                    if (regList[update_PC[WIDTH + 1 : 2]] < 3) begin
                        regList[update_PC[WIDTH + 1 : 2]] <= regList[update_PC[WIDTH + 1 : 2]] + 1;
                    end
                end
                else begin
                    // not jump, dec
                    result_out <= 0;
                    if (regList[update_PC[WIDTH + 1 : 2]] > 0) begin
                        regList[update_PC[WIDTH + 1 : 2]] <= regList[update_PC[WIDTH + 1 : 2]] - 1;
                    end
                end
            end
            
            // query
            if (query_en) begin
                result_out_en <= 1;
                if (regList[query_PC[WIDTH + 1 : 2]] > 1) begin
                    result_out <= 1;
                end
                else begin
                    result_out <= 0;
                end
            end 
            else begin
                result_out_en <= 0;
            end

        end
    end

endmodule