// module reservation_station.v

// each Entry in RS contains：opcode, Vj, Vk, Qj, Qk, imm, robEntry, isBusy

// Embedded with ALU component


module Reservation_Station #(
    parameter RS_WIDTH = 3,
    parameter RS_SIZE = 1 << RS_WIDTH,
    parameter RoB_WIDTH = 3,
    parameter RoB_SIZE = 1 << RoB_WIDTH,


    parameter NON_DEP = 1 << RoB_WIDTH,

    parameter jalr = 7'd4,     // Jump and Link Register: result = (Vj + imm) & ~1 
    // B type
    parameter beq = 7'd5,      // Branch if Equal: if (Vj == Vk) PC = PC + imm
    parameter bne = 7'd6,      // Branch if Not Equal: if (Vj != Vk) PC = PC + imm
    parameter blt = 7'd7,      // Branch if Less Than: if (Vj < Vk) PC = PC + imm
    parameter bge = 7'd8,      // Branch if Greater or Equal: if (Vj >= Vk) PC = PC + imm
    parameter bltu = 7'd9,     // Branch if Less Than Unsigned: if (Vj < Vk) PC = PC + imm
    parameter bgeu = 7'd10,    // Branch if Greater or Equal Unsigned: if (Vj >= Vk) PC = PC + imm
    // I type
    parameter addi = 7'd19,    // Add Immediate: result = Vj + imm
    parameter slti = 7'd20,    // Set Less Than Immediate: result = (Vj < imm) ? 1 : 0
    parameter sltiu = 7'd21,   // Set Less Than Immediate Unsigned: result = (Vj < imm) ? 1 : 0
    parameter xori = 7'd22,    // XOR Immediate: result = Vj ^ imm
    parameter ori = 7'd23,     // OR Immediate: result = Vj | imm
    parameter andi = 7'd24,    // AND Immediate: result = Vj & imm
    parameter slli = 7'd25,    // Shift Left Logical Immediate: result = Vj << imm
    parameter srli = 7'd26,    // Shift Right Logical Immediate: result = Vj >> imm
    parameter srai = 7'd27,    // Shift Right Arithmetic Immediate: result = Vj >>> imm
    // R type
    parameter add = 7'd28,     // Add: result = Vj + Vk
    parameter sub = 7'd29,     // Subtract: result = Vj - Vk
    parameter sll = 7'd30,     // Shift Left Logical: result = Vj << Vk
    parameter slt = 7'd31,     // Set Less Than: result = (Vj < Vk) ? 1 : 0
    parameter sltu = 7'd32,    // Set Less Than Unsigned: result = (Vj < Vk) ? 1 : 0
    parameter xorr = 7'd33,    // XOR: result = Vj ^ Vk
    parameter srl = 7'd34,     // Shift Right Logical: result = Vj >> Vk
    parameter sra = 7'd35,     // Shift Right Arithmetic: result = Vj >>> Vk
    parameter orr = 7'd36,     // OR: result = Vj | Vk
    parameter andr = 7'd37     // AND: result = Vj & Vk
) (
    // cpu
    input wire clk_in,
    input wire rst_in,
    input wire rdy_in,

    // with Dispatcher
    input wire new_entry_en,
    input wire [6 : 0] new_entry_opcode,
    input wire [31 : 0] new_entry_Vj,
    input wire [31 : 0] new_entry_Vk,
    input wire [RoB_WIDTH : 0] new_entry_Qj,
    input wire [RoB_WIDTH : 0] new_entry_Qk,
    input wire [31 : 0] new_entry_imm,
    input wire [RoB_WIDTH - 1 : 0] new_entry_robEntry,
    input wire [31 : 0] new_entry_pc,

    // with CDB
    input wire CDB_update_en,
    input wire [RoB_WIDTH - 1 : 0] CDB_update_index,
    input wire [31 : 0] CDB_update_data,
    output reg RS_update_en,
    output reg [RoB_WIDTH - 1 : 0] RS_update_index,
    output reg [31 : 0] RS_update_data,

    // flush signal
    input wire flush_signal,

    // self state
    output wire isEmpty,
    output wire isFull
);  
    reg isBusy[RS_SIZE - 1 : 0];
    reg [6 : 0] opcode[RS_SIZE - 1 : 0];
    reg [31 : 0] Vj[RS_SIZE - 1 : 0];
    reg [31 : 0] Vk[RS_SIZE - 1 : 0];
    reg [RoB_WIDTH : 0] Qj[RS_SIZE - 1 : 0];
    reg [RoB_WIDTH : 0] Qk[RS_SIZE - 1 : 0];
    reg [31 : 0] imm[RS_SIZE - 1 : 0];
    reg [RoB_WIDTH - 1 : 0] robEntry[RS_SIZE - 1 : 0];
    reg [31 : 0] pc[RS_SIZE - 1 : 0];

    wire isReady[RS_SIZE - 1 : 0];

    wire [RS_WIDTH : 0] idle_pos;
    wire [RS_WIDTH : 0] busy_pos;
    wire [RS_WIDTH : 0] ready_pos;
    assign idle_pos = (!isBusy[0]) ? 0 : (!isBusy[1]) ? 1 : (!isBusy[2]) ? 2 : (!isBusy[3]) ? 3 : (!isBusy[4]) ? 4 : 
            (!isBusy[5]) ? 5 : (!isBusy[6]) ? 6 : (!isBusy[7]) ? 7 : 8;
    assign busy_pos = (isBusy[0]) ? 0 : (isBusy[1]) ? 1 : (isBusy[2]) ? 2 : (isBusy[3]) ? 3 : (isBusy[4]) ? 4 :
            (isBusy[5]) ? 5 : (isBusy[6]) ? 6 : (isBusy[7]) ? 7 : 8;        
    assign ready_pos = (isReady[0]) ? 0 : (isReady[1]) ? 1 : (isReady[2]) ? 2 : (isReady[3]) ? 3 : (isReady[4]) ? 4 :
            (isReady[5]) ? 5 : (isReady[6]) ? 6 : (isReady[7]) ? 7 : 8;        

    assign isFull = (idle_pos == (1 << RS_WIDTH));
    assign isEmpty = (busy_pos == (1 << RS_WIDTH));

    // isReady = isBusy && Qj == NON_DEP && Qk == NON_DEP
    genvar i_gen;
    generate
        for (i_gen = 0; i_gen < RS_SIZE; i_gen = i_gen + 1) begin: gen_RS_isReady
            assign isReady[i_gen] = isBusy[i_gen] && (Qj[i_gen] == NON_DEP) && (Qk[i_gen] == NON_DEP);
        end
    endgenerate

    integer i;

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            for (i = 0; i < RS_SIZE; i = i + 1) begin
                isBusy[i] <= 0;
                opcode[i] <= 0;
                Vj[i] <= 0;
                Vk[i] <= 0;
                Qj[i] <= NON_DEP;
                Qk[i] <= NON_DEP;
                imm[i] <= 0;
                robEntry[i] <= 0;
                pc[i] <= 0;
            end
        end
        else if (!rdy_in) begin
            // pause
        end if (flush_signal) begin
            // flush
            for (i = 0; i < RS_SIZE; i = i + 1) begin
                isBusy[i] <= 0;
                opcode[i] <= 0;
                Vj[i] <= 0;
                Vk[i] <= 0;
                Qj[i] <= NON_DEP;
                Qk[i] <= NON_DEP;
                imm[i] <= 0;
                robEntry[i] <= 0;
                pc[i] <= 0;
            end
        end
        else begin
            // run
            if (!isFull && new_entry_en) begin
                // get new entry
                opcode[idle_pos] <= new_entry_opcode;
                Vj[idle_pos] <= new_entry_Vj;
                Vk[idle_pos] <= new_entry_Vk;
                Qj[idle_pos] <= new_entry_Qj;
                Qk[idle_pos] <= new_entry_Qk;
                imm[idle_pos] <= new_entry_imm;
                robEntry[idle_pos] <= new_entry_robEntry;
                pc[idle_pos] <= new_entry_pc;
                isBusy[idle_pos] <= 1;
                // idle_pos will be updated automatically
            end
            
            if (CDB_update_en) begin
                // monitor CDB, update Qj, Qk, Vj, Vk
                for (i = 0; i < RS_SIZE; i = i + 1) begin
                    if (isBusy[i]) begin
                        if (Qj[i] == CDB_update_index) begin
                            Qj[i] <= NON_DEP;
                            Vj[i] <= CDB_update_data;
                        end
                        if (Qk[i] == CDB_update_index) begin
                            Qk[i] <= NON_DEP;
                            Vk[i] <= CDB_update_data;
                        end
                    end
                end
            end

            // calc a ready entry and commit
            if (ready_pos != (1 << RS_WIDTH)) begin
                RS_update_en <= 1;
                RS_update_index <= robEntry[ready_pos];
                case (opcode[ready_pos])
                    jalr: RS_update_data <= (Vj[ready_pos] + imm[ready_pos]) & ~1;

                    beq: RS_update_data <= (Vj[ready_pos] == Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;
                    bne: RS_update_data <= (Vj[ready_pos] != Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;
                    blt: RS_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;
                    bge: RS_update_data <= (Vj[ready_pos] >= Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;
                    bltu: RS_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;
                    bgeu: RS_update_data <= (Vj[ready_pos] >= Vk[ready_pos]) ? pc[ready_pos] + imm[ready_pos] : pc[ready_pos] + 4;

                    addi: RS_update_data <= Vj[ready_pos] + imm[ready_pos];
                    slti: RS_update_data <= (Vj[ready_pos] < imm[ready_pos]) ? 1 : 0;
                    sltiu: RS_update_data <= (Vj[ready_pos] < imm[ready_pos]) ? 1 : 0;
                    xori: RS_update_data <= Vj[ready_pos] ^ imm[ready_pos];
                    ori: RS_update_data <= Vj[ready_pos] | imm[ready_pos];
                    andi: RS_update_data <= Vj[ready_pos] & imm[ready_pos];
                    slli: RS_update_data <= Vj[ready_pos] << imm[ready_pos];
                    srli: RS_update_data <= Vj[ready_pos] >> imm[ready_pos];
                    srai: RS_update_data <= Vj[ready_pos] >>> imm[ready_pos];

                    add: RS_update_data <= Vj[ready_pos] + Vk[ready_pos];
                    sub: RS_update_data <= Vj[ready_pos] - Vk[ready_pos];
                    sll: RS_update_data <= Vj[ready_pos] << Vk[ready_pos];
                    slt: RS_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? 1 : 0;
                    sltu: RS_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? 1 : 0;
                    xorr: RS_update_data <= Vj[ready_pos] ^ Vk[ready_pos];
                    srl: RS_update_data <= Vj[ready_pos] >> Vk[ready_pos];
                    sra: RS_update_data <= Vj[ready_pos] >>> Vk[ready_pos];
                    orr: RS_update_data <= Vj[ready_pos] | Vk[ready_pos];
                    andr: RS_update_data <= Vj[ready_pos] & Vk[ready_pos];
                endcase
            end
        end
    end





endmodule