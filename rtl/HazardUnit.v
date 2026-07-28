module HazardUnit(
    input [4:0] id_rs1,
    input [4:0] id_rs2,
    input [4:0] ex_rs1,
    input [4:0] ex_rs2,
    input [4:0] ex_rd,
    input ex_MemRead,
    input mem_RegWrite,
    input [4:0] mem_rd,
    input wb_RegWrite,
    input [4:0] wb_rd,
    input Misprediction, //from EX: predicted outcome/target didn't match actual

    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,
    output reg StallF,
    output reg StallD,
    output reg FlushD,
    output reg FlushE
);

    //Data Forwarding
    always @(*) begin
        ForwardAE = 2'b00;
        ForwardBE = 2'b00;
        
        //Forward A
        if (mem_RegWrite && (mem_rd != 0) && (mem_rd == ex_rs1)) begin
            ForwardAE = 2'b10; //Forward from EX/MEM
        end else if (wb_RegWrite && (wb_rd != 0) && (wb_rd == ex_rs1)) begin
            ForwardAE = 2'b01; //Forward from MEM/WB
        end
        
        //Forward B
        if (mem_RegWrite && (mem_rd != 0) && (mem_rd == ex_rs2)) begin
            ForwardBE = 2'b10;
        end else if (wb_RegWrite && (wb_rd != 0) && (wb_rd == ex_rs2)) begin
            ForwardBE = 2'b01;
        end
    end
    
    //Load-Use Hazard Detection
    wire lwStall;
    assign lwStall = ex_MemRead && (ex_rd != 0) && ((ex_rd == id_rs1) || (ex_rd == id_rs2));
    
    //Control Hazards
    wire PCSRC;
    assign PCSRC = Misprediction;
    
    always @(*) begin
        StallF = lwStall;
        StallD = lwStall;
        
        //Flush ID/EX when load-use stall occurs or when a branch is taken
        FlushE = lwStall || PCSRC;
        
        //Flush IF/ID when branch is taken
        FlushD = PCSRC;
    end
    
endmodule
