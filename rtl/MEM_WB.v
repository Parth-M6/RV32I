module MEM_WB(
    input clk,
    input reset,
    
    //Control signals
    input mem_RegWrite,
    input [1:0] mem_WriteBackSelect,
    
    output reg wb_RegWrite,
    output reg [1:0] wb_WriteBackSelect,
    
    //Data
    input [31:0] mem_pc,
    input [31:0] mem_instruction,
    input [31:0] mem_ALUResult,
    input [31:0] mem_ReadData,
    input [31:0] mem_pc_plus_4,
    input [31:0] mem_imm,
    input [4:0] mem_rd,
    
    output reg [31:0] wb_pc,
    output reg [31:0] wb_instruction,
    output reg [31:0] wb_ALUResult,
    output reg [31:0] wb_ReadData,
    output reg [31:0] wb_pc_plus_4,
    output reg [31:0] wb_imm,
    output reg [4:0] wb_rd
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_RegWrite <= 1'b0;
            wb_WriteBackSelect <= 2'b0;
            
            wb_pc <= 32'b0;
            wb_instruction <= 32'h00000013; //NOP
            wb_ALUResult <= 32'b0;
            wb_ReadData <= 32'b0;
            wb_pc_plus_4 <= 32'b0;
            wb_imm <= 32'b0;
            wb_rd <= 5'b0;
        end else begin
            wb_RegWrite <= mem_RegWrite;
            wb_WriteBackSelect <= mem_WriteBackSelect;
            
            wb_pc <= mem_pc;
            wb_instruction <= mem_instruction;
            wb_ALUResult <= mem_ALUResult;
            wb_ReadData <= mem_ReadData;
            wb_pc_plus_4 <= mem_pc_plus_4;
            wb_imm <= mem_imm;
            wb_rd <= mem_rd;
        end
    end
endmodule
