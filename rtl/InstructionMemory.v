module InstructionMemory (input [31:0] address,
                          output [31:0] instruction);
    reg [31:0] memory[0:4095];

    initial begin
        $readmemh("C:/Users/Parth/Desktop/RISC-V/rtl/instructions.hex", memory); 
    end

    assign instruction = (address[31:2] < 4096) ? memory[address[31:2]] : 32'bx;
endmodule
