`timescale 1ns/1ps

// Testbench for RISC-V official rv32ui tests
module tb_cpu_official #(
    parameter IMEM_FILE   = "instructions.hex",
    parameter DMEM_FILE   = IMEM_FILE,
    parameter DUMP_DEPTH  = 2
);

    reg clk;
    reg reset;

    integer i;
    integer cycles;
    integer last_test;
    integer current_gp;
    integer tests_passed;

    reg [31:0] fail_a0;
    reg [31:0] fail_testnum;

    wire [31:0] wb_instruction;
    wire [31:0] wb_pc;

    CPU #(
        .IMEM_FILE(IMEM_FILE),
        .DMEM_FILE(DMEM_FILE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .wb_instruction(wb_instruction),
        .wb_pc(wb_pc)
    );

    // 100MHz clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Wave dump - level 2 avoids dumping large memory arrays
    initial begin
        $dumpfile("tb_cpu_temp.vcd");
        $dumpvars(DUMP_DEPTH, tb_cpu_official);
    end

    // Register & pipeline state dump
    task dump_registers;
        begin
            $display("\n==============================");
            $display("CPU STATE DUMP");
            $display("==============================");
            $display("TIME=%0t", $time);
            $display("IF  : NextPC=%08h", dut.if_pc_next);
            $display("ID  : opcode=%02h", dut.id_opcode);
            $display("EX  : ALUResult=%08h Branch=%b Taken=%b",
                     dut.ex_ALUResult, dut.ex_Branch, dut.ex_BranchTaken_wire);
            $display("MEM : ALUResult=%08h MemRead=%b MemWrite=%b",
                     dut.mem_ALUResult, dut.mem_MemRead, dut.mem_MemWrite);
            $display("WB  : PC=%08h INSTR=%08h RegWrite=%b",
                     wb_pc, wb_instruction, dut.wb_RegWrite);

            $display("------------------------------");
            $display("REGISTERS");
            $display("------------------------------");

            for (i = 0; i < 32; i = i + 4) begin
                $display(
                    "x%02d=%08h  x%02d=%08h  x%02d=%08h  x%02d=%08h",
                    i,   (i == 0) ? 32'h00000000 : dut.register_file.registers[i],
                    i+1, dut.register_file.registers[i+1],
                    i+2, dut.register_file.registers[i+2],
                    i+3, dut.register_file.registers[i+3]
                );
            end
            $display("==============================\n");
        end
    endtask

    initial begin
        clk          = 0;
        reset        = 1;
        cycles       = 0;
        last_test    = 0;
        current_gp   = 0;
        tests_passed = 0;

        // Hold reset for 2 cycles, release on negedge to avoid clock race with CPU sequential logic
        repeat (2) @(posedge clk);
        @(negedge clk);
        reset = 0;

        forever begin
            // Sample on negedge so all posedge register/pipeline updates have cleanly settled
            @(negedge clk);
            cycles = cycles + 1;

            // Detect subtest progress via gp (x3)
            if (!reset && (dut.register_file.registers[3] !== current_gp)) begin
                current_gp = dut.register_file.registers[3];

                if (current_gp == 1) begin
                    // riscv-tests RVTEST_PASS sets gp=1 right before ecall
                    if (last_test > 0) begin
                        $display("[PASS] Test %0d", last_test);
                        tests_passed = tests_passed + 1;
                        last_test = 0;
                    end
                end else if (current_gp > 1 && (current_gp === (last_test << 1) || current_gp === ((last_test << 1) | 1))) begin
                    // riscv-tests RVTEST_FAIL sets gp = (failed_test << 1), then gp = (failed_test << 1) | 1
                    // Do not mark last_test as passed; failure routine is executing!
                end else if (current_gp > 1) begin
                    // A new subtest has started; previous subtest passed
                    if (last_test > 0) begin
                        $display("[PASS] Test %0d", last_test);
                        tests_passed = tests_passed + 1;
                    end
                    last_test = current_gp;
                    $display("[RUN ] Test %0d", current_gp);
                end
            end

            // Entire ISA test finished via exit syscall (ecall with a7==93) retiring in WB stage
            if (!reset && (wb_instruction === 32'h00000073) && (wb_pc >= 32'h80000000) &&
                (dut.register_file.registers[17] == 93)) begin
                if (dut.register_file.registers[10] == 0) begin // a0 == 0 means PASS
                    $display("\n========================================");
                    $display("        RV32I TEST PASSED");
                    $display("========================================");
                    $display("Completed %0d passed subtests", (tests_passed > 0) ? tests_passed : 1);
                    $display("Cycles : %0d", cycles);
                    dump_registers();
                    $finish;
                end else begin // a0 != 0 means FAIL
                    fail_a0 = dut.register_file.registers[10];
                    fail_testnum = (fail_a0 >> 1);

                    $display("[FAIL] Test %0d", fail_testnum);
                    $display("TEST %0d PC=%08h", fail_testnum, wb_pc);
                    $display("\n========================================");
                    $display("        RV32I TEST FAILED (a0=%0d, test %0d)", fail_a0, fail_testnum);
                    $display("========================================");
                    $display("Failed subtest : %0d", fail_testnum);
                    $display("Passed subtests: %0d", tests_passed);
                    $display("Cycles         : %0d", cycles);
                    dump_registers();
                    $fatal(1, "RV32I simulation failed: subtest %0d", fail_testnum);
                end
            end

            // Cycle-limit timeout with detailed diagnostic status
            if (cycles >= 10000) begin
                $display("\n========================================");
                $display("  TIMEOUT: Cycle limit exceeded (%0d cycles)", cycles);
                $display("========================================");
                $display("Passed subtests     : %0d", tests_passed);
                $display("Current/Last test ID: %0d", (dut.register_file.registers[3] > 1) ? dut.register_file.registers[3] : last_test);
                $display("Pipeline WB_PC      : %08h", wb_pc);
                $display("Pipeline WB_INSTR   : %08h", wb_instruction);
                $display("Cycles              : %0d", cycles);

                dump_registers();
                $fatal(1, "RV32I simulation timeout after %0d cycles", cycles);
            end
        end
    end
endmodule
