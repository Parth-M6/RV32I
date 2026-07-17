module MainControl(
    input [6:0] opcode,
    output reg RegWrite,
    output reg MemWrite,
    output reg MemRead,
    output reg ALUSrc,
    output reg Branch,
    output reg Jal,
    output reg Jalr,
    output reg [1:0] WriteBackSelect,
    output reg [1:0] ALUOp,
    output reg [2:0] ImmSrc,
    output reg UsePC
);

    always @(*) begin
        //Default values to prevent latches
        RegWrite        = 1'b0;
        MemWrite        = 1'b0;
        MemRead         = 1'b0;
        ALUSrc          = 1'b0;
        Branch          = 1'b0;
        Jal             = 1'b0;
        Jalr            = 1'b0;
        WriteBackSelect = 2'b00;
        ALUOp           = 2'b00;
        ImmSrc          = 3'b000;
        UsePC           = 1'b0;

        case (opcode)
            7'b0110011: begin //R-type
                RegWrite        = 1'b1;
                WriteBackSelect = 2'b00; //ALU Result
                ALUOp           = 2'b10; //Decode funct3/funct7
            end
            7'b0010011: begin //I-type ALU
                RegWrite        = 1'b1;
                ALUSrc          = 1'b1;
                WriteBackSelect = 2'b00; //ALU Result
                ALUOp           = 2'b10; //Decode funct3/funct7
                ImmSrc          = 3'b000; //I-type
            end
            7'b0000011: begin //Load
                RegWrite        = 1'b1;
                MemRead         = 1'b1;
                ALUSrc          = 1'b1;
                WriteBackSelect = 2'b01; //Memory
                ALUOp           = 2'b00; //ADD
                ImmSrc          = 3'b000; //I-type
            end
            7'b0100011: begin //Store
                MemWrite        = 1'b1;
                ALUSrc          = 1'b1;
                ALUOp           = 2'b00; //ADD
                ImmSrc          = 3'b001; //S-type
            end
            7'b1100011: begin //Branch
                Branch          = 1'b1;
                ALUOp           = 2'b01; //SUB (used by legacy ALU approach, though handled by BranchComparator now)
                ImmSrc          = 3'b010; //B-type
            end
            7'b1101111: begin //JAL
                RegWrite        = 1'b1;
                Jal             = 1'b1;
                WriteBackSelect = 2'b10; //PC + 4
                ImmSrc          = 3'b100; //J-type
            end
            7'b1100111: begin //JALR (I-type Jump)
                RegWrite        = 1'b1;
                ALUSrc          = 1'b1; //Add rd1 + imm
                Jalr            = 1'b1;
                WriteBackSelect = 2'b10; //PC + 4
                ALUOp           = 2'b00; //ADD
                ImmSrc          = 3'b000; //I-type
            end
            7'b0110111: begin //LUI (U-type)
                RegWrite        = 1'b1;
                WriteBackSelect = 2'b11; //Immediate (LUI)
                ImmSrc          = 3'b011; //U-type
            end
            7'b0010111: begin //AUIPC (U-type)
                RegWrite        = 1'b1;
                ALUSrc          = 1'b1; //Add PC + imm
                WriteBackSelect = 2'b00; //ALU Result
                ALUOp           = 2'b00; //ADD
                ImmSrc          = 3'b011; //U-type
                UsePC           = 1'b1; //Use PC for SrcA
            end
            //default redudndant as its already setup above
        endcase
    end
endmodule
