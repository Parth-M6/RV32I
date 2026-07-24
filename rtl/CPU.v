module CPU(
    input clk,
    input reset,
    output wire [31:0] wb_instruction,
    output wire [31:0] wb_pc
);

    //Hazard Unit Wires
    
    wire StallF;
    wire StallD;
    wire FlushD;
    wire FlushE;
    wire [1:0] ForwardAE;
    wire [1:0] ForwardBE;

    //IF Stage
    wire [31:0] if_pc;
    wire [31:0] if_pc_next;
    wire [31:0] if_pc_plus_4;
    wire [31:0] if_instruction;
    
    wire ex_Branch;
    wire ex_Jal;
    wire ex_Jalr;
    wire ex_branch_condition;
    wire [31:0] ex_pc_plus_imm;
    wire [31:0] ex_ALUResult;

    PCMux pc_mux (
        .pc_plus_4(if_pc_plus_4),
        .pc_plus_imm(ex_pc_plus_imm),
        .alu_result(ex_ALUResult),
        .Branch(ex_Branch),
        .Jal(ex_Jal),
        .Jalr(ex_Jalr),
        .BranchTaken(ex_branch_condition),
        .pc_next(if_pc_next)
    );

    wire [31:0] pc_reg_next;
    assign pc_reg_next = StallF ? if_pc : if_pc_next;
    
    ProgramCounter program_counter (
        .pc_next(pc_reg_next),
        .clk(clk),
        .reset(reset),
        .pc(if_pc)
    );

    PC_plus_4 pc_plus_4_inst (
        .pc(if_pc),
        .pc_plus_4(if_pc_plus_4)
    );

    InstructionMemory instruction_memory (
        .address(if_pc),
        .instruction(if_instruction)
    );

    //IF/ID Pipeline Register
    
    wire [31:0] id_pc;
    wire [31:0] id_pc_plus_4;
    wire [31:0] id_instruction;

    IF_ID if_id_reg (
        .clk(clk),
        .reset(reset),
        .en(!StallD),
        .clr(FlushD),
        .if_pc(if_pc),
        .if_pc_plus_4(if_pc_plus_4),
        .if_instruction(if_instruction),
        .id_pc(id_pc),
        .id_pc_plus_4(id_pc_plus_4),
        .id_instruction(id_instruction)
    );

    //ID Stage
    
    wire [6:0] id_opcode;
    wire [2:0] id_funct3;
    wire [6:0] id_funct7;
    wire [4:0] id_rd;
    wire [4:0] id_rs1;
    wire [4:0] id_rs2;

    InstructionDecoder instruction_decoder (
        .instruction(id_instruction),
        .opcode(id_opcode),
        .funct3(id_funct3),
        .funct7(id_funct7),
        .rd(id_rd),
        .rs1(id_rs1),
        .rs2(id_rs2)
    );

    wire id_RegWrite;
    wire id_MemWrite;
    wire id_MemRead;
    wire id_ALUSrc;
    wire id_Branch;
    wire id_Jal;
    wire id_Jalr;
    wire [1:0] id_WriteBackSelect;
    wire [1:0] id_ALUOp;
    wire [2:0] id_ImmSrc;
    wire id_UsePC;

    MainControl main_control (
        .opcode(id_opcode),
        .RegWrite(id_RegWrite),
        .MemWrite(id_MemWrite),
        .MemRead(id_MemRead),
        .ALUSrc(id_ALUSrc),
        .Branch(id_Branch),
        .Jal(id_Jal),
        .Jalr(id_Jalr),
        .WriteBackSelect(id_WriteBackSelect),
        .ALUOp(id_ALUOp),
        .ImmSrc(id_ImmSrc),
        .UsePC(id_UsePC)
    );

    wire [31:0] id_imm;
    ImmediateGenerator immediate_generator (
        .instruction(id_instruction),
        .ImmSrc(id_ImmSrc),
        .imm(id_imm)
    );

    wire [31:0] id_rd1;
    wire [31:0] id_rd2;
    wire [31:0] wb_wd3;
    wire [4:0] wb_rd;
    wire wb_RegWrite;

    RegisterFile register_file (
        .clk(clk),
        .reset(reset),
        .we(wb_RegWrite),
        .a1(id_rs1),
        .a2(id_rs2),
        .a3(wb_rd),
        .wd3(wb_wd3),
        .rd1(id_rd1),
        .rd2(id_rd2)
    );

    //ID/EX Pipeline Register
    
    wire ex_RegWrite;
    wire ex_MemWrite;
    wire ex_MemRead;
    wire ex_ALUSrc;
    wire [1:0] ex_WriteBackSelect;
    wire [1:0] ex_ALUOp;
    wire ex_UsePC;
    wire [31:0] ex_pc;
    wire [31:0] ex_instruction;
    wire [31:0] ex_rd1;
    wire [31:0] ex_rd2;
    wire [31:0] ex_imm;
    wire [31:0] ex_pc_plus_4;
    wire [4:0] ex_rs1;
    wire [4:0] ex_rs2;
    wire [4:0] ex_rd;
    wire [2:0] ex_funct3;
    wire [6:0] ex_funct7;
    wire [6:0] ex_opcode;

    ID_EX id_ex_reg (
        .clk(clk),
        .reset(reset),
        .clr(FlushE),
        
        .id_RegWrite(id_RegWrite),
        .id_MemWrite(id_MemWrite),
        .id_MemRead(id_MemRead),
        .id_ALUSrc(id_ALUSrc),
        .id_Branch(id_Branch),
        .id_Jal(id_Jal),
        .id_Jalr(id_Jalr),
        .id_WriteBackSelect(id_WriteBackSelect),
        .id_ALUOp(id_ALUOp),
        .id_UsePC(id_UsePC),
        
        .ex_RegWrite(ex_RegWrite),
        .ex_MemWrite(ex_MemWrite),
        .ex_MemRead(ex_MemRead),
        .ex_ALUSrc(ex_ALUSrc),
        .ex_Branch(ex_Branch),
        .ex_Jal(ex_Jal),
        .ex_Jalr(ex_Jalr),
        .ex_WriteBackSelect(ex_WriteBackSelect),
        .ex_ALUOp(ex_ALUOp),
        .ex_UsePC(ex_UsePC),
        
        .id_pc(id_pc),
        .id_instruction(id_instruction),
        .id_rd1(id_rd1),
        .id_rd2(id_rd2),
        .id_imm(id_imm),
        .id_pc_plus_4(id_pc_plus_4),
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .id_rd(id_rd),
        .id_funct3(id_funct3),
        .id_funct7(id_funct7),
        .id_opcode(id_opcode),
        
        .ex_pc(ex_pc),
        .ex_instruction(ex_instruction),
        .ex_rd1(ex_rd1),
        .ex_rd2(ex_rd2),
        .ex_imm(ex_imm),
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_rd(ex_rd),
        .ex_funct3(ex_funct3),
        .ex_funct7(ex_funct7),
        .ex_opcode(ex_opcode)
    );

    //EX Stage
    
    wire [31:0] mem_ALUResult;
    wire [31:0] ex_rd1_fwd;
    wire [31:0] ex_rd2_fwd;

    wire [31:0] mem_Result_fwd;

    assign ex_rd1_fwd = (ForwardAE == 2'b10) ? mem_Result_fwd :
                        (ForwardAE == 2'b01) ? wb_wd3 : ex_rd1;
                        
    assign ex_rd2_fwd = (ForwardBE == 2'b10) ? mem_Result_fwd :
                        (ForwardBE == 2'b01) ? wb_wd3 : ex_rd2;

    wire [31:0] ex_SrcA;
    wire [31:0] ex_SrcB;

    SrcAMux src_a_mux (
        .PC(ex_pc),
        .rd1(ex_rd1_fwd),
        .UsePC(ex_UsePC),
        .SrcA(ex_SrcA)
    );

    SrcBMux src_b_mux (
        .rd2(ex_rd2_fwd),
        .imm(ex_imm),
        .ALUSrc(ex_ALUSrc),
        .SrcB(ex_SrcB)
    );

    wire [3:0] ex_ALUControl;
    ALUControl alu_control_unit (
        .ALUOp(ex_ALUOp),
        .funct3(ex_funct3),
        .funct7(ex_funct7),
        .opcode(ex_opcode),
        .ALUControl(ex_ALUControl)
    );

    ALU alu (
        .SrcA(ex_SrcA),
        .SrcB(ex_SrcB),
        .ALUControl(ex_ALUControl),
        .ALUResult(ex_ALUResult)
    );

    BranchComparator branch_comparator (
        .srcA(ex_rd1_fwd),
        .srcB(ex_rd2_fwd),
        .funct3(ex_funct3),
        .BranchTaken(ex_branch_condition)
    );

    PC_plus_imm pc_plus_imm_inst (
        .pc(ex_pc),
        .imm(ex_imm),
        .pc_plus_imm(ex_pc_plus_imm)
    );

    wire ex_BranchTaken_wire = ex_Branch && ex_branch_condition;

    //EX/MEM Pipeline Register
    
    wire mem_RegWrite;
    wire mem_MemWrite;
    wire mem_MemRead;
    wire [1:0] mem_WriteBackSelect;
    wire [31:0] mem_pc;
    wire [31:0] mem_instruction;
    wire [31:0] mem_rd2;
    wire [31:0] mem_pc_plus_4;
    wire [31:0] mem_imm;
    wire [4:0] mem_rd;
    wire [2:0] mem_funct3;

    EX_MEM ex_mem_reg (
        .clk(clk),
        .reset(reset),
        
        .ex_RegWrite(ex_RegWrite),
        .ex_MemWrite(ex_MemWrite),
        .ex_MemRead(ex_MemRead),
        .ex_WriteBackSelect(ex_WriteBackSelect),
        
        .mem_RegWrite(mem_RegWrite),
        .mem_MemWrite(mem_MemWrite),
        .mem_MemRead(mem_MemRead),
        .mem_WriteBackSelect(mem_WriteBackSelect),
        
        .ex_pc(ex_pc),
        .ex_instruction(ex_instruction),
        .ex_ALUResult(ex_ALUResult),
        .ex_rd2(ex_rd2_fwd),
        .ex_pc_plus_4(ex_pc_plus_4),
        .ex_imm(ex_imm),
        .ex_rd(ex_rd),
        .ex_funct3(ex_funct3),
        
        .mem_pc(mem_pc),
        .mem_instruction(mem_instruction),
        .mem_ALUResult(mem_ALUResult),
        .mem_rd2(mem_rd2),
        .mem_pc_plus_4(mem_pc_plus_4),
        .mem_imm(mem_imm),
        .mem_rd(mem_rd),
        .mem_funct3(mem_funct3)
    );

    //MEM Stage
    
    wire [31:0] mem_ReadData;
    
    DataMemory data_memory (
        .clk(clk),
        .we(mem_MemWrite),
        .MemRead(mem_MemRead),
        .funct3(mem_funct3),
        .address(mem_ALUResult),
        .wd(mem_rd2),
        .rd(mem_ReadData)
    );
    
    WriteBackMux mem_write_back_mux (
        .ALUResult(mem_ALUResult),
        .ReadData(mem_ReadData),
        .pc_plus_4(mem_pc_plus_4),
        .Immediate(mem_imm),
        .WriteBackSelect(mem_WriteBackSelect),
        .Result(mem_Result_fwd)
    );

    //MEM/WB Pipeline Register
    
    wire [1:0] wb_WriteBackSelect;
    wire [31:0] wb_ALUResult;
    wire [31:0] wb_ReadData;
    wire [31:0] wb_pc_plus_4;
    wire [31:0] wb_imm;

    MEM_WB mem_wb_reg (
        .clk(clk),
        .reset(reset),
        
        .mem_RegWrite(mem_RegWrite),
        .mem_WriteBackSelect(mem_WriteBackSelect),
        
        .wb_RegWrite(wb_RegWrite),
        .wb_WriteBackSelect(wb_WriteBackSelect),
        
        .mem_pc(mem_pc),
        .mem_instruction(mem_instruction),
        .mem_ALUResult(mem_ALUResult),
        .mem_ReadData(mem_ReadData),
        .mem_pc_plus_4(mem_pc_plus_4),
        .mem_imm(mem_imm),
        .mem_rd(mem_rd),
        
        .wb_pc(wb_pc),
        .wb_instruction(wb_instruction),
        .wb_ALUResult(wb_ALUResult),
        .wb_ReadData(wb_ReadData),
        .wb_pc_plus_4(wb_pc_plus_4),
        .wb_imm(wb_imm),
        .wb_rd(wb_rd)
    );

    //WB Stage
    
    WriteBackMux write_back_mux (
        .ALUResult(wb_ALUResult),
        .ReadData(wb_ReadData),
        .pc_plus_4(wb_pc_plus_4),
        .Immediate(wb_imm),
        .WriteBackSelect(wb_WriteBackSelect),
        .Result(wb_wd3)
    );

    //Hazard Unit 
    
    HazardUnit hazard_unit (
        .id_rs1(id_rs1),
        .id_rs2(id_rs2),
        .ex_rs1(ex_rs1),
        .ex_rs2(ex_rs2),
        .ex_rd(ex_rd),
        .ex_MemRead(ex_MemRead),
        .mem_RegWrite(mem_RegWrite),
        .mem_rd(mem_rd),
        .wb_RegWrite(wb_RegWrite),
        .wb_rd(wb_rd),
        .BranchTaken(ex_BranchTaken_wire),
        .Jal(ex_Jal),
        .Jalr(ex_Jalr),
        
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .StallF(StallF),
        .StallD(StallD),
        .FlushD(FlushD),
        .FlushE(FlushE)
    );

endmodule
