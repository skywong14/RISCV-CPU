// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu #(
  parameter RoB_WIDTH = 1,
  parameter BLOCK_WIDTH = 2,
  parameter BLOCK_SIZE = 1 << BLOCK_WIDTH, 
  parameter LSB_WIDTH = 3,
  parameter RS_WIDTH = 2,
  parameter BP_WIDTH = 2
) (
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full, this signal will be sent to memory_controller
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

// output by LSB
wire LSB_mem_query_en;
wire LSB_mem_query_type;
wire [31 : 0] LSB_mem_query_addr;
wire [1 : 0] LSB_mem_data_width;
wire [31 : 0] LSB_mem_query_data;
wire LSB_RoB_write_en;
wire [RoB_WIDTH - 1 : 0] LSB_RoB_write_index;
wire [31 : 0] LSB_RoB_write_data;
wire [RoB_WIDTH : 0] LSB_lstCommittedWrite;
wire LSB_isFull;

// output by RoB
wire RoB_RF_update_en;
wire [4 : 0] RoB_RF_update_reg;
wire [RoB_WIDTH - 1 : 0] RoB_RF_update_index;
wire [31 : 0] RoB_RF_update_data;
wire RoB_jalr_feedback_en;
wire [31 : 0] RoB_jalr_feedback_data;
wire RoB_branch_fail_en;
wire [31 : 0] RoB_correct_next_pc;
wire RoB_branch_predictor_en;
wire RoB_isFull;
wire [RoB_WIDTH - 1 : 0] RoB_new_entry_index;
wire RoB_flush_signal;

// output by RS
wire RS_RS_update_en;
wire [RoB_WIDTH - 1 : 0] RS_RS_update_index;
wire [31 : 0] RS_RS_update_data;
wire RS_isEmpty;
wire RS_isFull;

// output by Branch_Predictor
wire branch_predictor_result_out;

// output by Dispatcher
wire Dispatcher_new_instruction_able;

wire Dispatcher_RS_new_Entry_en;
wire [RoB_WIDTH - 1 : 0] Dispatcher_RS_robEntry;
wire [6 : 0] Dispatcher_RS_opcode;
wire [31 : 0] Dispatcher_RS_Vj;
wire [31 : 0] Dispatcher_RS_Vk;
wire [RoB_WIDTH : 0] Dispatcher_RS_Qj;
wire [RoB_WIDTH : 0] Dispatcher_RS_Qk;
wire [31 : 0] Dispatcher_RS_imm;
wire [31 : 0] Dispatcher_RS_pc;

wire Dispatcher_LSB_newEntry_en;
wire [RoB_WIDTH - 1 : 0] Dispatcher_LSB_RoBIndex;
wire [6 : 0] Dispatcher_LSB_opcode;
wire [31 : 0] Dispatcher_LSB_Vj;
wire [31 : 0] Dispatcher_LSB_Vk;
wire [RoB_WIDTH : 0] Dispatcher_LSB_Qj;
wire [RoB_WIDTH : 0] Dispatcher_LSB_Qk;
wire [31 : 0] Dispatcher_LSB_imm;
wire [31 : 0] Dispatcher_LSB_pc;

wire Dispatcher_RoB_newEntry_en;
wire [6 : 0] Dispatcher_RoB_opcode;
wire [4 : 0] Dispatcher_RoB_rd;
wire [31 : 0] Dispatcher_RoB_pc;
wire [31 : 0] Dispatcher_RoB_next_pc;
wire Dispatcher_RoB_predict_result;
wire Dispatcher_RoB_already_ready;
wire [31 : 0] Dispatcher_RoB_ready_data;

wire [4 : 0] Dispatcher_RF_rs1;
wire [4 : 0] Dispatcher_RF_rs2;
wire Dispatcher_RF_newEntry_en;
wire [RoB_WIDTH - 1 : 0] Dispatcher_RF_newEntry_robIndex;
wire [4 : 0] Dispatcher_RF_occupied_rd;

// output by Instruction_Fetcher
wire IF_icache_query_en;
wire [31 : 0] IF_icache_query_pc;
wire IF_new_instruction_en;
wire [31 : 0] IF_new_pc;
wire [6 : 0] IF_new_opcode;
wire [4 : 0] IF_new_rs1;
wire [4 : 0] IF_new_rs2;
wire [4 : 0] IF_new_rd;
wire [31 : 0] IF_new_imm;
wire IF_new_predict_result;
wire [31 : 0] IF_predict_query_pc;

// output by icache
wire icache_MC_query_en;
wire [31 : 0] icache_MC_query_addr;
wire icache_IF_dout_en;
wire [31 : 0] icache_IF_dout;

// output by Memory_Controller
wire [7 : 0] MC_ram_din;
wire [16 : 0] MC_ram_addr_in;
wire MC_ram_query_type;
wire MC_icache_block_en;
wire [32 * BLOCK_SIZE - 1 : 0] MC_icache_block_data;
wire MC_LSB_result_en;
wire [31 : 0] MC_LSB_result_data;

// output by Register_File
wire [RoB_WIDTH : 0] RF_Qj;
wire [RoB_WIDTH : 0] RF_Qk;
wire [31 : 0] RF_Vj;
wire [31 : 0] RF_Vk;

// output by CDB
wire CDB_RoBEntry_update_en;
wire [RoB_WIDTH - 1 : 0] CDB_RoBEntry_update_index;
wire [31 : 0] CDB_RoBEntry_update_data;

RoB #(
  .RoB_WIDTH(RoB_WIDTH)
) RoB_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .new_entry_en(Dispatcher_RoB_newEntry_en),
  .new_entry_opcode(Dispatcher_RoB_opcode),
  .new_entry_rd(Dispatcher_RoB_rd),
  .new_entry_pc(Dispatcher_RoB_pc),
  .new_entry_next_pc(Dispatcher_RoB_next_pc),
  .new_entry_predict_result(Dispatcher_RoB_predict_result),
  .already_ready(Dispatcher_RoB_already_ready),
  .ready_data(Dispatcher_RoB_ready_data),

  .CDB_update_en(CDB_RoBEntry_update_en),
  .CDB_update_index(CDB_RoBEntry_update_index),
  .CDB_update_data(CDB_RoBEntry_update_data),

  .RF_update_en(RoB_RF_update_en),
  .RF_update_reg(RoB_RF_update_reg),
  .RF_update_index(RoB_RF_update_index),
  .RF_update_data(RoB_RF_update_data),
  .jalr_feedback_en(RoB_jalr_feedback_en),
  .jalr_feedback_data(RoB_jalr_feedback_data),
  .branch_fail_en(RoB_branch_fail_en),
  .correct_next_pc(RoB_correct_next_pc),
  .branch_predictor_en(RoB_branch_predictor_en),
  .branch_predictor_pc(IF_predict_query_pc),
  .branch_predictor_result(branch_predictor_result_out),
  .isFull(RoB_isFull),
  .new_entry_index(RoB_new_entry_index),
  .flush_signal(RoB_flush_signal)
);

