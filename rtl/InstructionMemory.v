module InstructionMemory #(parameter MEM_SIZE = 16384, parameter FILENAME = "instructions.hex")(
    input [31:0] address,
    output [31:0] instruction
);

    localparam IDX_BITS = $clog2(MEM_SIZE);

    reg [31:0] memory [0:MEM_SIZE-1];

    initial begin
        $readmemh(FILENAME, memory); //File locations for automated official tests and my own directed tests are different
    end

    //PC now carries an absolute base (0x80000000) in its upper bits so it lines up with Spike. Only the low IDX_BITS select the word within this (small) memory array. The base bits are ignored for indexing but still flow through PC arithmetic (AUIPC/JAL/JALR/branch targets) untouched
    wire [IDX_BITS-1:0] word_idx = address[IDX_BITS+1:2];
    assign instruction = memory[word_idx];
endmodule
