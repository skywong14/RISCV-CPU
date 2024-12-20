// module branch_predictor.v

// 00: Strongly Not Taken
// 01: Weakly Not Taken
// 10: Weakly Taken
// 11: Strongly Taken

module Branch_Predictor #(
    parameter BP_WIDTH = 2,
    parameter SIZE = 1 << BP_WIDTH
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
    input wire query_en,
    input wire [31 : 0] query_PC,
    output wire result_out // 0: not jump, 1: jump
);
    reg [1 : 0] regList[SIZE - 1 : 0];
    reg [1 : 0] single; // debug

    wire [BP_WIDTH - 1 : 0] valid_part;
    assign valid_part = query_PC[BP_WIDTH : 1];

    assign result_out = single[1];

    // always@(*) begin
            // result_out = regList[valid_part][1];
        // if (query_en) begin 
            // result_out = regList[valid_part][1];
        // end else begin
            // result_out = 1'b0;
        // end
    // end

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            for (i = 0; i < SIZE; i = i + 1) begin
                regList[i] <= 2'b10;
            end
            single <= 2'b10;
        end
        else if (!rdy_in) begin
            // pause
        end
        else begin
            // run
            if (update_en) begin
                if (update_result) begin
                    // jump, add
                    if (single < 3)
                        single <= single + 1;
                end
                else begin
                    // not jump, dec
                    if (single > 0)
                        single <= single - 1;
                end
            //     if (update_result) begin
            //         // jump, add
            //         if (regList[update_PC[BP_WIDTH + 1 : 2]] < 3) begin
            //             regList[update_PC[BP_WIDTH + 1 : 2]] <= regList[update_PC[BP_WIDTH + 1 : 2]] + 1;
            //         end
            //     end
            //     else begin
            //         // not jump, dec
            //         if (regList[update_PC[BP_WIDTH + 1 : 2]] > 0) begin
            //             regList[update_PC[BP_WIDTH + 1 : 2]] <= regList[update_PC[BP_WIDTH + 1 : 2]] - 1;
            //         end
            //     end
            end
        end
    end

endmodule