`timescale 1ns/1ps
//testbench for risc-v official rv32ui tests
module tb_cpu_official;

    reg clk;
    reg reset;

    integer i;
    integer cycles;
    integer last_test;
    integer new_test;


    CPU dut (
        .clk(clk),
        .reset(reset)
    );


    //10ns clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
        $display(
            "PC=%08h instr=%08h opcode=%02h pc4=%08h pcimm=%08h next=%08h Br=%b Jal=%b Jalr=%b Taken=%b",
            dut.if_pc,
            dut.if_instruction,
            dut.id_opcode,
            dut.if_pc_plus_4,
            dut.ex_pc_plus_imm,
            dut.if_pc_next,
            dut.ex_Branch,
            dut.ex_Jal,
            dut.ex_Jalr,
            dut.ex_BranchTaken_wire
        );
    end


    //Wave dump
    initial begin
        $dumpfile("tb_cpu_temp.vcd");
        $dumpvars(0,tb_cpu_official);
    end



    //Register dump
    task dump_registers;

        begin
            $display("\n==============================");
            $display("CPU STATE DUMP");
            $display("==============================");

            $display(
                "TIME=%0t PC=%08h INSTR=%08h",
                $time,
                dut.wb_pc,
                dut.wb_instruction
            );

            $display(
                "addr=%h offset=%0d raw_word=%h lb_val=%h",
                dut.ex_ALUResult,
                dut.ex_ALUResult[1:0],
                dut.data_memory.raw_word,
                dut.data_memory.lb_val
            );

            $display(
                "opcode=%02h Branch=%b Taken=%b NextPC=%08h",
                dut.id_opcode,
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

 initial begin
    cycles    = 0;
    last_test = 0;
    reset = 1;

    repeat (2) @(posedge clk);
    reset = 0;

    forever begin
        @(posedge clk);
        cycles = cycles + 1;
        //Detect completion of a subtest
        if (dut.register_file.registers[3] != last_test) begin
            if (last_test != 0)
                $display("[PASS] Test %0d", last_test);
            last_test = dut.register_file.registers[3];
            if (last_test != 0)
                $display("[RUN ] Test %0d", last_test);
        end

        //Entire ISA test finished
        //riscv-tests convention: a0=0 means PASS, a0!=0 (=failing gp) means FAIL
        if (dut.wb_instruction === 32'h00000073) begin //ecall
            if (dut.register_file.registers[10] == 0) begin //a0 == 0 means PASS
                if (last_test != 0)
                    $display("[PASS] Test %0d", last_test);
                $display("\n========================================");
                $display("        RV32I TEST PASSED");
                $display("========================================");
            end else begin
                $display("\n========================================");
                $display("        RV32I TEST FAILED (a0=%0d)", dut.register_file.registers[10]);
                $display("========================================");
            end
            $display("Completed %0d subtests", last_test);
            $display("Cycles : %0d", cycles);

            dump_registers();
            $finish;
        end

        if (cycles > 500000) begin
            $display("\n========================================");
            $display("        RV32I TEST FAILED");
            $display("========================================");
            $display("Last completed test : %0d", last_test);
            $display("Current test        : %0d", dut.register_file.registers[3]);
            $display("Cycles              : %0d", cycles);

            dump_registers();
            $finish;
        end
    end
end
endmodule   