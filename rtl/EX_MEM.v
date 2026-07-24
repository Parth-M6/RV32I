module EX_MEM(
    input clk,
    input reset,
    
    //Control signals
    input ex_RegWrite,
    input ex_MemWrite,
    input ex_MemRead,
    input [1:0] ex_WriteBackSelect,
    
    output reg mem_RegWrite,
    output reg mem_MemWrite,
    output reg mem_MemRead,
    output reg [1:0] mem_WriteBackSelect,
    
    //Data
    input [31:0] ex_pc,
    input [31:0] ex_instruction,
    input [31:0] ex_ALUResult,
    input [31:0] ex_rd2,
    input [31:0] ex_pc_plus_4,
    input [31:0] ex_imm,
    input [4:0] ex_rd,
    input [2:0] ex_funct3,
    
    output reg [31:0] mem_pc,
    output reg [31:0] mem_instruction,
    output reg [31:0] mem_ALUResult,
    output reg [31:0] mem_rd2,
    output reg [31:0] mem_pc_plus_4,
    output reg [31:0] mem_imm,
    output reg [4:0] mem_rd,
    output reg [2:0] mem_funct3
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mem_RegWrite <= 1'b0;
            mem_MemWrite <= 1'b0;
            mem_MemRead <= 1'b0;
            mem_WriteBackSelect <= 2'b0;
            
            mem_pc <= 32'b0;
            mem_instruction <= 32'h00000013;
            mem_ALUResult <= 32'b0;
            mem_rd2 <= 32'b0;
            mem_pc_plus_4 <= 32'b0;
            mem_imm <= 32'b0;
            mem_rd <= 5'b0;
            mem_funct3 <= 3'b0;
        end else begin
            mem_RegWrite <= ex_RegWrite;
            mem_MemWrite <= ex_MemWrite;
            mem_MemRead <= ex_MemRead;
            mem_WriteBackSelect <= ex_WriteBackSelect;
            
            mem_pc <= ex_pc;
            mem_instruction <= ex_instruction;
            mem_ALUResult <= ex_ALUResult;
            mem_rd2 <= ex_rd2;
            mem_pc_plus_4 <= ex_pc_plus_4;
            mem_imm <= ex_imm;
            mem_rd <= ex_rd;
            mem_funct3 <= ex_funct3;
        end
    end
endmodule
