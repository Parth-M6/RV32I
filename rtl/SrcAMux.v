module SrcAMux(
    input [31:0] PC,
    input [31:0] rd1,
    input UsePC,
    output reg [31:0] SrcA
);

    always @(*) begin
        SrcA = UsePC ? PC : rd1;
    end
    
endmodule
