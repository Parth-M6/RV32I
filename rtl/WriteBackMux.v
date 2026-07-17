module WriteBackMux(
    input [31:0] ALUResult,
    input [31:0] ReadData,
    input [31:0] pc_plus_4,
    input [31:0] Immediate,
    input [1:0] WriteBackSelect,
    output reg [31:0] Result
);

    always @(*) begin
        case (WriteBackSelect)
            2'b00: Result = ALUResult;
            2'b01: Result = ReadData;
            2'b10: Result = pc_plus_4;
            2'b11: Result = Immediate;
            default: Result = ALUResult;
        endcase
    end
    
endmodule


