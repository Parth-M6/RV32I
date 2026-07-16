module ALU(
    input [31:0] SrcA,
    input [31:0] SrcB,
    input [3:0] ALUControl,
    output reg [31:0] ALUResult
);
    //local parameters
    localparam ADD = 4'd0;
    localparam SUB = 4'd1;
    localparam AND = 4'd2;
    localparam OR = 4'd3;
    localparam XOR = 4'd4;
    localparam SLT = 4'd5;
    localparam SLL = 4'd6;
    localparam SRL = 4'd7;
    localparam SRA = 4'd8;
    localparam SLTU = 4'd9;

    //Boundary Assertion (pnly for simulation)
    always @(*) begin
        if (ALUControl > SLTU) begin
            $display("WARNING/ASSERTION FAILED in ALU: Invalid ALUControl value %d", ALUControl);
        end
    end

    always @(*) begin
        case (ALUControl)
            ADD:  ALUResult = SrcA + SrcB;
            SUB:  ALUResult = SrcA - SrcB;
            AND:  ALUResult = SrcA & SrcB;
            OR:   ALUResult = SrcA | SrcB;
            XOR:  ALUResult = SrcA ^ SrcB;
            SLT:  ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'd1 : 32'd0;
            SLL:  ALUResult = SrcA << SrcB[4:0];
            SRL:  ALUResult = SrcA >> SrcB[4:0];
            SRA:  ALUResult = $signed(SrcA) >>> SrcB[4:0];
            SLTU: ALUResult = (SrcA < SrcB) ? 32'd1 : 32'd0;
            default: ALUResult = 32'hxxxxxxxx; //Expose bugs immediately
        endcase
    end
endmodule
