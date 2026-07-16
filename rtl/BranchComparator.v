module BranchComparator(
    input [31:0] srcA,
    input [31:0] srcB,
    input [2:0] funct3,
    output reg BranchTaken
);
    wire Equal;
    wire Less;
    wire LessUnsigned;
    wire GreaterEqual;
    wire GreaterEqualUnsigned;

    assign Equal = (srcA == srcB);
    assign Less = ($signed(srcA) < $signed(srcB));
    assign LessUnsigned = (srcA < srcB);
    assign GreaterEqual = ($signed(srcA) >= $signed(srcB));
    assign GreaterEqualUnsigned = (srcA >= srcB);

    always @(*) begin
        case (funct3)
            3'b000: BranchTaken = Equal;                //BEQ
            3'b001: BranchTaken = ~Equal;               //BNE
            3'b100: BranchTaken = Less;                 //BLT
            3'b101: BranchTaken = GreaterEqual;         //BGE
            3'b110: BranchTaken = LessUnsigned;         //BLTU
            3'b111: BranchTaken = GreaterEqualUnsigned; //BGEU
            default: BranchTaken = 1'b0;
        endcase
    end
endmodule
