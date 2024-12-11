// module dispatcher.v
// is responsible for distributing instructions to LSB/RS. 

// 暂停：sys_rst == 1 / rdy_in == 0 / flush_signal == 1

// 处理新指令的条件：RoB未满，LSB和RS未满，且不需要FLUSH

// 与RF直接交互，查询某些寄存器的状态。对于RF中busy的寄存器，会先询问RoB是否有这些结果，把尽可能多的信息发往LSB/RS

// 对于Memory相关指令：
//   发往LSB,

module Dispatcher #(


) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,


);



endmodule