module PCMux(
    input [31:0] pc_plus_4,
    input [31:0] pc_plus_imm,
    input [31:0] alu_result,
    input Branch,
    input Jal,
    input Jalr,
    input BranchTaken,
    output reg [31:0] pc_next
);

    always @(*) begin
        if (Jalr) begin
            pc_next = alu_result & ~32'b1;
        end else if (Jal || (Branch && BranchTaken)) begin
            pc_next = pc_plus_imm;
        end else begin
            pc_next = pc_plus_4;
        end
    end

endmodule
