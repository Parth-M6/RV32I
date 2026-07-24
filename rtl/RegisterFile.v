module RegisterFile(
    input clk,
    input reset,
    input we,
    input [4:0] a1,
    input [4:0] a2,
    input [4:0] a3,
    input [31:0] wd3,
    output reg [31:0] rd1,
    output reg [31:0] rd2
);

    /*
        32 registers, each 32 bits wide
        x0 hardwired to 0. Writes to x0 ignored
        Synchronous write(updates on the posedge of clk)
        Asynchronous(combinational) read. Outputs rd1 and rd2 update immediately when a1 or a2 changes
        Read-After-Write(RAW) behavior. Write-First/Bypass. Reading a register in the same clock cycle it is being written yields the NEW value
    */

    reg [31:0] registers[0:31];

    //Initialization block for simulator(avoids X propagation at startup)
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 32'd0;
        end
    end

    //Synchronous write with active high reset
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (we && a3 != 5'd0) begin
            registers[a3] <= wd3;
        end
    end

    //Asynch read
    always @(*) begin
        //Read Port 1
        if (a1 == 5'd0) begin
            rd1 = 32'd0; //x0 is always 0
        end else if (we && (a1 == a3)) begin
            rd1 = wd3; //Write-first bypass
        end else begin
            rd1 = registers[a1];
        end

        //Read Port 2
        if (a2 == 5'd0) begin
            rd2 = 32'd0; //x0 is always 0
        end else if (we && (a2 == a3)) begin
            rd2 = wd3; //Write-first bypass
        end else begin
            rd2 = registers[a2];
        end
    end

endmodule
