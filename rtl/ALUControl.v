module ALUControl(
    input  [1:0] ALUOp,
    input  [2:0] funct3,
    input  [6:0] funct7,   //instruction[31:25]
    input  [6:0] opcode,
    output reg [3:0] ALUControl
);

    //ALU operation encodings
    localparam ALU_ADD = 4'd0;
    localparam ALU_SUB = 4'd1;
    localparam ALU_AND = 4'd2;
    localparam ALU_OR = 4'd3;
    localparam ALU_XOR = 4'd4;
    localparam ALU_SLT = 4'd5;
    localparam ALU_SLL = 4'd6;
    localparam ALU_SRL = 4'd7;
    localparam ALU_SRA = 4'd8;
    localparam ALU_SLTU = 4'd9;

    //RV32I Opcodes
    localparam OPCODE_OP = 7'b0110011; //R type
    localparam OPCODE_OP_IMM = 7'b0010011; //I type 

    always @(*) begin
        case (ALUOp)

            // Load/Store/JAL/JALR/AUIPC/LUI
            2'b00: ALUControl = ALU_ADD;

            //Branch comparison
            2'b01: ALUControl = ALU_SUB;

            // R/I type instructions
            2'b10: begin
                casex ({opcode, funct3, funct7})

                    //ADDI
                    {OPCODE_OP_IMM, 3'b000, 7'bxxxxxxx}: ALUControl = ALU_ADD;

                    //SLLI
                    {OPCODE_OP_IMM, 3'b001, 7'b0000000}: ALUControl = ALU_SLL;

                    //SLTI
                    {OPCODE_OP_IMM, 3'b010, 7'bxxxxxxx}: ALUControl = ALU_SLT;

                    //SLTIU
                    {OPCODE_OP_IMM, 3'b011, 7'bxxxxxxx}: ALUControl = ALU_SLTU;

                    //XORI
                    {OPCODE_OP_IMM, 3'b100, 7'bxxxxxxx}: ALUControl = ALU_XOR;

                    //SRLI
                    {OPCODE_OP_IMM, 3'b101, 7'b0000000}: ALUControl = ALU_SRL;

                    //SRAI
                    {OPCODE_OP_IMM, 3'b101, 7'b0100000}: ALUControl = ALU_SRA;

                    //ORI
                    {OPCODE_OP_IMM, 3'b110, 7'bxxxxxxx}: ALUControl = ALU_OR;

                    //ANDI
                    {OPCODE_OP_IMM, 3'b111, 7'bxxxxxxx}: ALUControl = ALU_AND;

                    //ADD
                    {OPCODE_OP, 3'b000, 7'b0000000}: ALUControl = ALU_ADD;

                    //SUB
                    {OPCODE_OP, 3'b000, 7'b0100000}: ALUControl = ALU_SUB;

                    //SLL
                    {OPCODE_OP, 3'b001, 7'b0000000}: ALUControl = ALU_SLL;

                    //SLT
                    {OPCODE_OP, 3'b010, 7'b0000000}: ALUControl = ALU_SLT;

                    //SLTU
                    {OPCODE_OP, 3'b011, 7'b0000000}: ALUControl = ALU_SLTU;

                    //XOR
                    {OPCODE_OP, 3'b100, 7'b0000000}: ALUControl = ALU_XOR;

                    //SRL
                    {OPCODE_OP, 3'b101, 7'b0000000}: ALUControl = ALU_SRL;

                    //SRA
                    {OPCODE_OP, 3'b101, 7'b0100000}: ALUControl = ALU_SRA;

                    //OR
                    {OPCODE_OP, 3'b110, 7'b0000000}: ALUControl = ALU_OR;

                    //AND
                    {OPCODE_OP, 3'b111, 7'b0000000}: ALUControl = ALU_AND;

                    //Illegal encoding
                    default: ALUControl = 4'bxxxx;
                endcase
            end
            default: ALUControl = 4'bxxxx;
        endcase
    end
endmodule
