module ID_EX(
    input clk,
    input reset,
    input clr,
    
    //Control signals
    input id_RegWrite,
    input id_MemWrite,
    input id_MemRead,
    input id_ALUSrc,
    input id_Branch,
    input id_Jal,
    input id_Jalr,
    input [1:0] id_WriteBackSelect,
    input [1:0] id_ALUOp,
    input id_UsePC,
    
    output reg ex_RegWrite,
    output reg ex_MemWrite,
    output reg ex_MemRead,
    output reg ex_ALUSrc,
    output reg ex_Branch,
    output reg ex_Jal,
    output reg ex_Jalr,
    output reg [1:0] ex_WriteBackSelect,
    output reg [1:0] ex_ALUOp,
    output reg ex_UsePC,

    //Data
    input [31:0] id_pc,
    input [31:0] id_instruction,
    input [31:0] id_rd1,
    input [31:0] id_rd2,
    input [31:0] id_imm,
    input [31:0] id_pc_plus_4,
    
    input [4:0] id_rs1,
    input [4:0] id_rs2,
    input [4:0] id_rd,
    input [2:0] id_funct3,
    input [6:0] id_funct7,
    input [6:0] id_opcode,
    
    output reg [31:0] ex_pc,
    output reg [31:0] ex_instruction,
    output reg [31:0] ex_rd1,
    output reg [31:0] ex_rd2,
    output reg [31:0] ex_imm,
    output reg [31:0] ex_pc_plus_4,
    
    output reg [4:0] ex_rs1,
    output reg [4:0] ex_rs2,
    output reg [4:0] ex_rd,
    output reg [2:0] ex_funct3,
    output reg [6:0] ex_funct7,
    output reg [6:0] ex_opcode
);

    always @(posedge clk or posedge reset) begin
        if (reset || clr) begin
            ex_RegWrite <= 1'b0;
            ex_MemWrite <= 1'b0;
            ex_MemRead <= 1'b0;
            ex_ALUSrc <= 1'b0;
            ex_Branch <= 1'b0;
            ex_Jal <= 1'b0;
            ex_Jalr <= 1'b0;
            ex_WriteBackSelect <= 2'b0;
            ex_ALUOp <= 2'b0;
            ex_UsePC <= 1'b0;
            
            ex_pc <= 32'b0;
            ex_instruction <= 32'h00000013; //NOP
            ex_rd1 <= 32'b0;
            ex_rd2 <= 32'b0;
            ex_imm <= 32'b0;
            ex_pc_plus_4 <= 32'b0;
            
            ex_rs1 <= 5'b0;
            ex_rs2 <= 5'b0;
            ex_rd <= 5'b0;
            ex_funct3 <= 3'b0;
            ex_funct7 <= 7'b0;
            ex_opcode <= 7'b0;
        end else begin
            ex_RegWrite <= id_RegWrite;
            ex_MemWrite <= id_MemWrite;
            ex_MemRead <= id_MemRead;
            ex_ALUSrc <= id_ALUSrc;
            ex_Branch <= id_Branch;
            ex_Jal <= id_Jal;
            ex_Jalr <= id_Jalr;
            ex_WriteBackSelect <= id_WriteBackSelect;
            ex_ALUOp <= id_ALUOp;
            ex_UsePC <= id_UsePC;
            
            ex_pc <= id_pc;
            ex_instruction <= id_instruction;
            ex_rd1 <= id_rd1;
            ex_rd2 <= id_rd2;
            ex_imm <= id_imm;
            ex_pc_plus_4 <= id_pc_plus_4;
            
            ex_rs1 <= id_rs1;
            ex_rs2 <= id_rs2;
            ex_rd <= id_rd;
            ex_funct3 <= id_funct3;
            ex_funct7 <= id_funct7;
            ex_opcode <= id_opcode;
        end
    end
endmodule
