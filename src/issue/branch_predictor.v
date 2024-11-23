// module branch_predictor.v


module branch_predictor #(

) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // update infomation from RoB

    // query from IF
    input wire query_en,

    // output to IF
    output wire data_out_en,
    output wire data_out // 0: not jump, 1: jump
);

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