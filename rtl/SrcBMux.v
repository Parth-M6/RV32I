module SrcBMux(
    input [31:0] rd2,
    input [31:0] imm,
    input ALUSrc,
    output reg [31:0] SrcB
);

    always @(*) begin
        SrcB = ALUSrc ? imm : rd2;
    end

endmodule
