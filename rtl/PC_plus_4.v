module PC_plus_4(
    input [31:0] pc,
    output reg [31:0] pc_plus_4
);
always @(*) begin
    pc_plus_4 = pc + 32'd4;
end

endmodule