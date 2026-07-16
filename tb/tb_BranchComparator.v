`timescale 1ns/1ps

module tb_BranchComparator;
    reg [31:0] srcA;
    reg [31:0] srcB;
    reg [2:0] funct3;
    wire BranchTaken;

    BranchComparator dut (
        .srcA(srcA),
        .srcB(srcB),
        .funct3(funct3),
        .BranchTaken(BranchTaken)
    );

    initial begin
        //BEQ
        srcA = 32'd10; srcB = 32'd10; funct3 = 3'b000; #10;
        if (BranchTaken !== 1'b1) $display("FAIL: BEQ equal");
        srcA = 32'd10; srcB = 32'd11; funct3 = 3'b000; #10;
        if (BranchTaken !== 1'b0) $display("FAIL: BEQ not equal");

        //BLT (signed)
        srcA = -32'd10; srcB = 32'd10; funct3 = 3'b100; #10;
        if (BranchTaken !== 1'b1) $display("FAIL: BLT true");

        //BGE (signed)
        srcA = 32'd10; srcB = -32'd10; funct3 = 3'b101; #10;
        if (BranchTaken !== 1'b1) $display("FAIL: BGE true");
        srcA = -32'd10; srcB = -32'd10; funct3 = 3'b101; #10;
        if (BranchTaken !== 1'b1) $display("FAIL: BGE equal");

        //BLTU (unsigned)
        srcA = -32'd10; srcB = 32'd10; funct3 = 3'b110; #10; // -10 is a huge positive number
        if (BranchTaken !== 1'b0) $display("FAIL: BLTU false");

        $display("BranchComparator Testbench Completed.");
        $finish;
    end
endmodule
