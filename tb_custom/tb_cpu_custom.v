`timescale 1ns/1ps
// Directed-test harness, updated for the 5-stage pipelined CPU

module tb_cpu_custom;

    reg clk;
    reg reset;

    integer i;
    integer cycles;
    integer last_test;


    wire [31:0] wb_instruction;
    wire [31:0] wb_pc;

    CPU dut (
        .clk(clk),
        .reset(reset),
        .wb_instruction(wb_instruction),
        .wb_pc(wb_pc)
    );

    //10ns clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    //Wave dump
    initial begin
        $dumpfile("tb_cpu_custom.vcd");
        $dumpvars(0,tb_cpu_custom);
    end



    //Register dump
    task dump_registers;

        begin

            $display("\n==============================");
            $display("CPU STATE DUMP");
            $display("==============================");

            $display(
                "TIME=%0t WB_PC=%08h WB_INSTR=%08h",
                $time,
                wb_pc,
                wb_instruction
            );

            $display(
                "ex_opcode=%02h ex_Branch=%b ex_BranchTaken=%b if_pc_next=%08h",
                dut.ex_instruction[6:0],
                dut.ex_Branch,
                dut.ex_BranchTaken_wire,
                dut.if_pc_next
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
                "WB_PC=%h WB_INSTR=%h x7=%h x14=%h ex_Branch=%b ex_BranchTaken=%b ex_imm=%h if_pc_next=%h",
                wb_pc,
                wb_instruction,
                dut.register_file.registers[7],
                dut.register_file.registers[14],
                dut.ex_Branch,
                dut.ex_BranchTaken_wire,
                dut.ex_imm,
                dut.if_pc_next
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
                if (dut.register_file.registers[3] !== last_test) begin
                    $display(
                        "TEST %0d starting, cycle=%0d",
                        dut.register_file.registers[3],
                        cycles
                    );
                    last_test = dut.register_file.registers[3];
                end
            end

            //PASS condition: the sentinel word must actually RETIRE(WB) and not merely be fetched down a speculative path
            if(wb_instruction == 32'h00000400)
            begin
                $display("\nPROGRAM TERMINATED -- ALL DIRECTED TESTS PASSED (cycle=%0d)", cycles);
                dump_registers();
                $finish;
            end

            if(cycles > 2000)
            begin
                $display("\nTIMEOUT (last test entered: %0d)", last_test);
                dump_registers();
                $finish;
            end
        end
    end
endmodule
