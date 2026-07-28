`timescale 1ns/1ps

/*  5-stage pipelined RV32I CPU directed-test.

 Termination conditions (checked on WB retirement):
  1. Sentinel instruction 0x00000400 retires = PASS  (directed tests)
  2. ecall (0x00000073) retires with a0==0 = PASS  (C/official convention)
  3. ecall retires with a0!=0 = FAIL
  4. Cycle budget exceeded = TIMEOUT
 Test tracking: gp (x3) encodes the currently running sub-test number.
 The testbench prints [PASS]/[RUN] each time gp changes.
*/

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

    //clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end


    //Wave dump
    initial begin
        $dumpfile("tb_cpu_custom.vcd");
        $dumpvars(0, tb_cpu_custom);
    end


    //Full register + pipeline-state dump task
    task dump_registers;
        begin
            $display("\n==============================");
            $display("CPU STATE DUMP");
            $display("==============================");
            $display(
                "TIME=%0t  WB_PC=%08h  WB_INSTR=%08h",
                $time, wb_pc, wb_instruction
            );
            $display(
                "ex_opcode=%02h  ex_Branch=%b  ex_BranchTaken=%b  if_pc_next=%08h",
                dut.ex_instruction[6:0],
                dut.ex_Branch,
                dut.ex_BranchTaken_wire,
                dut.if_pc_next
            );
            $display("------------------------------");
            $display("REGISTERS");
            $display("------------------------------");
            for (i = 0; i < 32; i = i + 4) begin
                $display(
                    "x%02d=%08h  x%02d=%08h  x%02d=%08h  x%02d=%08h",
                    i,   dut.register_file.registers[i],
                    i+1, dut.register_file.registers[i+1],
                    i+2, dut.register_file.registers[i+2],
                    i+3, dut.register_file.registers[i+3]
                );
            end
            $display("==============================\n");
        end
    endtask


    //Simulation
    initial begin
        cycles    = 0;
        last_test = -1;
        reset     = 1;

        repeat (2) @(posedge clk);
        reset = 0;

        forever begin
            @(posedge clk);
            cycles = cycles + 1;

            //Sub-test progress tracking via gp(x3)
            if (dut.register_file.registers[3] != 0) begin
                if (dut.register_file.registers[3] !== last_test) begin
                    if (last_test > 0)
                        $display("[PASS] sub-test %0d  (cycle=%0d)", last_test, cycles);
                    last_test = dut.register_file.registers[3];
                    $display("[RUN ] sub-test %0d  (cycle=%0d)", last_test, cycles);
                end
            end

            //TERMINATION: custom sentinel 0x00000400 retires
            if (wb_instruction == 32'h00000400) begin
                if (last_test > 0)
                    $display("[PASS] sub-test %0d  (cycle=%0d)", last_test, cycles);
                $display("\n========================================");
                $display("  DIRECTED TESTS PASSED  (cycles=%0d)", cycles);
                $display("========================================\n");
                dump_registers();
                $finish;
            end

            //TERMINATION: ecall(riscv-tests/C program convention)
            if (wb_instruction == 32'h00000073) begin
                if (dut.register_file.registers[10] == 0) begin
                    if (last_test > 0)
                        $display("[PASS] sub-test %0d  (cycle=%0d)", last_test, cycles);
                    $display("\n========================================");
                    $display("  RV32I TEST PASSED  (cycles=%0d)", cycles);
                    $display("========================================\n");
                end else begin
                    $display("\n========================================");
                    $display("  RV32I TEST FAILED  (a0=%0d)", dut.register_file.registers[10]);
                    $display("========================================\n");
                end
                $display("Completed %0d subtests", last_test);
                dump_registers();
                $finish;
            end

            //TIMEOUT
            if (cycles > 100000) begin
                $display("\n========================================");
                $display("  TIMEOUT  (last sub-test entered: %0d)", last_test);
                $display("========================================\n");
                dump_registers();
                $finish;
            end
        end
    end

endmodule
