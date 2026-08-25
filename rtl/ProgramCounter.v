module ProgramCounter(
    input [31:0]pc_next,
    input clk,
    input reset,
	output reg [31:0] pc
);

    always @(posedge clk or posedge reset)
    begin
        if (reset)
            pc <= 32'h80000000; //To align with spike 
        else
            pc <= pc_next;
    end
endmodule