Branch_Predictor #(
  .BP_WIDTH(BP_WIDTH)
) Branch_Predictor_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .update_en(RoB_branch_predictor_en),
  .update_PC(IF_predict_query_pc),
  .update_result(RoB_branch_predictor_en),
  .query_PC(IF_predict_query_pc),
  .result_out(branch_predictor_result_out)
);

Dispatcher #(
  .RoB_WIDTH(RoB_WIDTH),
  .LSB_WIDTH(LSB_WIDTH),
  .RS_WIDTH(RS_WIDTH)
) Dispatcher_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .new_instruction_en(IF_new_instruction_en),
  .new_pc(IF_new_pc),
  .new_opcode(IF_new_opcode),
  .new_rs1(IF_new_rs1),
  .new_rs2(IF_new_rs2),
  .new_rd(IF_new_rd),
  .new_imm(IF_new_imm),
  .new_predict_result(IF_new_predict_result),
  .new_instruction_able(Dispatcher_new_instruction_able),

  .RS_newEntry_en(Dispatcher_RS_new_Entry_en),
  .RS_robEntry(Dispatcher_RS_robEntry),
  .RS_opcode(Dispatcher_RS_opcode),
  .RS_Vj(Dispatcher_RS_Vj),
  .RS_Vk(Dispatcher_RS_Vk),
  .RS_Qj(Dispatcher_RS_Qj),
  .RS_Qk(Dispatcher_RS_Qk),
  .RS_imm(Dispatcher_RS_imm),
  .RS_pc(Dispatcher_RS_pc),
  .RS_isFull(RS_isFull),
  
  .LSB_newEntry_en(Dispatcher_LSB_newEntry_en),
  .LSB_RoBIndex(Dispatcher_LSB_RoBIndex),
  .LSB_opcode(Dispatcher_LSB_opcode),
  .LSB_Vj(Dispatcher_LSB_Vj),
  .LSB_Vk(Dispatcher_LSB_Vk),
  .LSB_Qj(Dispatcher_LSB_Qj),
  .LSB_Qk(Dispatcher_LSB_Qk),
  .LSB_imm(Dispatcher_LSB_imm),
  .LSB_pc(Dispatcher_LSB_pc),
  .LSB_isFull(LSB_isFull),

  .RoB_isFull(RoB_isFull),
  .RoB_newEntryIndex(RoB_new_entry_index),
  .RoB_flush_signal(RoB_flush_signal),
  .RoB_newEntry_en(Dispatcher_RoB_newEntry_en),
  .RoB_opcode(Dispatcher_RoB_opcode),
  .RoB_rd(Dispatcher_RoB_rd),
  .RoB_pc(Dispatcher_RoB_pc),
  .RoB_next_pc(Dispatcher_RoB_next_pc),
  .RoB_predict_result(Dispatcher_RoB_predict_result),
  .RoB_already_ready(Dispatcher_RoB_already_ready),
  .RoB_ready_data(Dispatcher_RoB_ready_data),

  .RF_rs1(Dispatcher_RF_rs1),
  .RF_rs2(Dispatcher_RF_rs2),
  .RF_Qj(RF_Qj),
  .RF_Qk(RF_Qk),
  .RF_Vj(RF_Vj),
  .RF_Vk(RF_Vk),
  .RF_newEntry_en(Dispatcher_RF_newEntry_en),
  .RF_newEntry_robIndex(Dispatcher_RF_newEntry_robIndex),
  .RF_occupied_rd(Dispatcher_RF_occupied_rd)
);

