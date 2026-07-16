`timescale 1ns/1ps

// TC01: Power on reset
// TC02: Reset across multiple clock cycles
// TC03: Normal PC update
// TC04: Sequential updates
// TC05: Maximum address
// TC06: Minimum address
// TC07: Random address
// TC08: Hold value between clk edges
// TC09: Asynchronous reset during operation
// TC10: Recovery post reset
// TC11: Multiple input changes before clk edge
// TC12: 100 randomized tests

module tb_ProgramCounter;

reg clk;
reg reset;
reg [31:0] pc_next;
wire [31:0] pc;

ProgramCounter dut (.pc_next(pc_next), .clk(clk), .reset(reset), .pc(pc));

    integer total_tests;
    integer total_failures;
    integer i; //for loop variable

    //all params
    initial begin
        clk=0;
        reset=1;
        total_tests=0;
        total_failures=0;
        pc_next=0;
    end

    //clock generation
    initial begin
        forever #5 clk=~clk;
    end



    //waveform dump
    initial begin
        $dumpfile("/mnt/c/Users/Parth/Desktop/RISC-V/waves/tb_CPU.vcd");
        $dumpvars(0, tb_ProgramCounter);
    end

    //golden model
    reg [31:0] expected_pc;
    always @(posedge clk or posedge reset) begin
        if (reset)
            expected_pc <= 32'b0;
        else
            expected_pc <= pc_next;
    end

    //timeout protection (to be changed later)

    initial begin
        #10000;
        $display("ERROR: Simulation timeout\n");
        $finish;
    end


    task check_pc;
        input [31:0] expected;
        input string test_case;

        begin
            total_tests=total_tests+1;

            if (pc===expected)begin
                if (test_case != "TC12: Randomized test")
                    $display("PASS! %s", test_case);
            end 
            
            else begin
                total_failures=total_failures+1;
                $display("FAIL: %s, expected: %h, got: %h", test_case, expected, pc);
            end
        end
    endtask

    task summary;
        begin
            $display("----------------------------------------");
            $display("Total Tests    : %0d", total_tests);
            $display("Total Failures : %0d", total_failures);
            $display("----------------------------------------");
            if (total_failures===0)
                $display("\nOVERALL RESULT: PASS\n");
            else
                $display("\nOVERALL RESULT: FAIL\n");
        end
    endtask


    //testing
    initial begin
        reset=1; pc_next=32'b0;
        
        //TC01
        #3;
        check_pc(32'b0, "TC01: Power on reset");

        //TC02
        reset=1;
        repeat(3) begin
            @(posedge clk);
            #1;
            check_pc(32'b0, "TC02: Reset across multiple clock cycles");
        end
        reset=0;  //reset released

        //TC03
        pc_next=32'h4;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC03: Normal PC update");

        //TC04
        pc_next=32'h8;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC04: Sequential updates- i");

        pc_next=32'hC;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC04: Sequential updates- ii");

        //TC05
        pc_next=32'hFFFFFFFF;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC05: Maximum address");

        //TC06 
        pc_next=32'h0;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC06: Minimum address");

        //TC07
        pc_next=32'h498A32F0;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC07: Random address");

        //TC08
        pc_next=32'h20;
        #3;
        check_pc(expected_pc, "TC08: Before clock edge, hold value");
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC08: After clock edge, update value");


        //TC09
        reset=1;
        #1;
        check_pc(32'b0, "TC09: Async reset");

        //TC10
        reset=0;
        pc_next=32'hABCDEF09;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC10: Recovery post reset");

        //TC11
        pc_next=32'h11111111;
        pc_next=32'h22222222;
        pc_next=32'h33333333;
        @(posedge clk);
        #1;
        check_pc(expected_pc, "TC11: Multiple input changes before clk edge\n");


        //TC12
        for(i=0; i<100; i=i+1) begin
            pc_next=$random;
            @(posedge clk);
            #1;
            check_pc(expected_pc, "TC12: Randomized test");
        end

        summary();
        $finish;
    end
endmodule