`timescale 1ns/1ps

module tb_ALU;
    reg [31:0] SrcA;
    reg [31:0] SrcB;
    reg [3:0] ALUControl;
    wire [31:0] ALUResult;

    ALU dut (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult)
    );

    initial begin
        //Test ADD
        SrcA = 32'd10; SrcB = 32'd20; ALUControl = 4'd0; #10;
        if (ALUResult !== 32'd30) $display("FAIL: ADD");

        //Test SUB
        SrcA = 32'd20; SrcB = 32'd10; ALUControl = 4'd1; #10;
        if (ALUResult !== 32'd10) $display("FAIL: SUB");

        //Test AND
        SrcA = 32'hFFFF0000; SrcB = 32'h00FFFF00; ALUControl = 4'd2; #10;
        if (ALUResult !== 32'h00FF0000) $display("FAIL: AND");

        //Test OR
        SrcA = 32'hF0F0F0F0; SrcB = 32'h0F0F0F0F; ALUControl = 4'd3; #10;
        if (ALUResult !== 32'hFFFFFFFF) $display("FAIL: OR");

        //Test SLT
        SrcA = -32'd10; SrcB = 32'd5; ALUControl = 4'd5; #10;
        if (ALUResult !== 32'd1) $display("FAIL: SLT");

        //Test SLTU
        SrcA = -32'd10; SrcB = 32'd5; ALUControl = 4'd9; #10;
        if (ALUResult !== 32'd0) $display("FAIL: SLTU (Unsigned comparison)");

        $display("ALU Testbench Completed.");
        $finish;
    end
endmodule
