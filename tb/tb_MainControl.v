`timescale 1ns/1ps

module tb_MainControl;
    reg [6:0] opcode;
    wire RegWrite;
    wire MemWrite;
    wire MemRead;
    wire ALUSrc;
    wire Branch;
    wire Jal;
    wire Jalr;
    wire [1:0] WriteBackSelect;
    wire [1:0] ALUOp;
    wire [2:0] ImmSrc;
    wire UsePC;

    MainControl dut (
        .opcode(opcode),
        .RegWrite(RegWrite),
        .MemWrite(MemWrite),
        .MemRead(MemRead),
        .ALUSrc(ALUSrc),
        .Branch(Branch),
        .Jal(Jal),
        .Jalr(Jalr),
        .WriteBackSelect(WriteBackSelect),
        .ALUOp(ALUOp),
        .ImmSrc(ImmSrc),
        .UsePC(UsePC)
    );

    initial begin
        //R-type
        opcode = 7'b0110011; #10;
        if (RegWrite !== 1'b1 || ALUSrc !== 1'b0 || WriteBackSelect !== 2'b00 || ALUOp !== 2'b10)
            $display("FAIL: R-type");

        //AUIPC
        opcode = 7'b0010111; #10;
        if (RegWrite !== 1'b1 || UsePC !== 1'b1 || WriteBackSelect !== 2'b00 || ALUSrc !== 1'b1)
            $display("FAIL: AUIPC");
        
        //Load
        opcode = 7'b0000011; #10;
        if (RegWrite !== 1'b1 || MemRead !== 1'b1 || WriteBackSelect !== 2'b01)
            $display("FAIL: Load");

        //Store
        opcode = 7'b0100011; #10;
        if (MemWrite !== 1'b1 || ALUSrc !== 1'b1)
            $display("FAIL: Store");
        $display("MainControl Testbench Completed.");
        $finish;
    end
endmodule