Instruction_Fetcher #(
  .RoB_WIDTH(RoB_WIDTH)
) Instruction_Fetcher_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .icache_query_en(IF_icache_query_en),
  .icache_query_pc(IF_icache_query_pc),
  .icache_data_en(icache_IF_dout_en),
  .icache_data(icache_IF_dout),
  .rob_isFull(RoB_isFull),
  .new_entry_index(RoB_new_entry_index),
  .jalr_result_en(RoB_jalr_feedback_en),
  .jalr_result(RoB_jalr_feedback_data),
  .correct_next_pc(RoB_correct_next_pc),
  .new_instruction_able(Dispatcher_new_instruction_able),
  .new_instruction_en(IF_new_instruction_en),
  .new_pc(IF_new_pc),
  .new_opcode(IF_new_opcode),
  .new_rs1(IF_new_rs1),
  .new_rs2(IF_new_rs2),
  .new_rd(IF_new_rd),
  .new_imm(IF_new_imm),
  .new_predict_result(IF_new_predict_result),
  .predict_query_pc(IF_predict_query_pc),
  .predict_result_en(branch_predictor_result_out),
  .predict_result(branch_predictor_result_out)
);

ICache #(
  .BLOCK_WIDTH(BLOCK_WIDTH)
) ICache_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .MC_query_en(icache_MC_query_en),
  .MC_query_addr(icache_MC_query_addr),
  .MC_data_en(MC_icache_block_en),
  .MC_data(MC_icache_block_data),
  .IF_query_en(IF_icache_query_en),
  .IF_query_addr(IF_icache_query_pc),
  .IF_dout_en(icache_IF_dout_en),
  .IF_dout(icache_IF_dout)
);

