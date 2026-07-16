`timescale 1ns/1ps

module tb_cpu_directed;

    reg clk;
    reg reset;

    integer i;
    integer cycles;
    integer last_test;


    CPU dut (
        .clk(clk),
        .reset(reset)
    );


    // 10ns clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    // Wave dump
    initial begin
        $dumpfile("tb_cpu_temp.vcd");
        $dumpvars(0,tb_cpu_directed);
    end



    // Register dump
    task dump_registers;

        begin

            $display("\n==============================");
            $display("CPU STATE DUMP");
            $display("==============================");

            $display(
                "TIME=%0t PC=%08h INSTR=%08h",
                $time,
                dut.pc,
                dut.instruction
            );


            $display(
                "opcode=%02h Branch=%b Taken=%b NextPC=%08h",
                dut.opcode,
                dut.Branch,
                dut.BranchTaken,
                dut.pc_next
            );


            $display("------------------------------");
            $display("REGISTERS");
            $display("------------------------------");


            for(i=0;i<32;i=i+4)
            begin

                $display(
                "x%02d=%08h  x%02d=%08h  x%02d=%08h  x%02d=%08h",
                i,
                dut.register_file.registers[i],
                i+1,
                dut.register_file.registers[i+1],
                i+2,
                dut.register_file.registers[i+2],
                i+3,
                dut.register_file.registers[i+3]
                );

            end


            $display("==============================\n");

        end

    endtask


    always @(posedge clk)
        begin
            #1;
            if(dut.register_file.registers[3]==8)
            begin
                $display(
                "PC=%h instr=%h x7=%h x14=%h Branch=%b Taken=%b Imm=%h NextPC=%h",
                dut.pc,
                dut.instruction,
                dut.register_file.registers[7],
                dut.register_file.registers[14],
                dut.Branch,
                dut.BranchTaken,
                dut.imm,
                dut.pc_next
                );
            end
        end



    initial begin

        cycles = 0;
        last_test = -1;


        reset = 1;

        repeat(2)
            @(posedge clk);

        reset = 0;



        forever begin

            @(posedge clk);
            cycles = cycles + 1;


            if(dut.register_file.registers[3] != 0)
            begin
                $display(
                    "TEST %0d PC=%08h",
                    dut.register_file.registers[3],
                    dut.pc
                );
            end


            // PASS condition
            if(dut.instruction == 32'h00000063)
            begin
                $display("\nPROGRAM TERMINATED");
                dump_registers();
                $finish;
            end

            if(cycles > 10000)
            begin
                $display("\nTIMEOUT");
                dump_registers();
                $finish;
            end

        end
    end
endmodule   