module IF_ID(
    input clk,
    input reset,
    input en,
    input clr,
    input [31:0] if_pc,
    input [31:0] if_pc_plus_4,
    input [31:0] if_instruction,
    output reg [31:0] id_pc,
    output reg [31:0] id_pc_plus_4,
    output reg [31:0] id_instruction
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            id_pc <= 32'b0;
            id_pc_plus_4 <= 32'b0;
            id_instruction <= 32'h00000013; //NOP
        end else if (clr) begin
            id_pc <= 32'b0;
            id_pc_plus_4 <= 32'b0;
            id_instruction <= 32'h00000013; //NOP
        end else if (en) begin
            id_pc <= if_pc;
            id_pc_plus_4 <= if_pc_plus_4;
            id_instruction <= if_instruction;
        end
    end
endmodule
