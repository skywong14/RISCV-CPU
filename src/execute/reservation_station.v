// module reservation_station.v

// each Entry in RS contains：opcode, Vj, Vk, Qj, Qk, imm, robEntry, isBusy

// Embedded with ALU component


module Reservation_Station #(
    parameter RS_WIDTH = 4,
    parameter RS_SIZE = 1 << RS_WIDTH,
    parameter RoB_WIDTH = 4,
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
    input wire [RoB_WIDTH - 1 : 0] new_entry_robEntry,
    input wire [6 : 0] new_entry_opcode,
    input wire [31 : 0] new_entry_Vj,
    input wire [31 : 0] new_entry_Vk,
    input wire [RoB_WIDTH : 0] new_entry_Qj,
    input wire [RoB_WIDTH : 0] new_entry_Qk,
    input wire [31 : 0] new_entry_imm,
    input wire [31 : 0] new_entry_pc,

    // with CDB
    input wire CDB_update_en,
    input wire [RoB_WIDTH - 1 : 0] CDB_update_index,
    input wire [31 : 0] CDB_update_data,
    output reg RoB_update_en,
    output reg [RoB_WIDTH - 1 : 0] RoB_update_index,
    output reg [31 : 0] RoB_update_data,

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
            (!isBusy[5]) ? 5 : (!isBusy[6]) ? 6 : (!isBusy[7]) ? 7 : 
            (!isBusy[8]) ? 8 : (!isBusy[9]) ? 9 : (!isBusy[10]) ? 10 : (!isBusy[11]) ? 11 : (!isBusy[12]) ? 12 : 
            (!isBusy[13]) ? 13 : (!isBusy[14]) ? 14 : (!isBusy[15]) ? 15 : 16;
    assign busy_pos = (isBusy[0]) ? 0 : (isBusy[1]) ? 1 : (isBusy[2]) ? 2 : (isBusy[3]) ? 3 : (isBusy[4]) ? 4 :
            (isBusy[5]) ? 5 : (isBusy[6]) ? 6 : (isBusy[7]) ? 7 : 
            (isBusy[8]) ? 8 : (isBusy[9]) ? 9 : (isBusy[10]) ? 10 : (isBusy[11]) ? 11 : (isBusy[12]) ? 12 :
            (isBusy[13]) ? 13 : (isBusy[14]) ? 14 : (isBusy[15]) ? 15 : 16;     
    assign ready_pos = (isReady[0]) ? 0 : (isReady[1]) ? 1 : (isReady[2]) ? 2 : (isReady[3]) ? 3 : (isReady[4]) ? 4 :
            (isReady[5]) ? 5 : (isReady[6]) ? 6 : (isReady[7]) ? 7 :
            (isReady[8]) ? 8 : (isReady[9]) ? 9 : (isReady[10]) ? 10 : (isReady[11]) ? 11 : (isReady[12]) ? 12 :
            (isReady[13]) ? 13 : (isReady[14]) ? 14 : (isReady[15]) ? 15 : 16;    

    // assign idle_pos = (!isBusy[0]) ? 0 : (!isBusy[1]) ? 1 : (!isBusy[2]) ? 2 : (!isBusy[3]) ? 3 : (!isBusy[4]) ? 4 : 
    //         (!isBusy[5]) ? 5 : (!isBusy[6]) ? 6 : (!isBusy[7]) ? 7 : 8;
    // assign busy_pos = (isBusy[0]) ? 0 : (isBusy[1]) ? 1 : (isBusy[2]) ? 2 : (isBusy[3]) ? 3 : (isBusy[4]) ? 4 :
    //         (isBusy[5]) ? 5 : (isBusy[6]) ? 6 : (isBusy[7]) ? 7 : 8;
    // assign ready_pos = (isReady[0]) ? 0 : (isReady[1]) ? 1 : (isReady[2]) ? 2 : (isReady[3]) ? 3 : (isReady[4]) ? 4 :
    //         (isReady[5]) ? 5 : (isReady[6]) ? 6 : (isReady[7]) ? 7 : 8;

    
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

    wire new_entry_Qj_en, new_entry_Qk_en;
    assign new_entry_Qj_en = (new_entry_Qj != NON_DEP && RoB_update_en && RoB_update_index == new_entry_Qj);
    assign new_entry_Qk_en = (new_entry_Qk != NON_DEP && RoB_update_en && RoB_update_index == new_entry_Qk);

    always @(posedge clk_in) begin
        if (rst_in) begin
            // reset
            RoB_update_en <= 0;
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
            RoB_update_en <= 0;
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
            RoB_update_en <= 0;
            if (!isFull && new_entry_en) begin
                // get new entry
                opcode[idle_pos] <= new_entry_opcode;
                Qj[idle_pos] <= (new_entry_Qj_en) ? NON_DEP : new_entry_Qj;
                Vj[idle_pos] <= (new_entry_Qj_en) ? RoB_update_data : new_entry_Vj;
                Qk[idle_pos] <= (new_entry_Qk_en) ? NON_DEP : new_entry_Qk;
                Vk[idle_pos] <= (new_entry_Qk_en) ? RoB_update_data : new_entry_Vk;

                imm[idle_pos] <= new_entry_imm;
                robEntry[idle_pos] <= new_entry_robEntry;
                pc[idle_pos] <= new_entry_pc;
                isBusy[idle_pos] <= 1;
                // idle_pos will be updated automatically
            end

            // update self state
            for (i = 0; i < RS_SIZE; i = i + 1) begin
                if (isBusy[i]) begin
                    Qj[i] <= (RoB_update_en && Qj[i] == RoB_update_index) ? NON_DEP :
                             (CDB_update_en && Qj[i] == CDB_update_index) ? NON_DEP :
                                Qj[i];
                    Qk[i] <= (RoB_update_en && Qk[i] == RoB_update_index) ? NON_DEP :   
                             (CDB_update_en && Qk[i] == CDB_update_index) ? NON_DEP :
                                Qk[i];
                    Vj[i] <= (RoB_update_en && Qj[i] == RoB_update_index) ? RoB_update_data :
                             (CDB_update_en && Qj[i] == CDB_update_index) ? CDB_update_data :
                                Vj[i];
                    Vk[i] <= (RoB_update_en && Qk[i] == RoB_update_index) ? RoB_update_data :
                            (CDB_update_en && Qk[i] == CDB_update_index) ? CDB_update_data :
                                Vk[i];
                end
            end                
            // calc a ready entry, commit, clear
            if (ready_pos != (1 << RS_WIDTH)) begin
                RoB_update_en <= 1;
                RoB_update_index <= robEntry[ready_pos];
                case (opcode[ready_pos])
                    jalr: RoB_update_data <= (Vj[ready_pos] + imm[ready_pos]) & ~1;

                    beq: RoB_update_data <= (Vj[ready_pos] == Vk[ready_pos]) ? 1 : 0;
                    bne: RoB_update_data <= (Vj[ready_pos] != Vk[ready_pos]) ? 1 : 0;
                    blt: RoB_update_data <= ($signed(Vj[ready_pos]) < $signed(Vk[ready_pos])) ? 1 : 0;
                    bge: RoB_update_data <= ($signed(Vj[ready_pos]) >= $signed(Vk[ready_pos])) ? 1 : 0;
                    bltu: RoB_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? 1 : 0;
                    bgeu: RoB_update_data <= (Vj[ready_pos] >= Vk[ready_pos]) ? 1 : 0;

                    addi: RoB_update_data <= Vj[ready_pos] + imm[ready_pos];
                    slti: RoB_update_data <= (Vj[ready_pos] < imm[ready_pos]) ? 1 : 0;
                    sltiu: RoB_update_data <= (Vj[ready_pos] < imm[ready_pos]) ? 1 : 0;
                    xori: RoB_update_data <= Vj[ready_pos] ^ imm[ready_pos];
                    ori: RoB_update_data <= Vj[ready_pos] | imm[ready_pos];
                    andi: RoB_update_data <= Vj[ready_pos] & imm[ready_pos];
                    slli: RoB_update_data <= Vj[ready_pos] << imm[ready_pos];
                    srli: RoB_update_data <= Vj[ready_pos] >> imm[ready_pos];
                    srai: RoB_update_data <= Vj[ready_pos] >>> imm[ready_pos];

                    add: RoB_update_data <= Vj[ready_pos] + Vk[ready_pos];
                    sub: RoB_update_data <= Vj[ready_pos] - Vk[ready_pos];
                    sll: RoB_update_data <= Vj[ready_pos] << Vk[ready_pos];
                    slt: RoB_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? 1 : 0;
                    sltu: RoB_update_data <= (Vj[ready_pos] < Vk[ready_pos]) ? 1 : 0;
                    xorr: RoB_update_data <= Vj[ready_pos] ^ Vk[ready_pos];
                    srl: RoB_update_data <= Vj[ready_pos] >> Vk[ready_pos];
                    sra: RoB_update_data <= Vj[ready_pos] >>> Vk[ready_pos];
                    orr: RoB_update_data <= Vj[ready_pos] | Vk[ready_pos];
                    andr: RoB_update_data <= Vj[ready_pos] & Vk[ready_pos];
                endcase
                // clear ready entry
                isBusy[ready_pos] <= 0;
                opcode[ready_pos] <= 0;
                Vj[ready_pos] <= 0;
                Vk[ready_pos] <= 0;
                Qj[ready_pos] <= NON_DEP;
                Qk[ready_pos] <= NON_DEP;
                imm[ready_pos] <= 0;
                robEntry[ready_pos] <= 0;
                pc[ready_pos] <= 0;
            end
        end
    end
endmodule