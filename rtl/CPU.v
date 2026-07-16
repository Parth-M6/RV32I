module CPU(
    input clk,
    input reset
);

        //Program Counter signals
        wire [31:0] pc;
        wire [31:0] pc_next;
        wire [31:0] pc_plus_4;
        wire [31:0] pc_plus_imm;

        //Instruction Memory signals
        wire [31:0] instruction;

        //Instruction Decoder Signals
        wire [6:0] opcode;
        wire [2:0] funct3;
        wire [6:0] funct7;
        wire [4:0] rd;
        wire [4:0] rs1;
        wire [4:0] rs2;

        //Control Unit outputs
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

        //Register File signals
        wire [31:0] rd1;
        wire [31:0] rd2;
        wire [31:0] wd3;

        //Immediate Generator signal
        wire [31:0] imm;

        //Branch Comparator signals
        wire branch_condition;
        wire BranchTaken;
        //ALU signals
        wire [31:0] SrcA;
        wire [31:0] SrcB;
        wire [3:0] ALUControl;
        wire [31:0] ALUResult;

        //Data Memory signal
        wire [31:0] ReadData;

        //PCMux
        PCMux pc_mux (
            .pc_plus_4(pc_plus_4),
            .pc_plus_imm(pc_plus_imm),
            .alu_result(ALUResult),
            .Branch(Branch),
            .Jal(Jal),
            .Jalr(Jalr),
            .BranchTaken(BranchTaken),
            .pc_next(pc_next)
        );

        //ProgramCounter
        ProgramCounter program_counter (
            .pc_next(pc_next),
            .clk(clk),
            .reset(reset),
            .pc(pc)
        );

        //PC+4
        PC_plus_4 pc_plus_4_inst (
            .pc(pc),
            .pc_plus_4(pc_plus_4)
        );

        //PC+imm
        PC_plus_imm pc_plus_imm_inst (
            .pc(pc),
            .imm(imm),
            .pc_plus_imm(pc_plus_imm)
        );

        //InstructionMemory
        InstructionMemory instruction_memory (
            .address(pc),
            .instruction(instruction)
        );

        //InstructionDecoder
        InstructionDecoder instruction_decoder (
            .instruction(instruction),
            .opcode(opcode),
            .funct3(funct3),
            .funct7(funct7),
            .rd(rd),
            .rs1(rs1),
            .rs2(rs2)
        );

        //MainControl
        MainControl main_control (
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

        //ImmediateGenerator
        ImmediateGenerator immediate_generator (
            .instruction(instruction),
            .ImmSrc(ImmSrc),
            .imm(imm)
        );

        //RegisterFile
        RegisterFile register_file (
            .clk(clk),
            .reset(reset),
            .we(RegWrite),
            .a1(rs1),
            .a2(rs2),
            .a3(rd),
            .wd3(wd3),
            .rd1(rd1),
            .rd2(rd2)
        );

        //BranchComparator
        BranchComparator branch_comparator (
            .srcA(rd1),
            .srcB(rd2),
            .funct3(funct3),
            .BranchTaken(branch_condition)
        );

        // A branch can only be taken if the instruction is actually a branch
        assign BranchTaken = Branch && branch_condition;

        //SrcAMux
        SrcAMux src_a_mux (
            .PC(pc),
            .rd1(rd1),
            .UsePC(UsePC),
            .SrcA(SrcA)
        );

        //SrcBMux
        SrcBMux src_b_mux (
            .rd2(rd2),
            .imm(imm),
            .ALUSrc(ALUSrc),
            .SrcB(SrcB)
        );

        //ALUControl
        ALUControl alu_control_unit (
            .ALUOp(ALUOp),
            .funct3(funct3),
            .funct7(funct7),
            .opcode(opcode),
            .ALUControl(ALUControl)
        );

        //ALU
        ALU alu (
            .SrcA(SrcA),
            .SrcB(SrcB),
            .ALUControl(ALUControl),
            .ALUResult(ALUResult)
        );

        //DataMemory
        DataMemory data_memory (
            .clk(clk),
            .we(MemWrite),
            .MemRead(MemRead),
            .funct3(funct3),
            .address(ALUResult),
            .wd(rd2),
            .rd(ReadData)
        );

        //WriteBackMux
        WriteBackMux write_back_mux (
            .ALUResult(ALUResult),
            .ReadData(ReadData),
            .pc_plus_4(pc_plus_4),
            .Immediate(imm),
            .WriteBackSelect(WriteBackSelect),
            .Result(wd3)
        );

endmodule
