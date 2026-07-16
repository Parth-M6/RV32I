module ProgramCounter(input [31:0]pc_next,input clk,input reset,
		      output reg[31:0] pc);

always @(posedge clk or posedge reset)
begin
    if (reset)
        pc <= 32'b0;
    else
        pc <= pc_next;
end
endmodule