Memory_Controller #(
  .BLOCK_WIDTH(BLOCK_WIDTH)
) Memory_Controller_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .uart_isFull(io_buffer_full),
  .ram_dout(mem_din),
  .ram_din(MC_ram_din),
  .ram_addr_in(MC_ram_addr_in),
  .ram_query_type(MC_ram_query_type),
  .icache_query_en(icache_MC_query_en),
  .head_addr(icache_MC_query_addr),
  .icache_block_en(MC_icache_block_en),
  .icache_block_data(MC_icache_block_data),
  .LSB_query_en(LSB_mem_query_en),
  .LSB_query_type(LSB_mem_query_type),
  .LSB_query_addr(LSB_mem_query_addr),
  .LSB_data_width(LSB_mem_data_width),
  .LSB_query_data(LSB_mem_query_data),
  .LSB_result_en(MC_LSB_result_en),
  .LSB_result_data(MC_LSB_result_data)
);

RF #(
  .RoB_WIDTH(RoB_WIDTH)
) RF_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .flush_signal(RoB_flush_signal),
  .RoB_update_en(RoB_RF_update_en),
  .RoB_update_reg(RoB_RF_update_reg),
  .RoB_update_index(RoB_RF_update_index),
  .RoB_update_data(RoB_RF_update_data),
  .rs1(Dispatcher_RF_rs1),
  .rs2(Dispatcher_RF_rs2),
  .Qj(RF_Qj),
  .Qk(RF_Qk),
  .Vj(RF_Vj),
  .Vk(RF_Vk),
  .new_entry_en(Dispatcher_RF_newEntry_en),
  .new_entry_robEntry(Dispatcher_RF_newEntry_robIndex),
  .occupied_rd(Dispatcher_RF_occupied_rd)
);

CDB #(
  .RoB_WIDTH(RoB_WIDTH)
) CDB_module (
  .LSB_update_en(MC_LSB_result_en),
  .LSB_update_index(LSB_RoB_write_index),
  .LSB_update_data(MC_LSB_result_data),
  .RS_update_en(RS_RS_update_en),
  .RS_update_index(RS_RS_update_index),
  .RS_update_data(RS_RS_update_data),
  .RoBEntry_update_en(CDB_RoBEntry_update_en),
  .RoBEntry_update_index(CDB_RoBEntry_update_index),
  .RoBEntry_update_data(CDB_RoBEntry_update_data)
);

LSB #(
  .RoB_WIDTH(RoB_WIDTH),
  .LSB_WIDTH(LSB_WIDTH)
) LSB_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .mem_reply_en(MC_LSB_result_en),
  .mem_reply_data(MC_LSB_result_data),
  .mem_query_en(LSB_mem_query_en),
  .mem_query_type(LSB_mem_query_type),
  .mem_query_addr(LSB_mem_query_addr),
  .mem_data_width(LSB_mem_data_width),
  .mem_query_data(LSB_mem_query_data),

  .new_entry_en(Dispatcher_RS_new_Entry_en),
  .new_entry_RoBIndex(Dispatcher_RS_robEntry),
  .new_entry_opcode(Dispatcher_RS_opcode),
  .new_entry_Vj(Dispatcher_RS_Vj),
  .new_entry_Vk(Dispatcher_RS_Vk),
  .new_entry_Qj(Dispatcher_RS_Qj),
  .new_entry_Qk(Dispatcher_RS_Qk),
  .new_entry_imm(Dispatcher_RS_imm),
  .new_entry_pc(Dispatcher_RS_pc),

  .RoB_update_en(CDB_RoBEntry_update_en),
  .RoB_update_index(CDB_RoBEntry_update_index),
  .RoB_update_data(CDB_RoBEntry_update_data),
  .RoB_write_en(LSB_RoB_write_en),
  .RoB_write_index(LSB_RoB_write_index),
  .RoB_write_data(LSB_RoB_write_data),

  .RoB_headIndex(RoB_new_entry_index),
  .lstCommittedWrite(LSB_lstCommittedWrite),
  .flush_signal(RoB_flush_signal),
  .isFull(LSB_isFull)
);

