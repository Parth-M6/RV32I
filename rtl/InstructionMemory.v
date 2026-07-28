module InstructionMemory #(parameter MEM_SIZE = 4096, parameter FILENAME = "instructions.hex")(
    input [31:0] address,
    output [31:0] instruction
);

    reg [31:0] memory [0:MEM_SIZE-1];

    initial begin
        $readmemh(FILENAME, memory); //File locations for automated official tests and my own directed tests are different
    end

    assign instruction = (address[31:2] <= MEM_SIZE-1) ? memory[address[31:2]] : 32'bx;
endmodule
