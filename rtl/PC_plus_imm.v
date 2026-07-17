module PC_plus_imm(
    input [31:0] pc,
    input [31:0] imm,
    output reg [31:0] pc_plus_imm
);

    always @(*) begin
        pc_plus_imm = pc + imm;
    end

endmodule