Reservation_Station #(
  .RoB_WIDTH(RoB_WIDTH),
  .RS_WIDTH(RS_WIDTH)
) RS_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),

  .new_entry_en(Dispatcher_RS_new_Entry_en),
  .new_entry_robEntry(Dispatcher_RS_robEntry),
  .new_entry_opcode(Dispatcher_RS_opcode),
  .new_entry_Vj(Dispatcher_RS_Vj),
  .new_entry_Vk(Dispatcher_RS_Vk),
  .new_entry_Qj(Dispatcher_RS_Qj),
  .new_entry_Qk(Dispatcher_RS_Qk),
  .new_entry_imm(Dispatcher_RS_imm),
  .new_entry_pc(Dispatcher_RS_pc),

  .CDB_update_en(CDB_RoBEntry_update_en),
  .CDB_update_index(CDB_RoBEntry_update_index),
  .CDB_update_data(CDB_RoBEntry_update_data),
  .RS_update_en(RS_RS_update_en),
  .RS_update_index(RS_RS_update_index),
  .RS_update_data(RS_RS_update_data),

  .flush_signal(RoB_flush_signal),
  .isEmpty(RS_isEmpty),
  .isFull(RS_isFull)
);

Branch_Predictor #(
  .BP_WIDTH(BP_WIDTH)
) BP_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .update_en(RoB_branch_predictor_en),
  .update_PC(IF_predict_query_pc),
  .update_result(RoB_branch_predictor_result),
  .query_PC(IF_icache_query_pc),
  .result_out(branch_predictor_result_out)
);

Instruction_Fetcher #(
  .RoB_WIDTH(RoB_WIDTH)
) IF_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .icache_query_en(IF_icache_query_en),
  .icache_query_pc(IF_icache_query_pc),
  .icache_data_en(icache_IF_dout_en),
  .icache_data(icache_IF_dout),
  .rob_isFull(RoB_isFull),
  .new_entry_index(RoB_new_entry_index),
  .jalr_result_en(RoB_jalr_feedback_en),
  .jalr_result(RoB_jalr_feedback_data),
  .correct_next_pc(RoB_correct_next_pc),
  .new_instruction_able(Dispatcher_new_instruction_able),
  .new_instruction_en(IF_new_instruction_en),
  .new_pc(IF_new_pc),
  .new_opcode(IF_new_opcode),
  .new_rs1(IF_new_rs1),
  .new_rs2(IF_new_rs2),
  .new_rd(IF_new_rd),
  .new_imm(IF_new_imm),
  .new_predict_result(IF_new_predict_result),
  .predict_query_pc(IF_predict_query_pc),
  .predict_result_en(branch_predictor_result_out),
  .predict_result(branch_predictor_result_out)
);

Memory_Controller MC_module (
  .clk_in(clk_in),
  .rst_in(rst_in),
  .rdy_in(rdy_in),
  .uart_isFull(io_buffer_full),
  .ram_dout(mem_din),
  .ram_din(MC_ram_din),
  .ram_addr_in(MC_ram_addr_in),
  .ram_query_type(MC_ram_query_type),
  .icache_query_en(icache_MC_query_en),
  .head_addr(icache_MC_query_addr),
  .icache_block_en(MC_icache_block_en),
  .icache_block_data(MC_icache_block_data),
  .LSB_query_en(LSB_mem_query_en),
  .LSB_query_type(LSB_mem_query_type),
  .LSB_query_addr(LSB_mem_query_addr),
  .LSB_data_width(LSB_mem_data_width),
  .LSB_query_data(LSB_mem_query_data),
  .LSB_result_en(MC_LSB_result_en),
  .LSB_result_data(MC_LSB_result_data)
);


always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule