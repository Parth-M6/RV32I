`timescale 1ns/1ps

/*

BASIC ARITHMETIC OPERATIONS-

| PC | Hex      | Instruction     | Expected Result       |
| -: | ---------| ----------------| --------------------- |
| 00 | 00a00013 | addi x0, x0, 10 | Ignored, x0 remains 0 |
| 04 | 00a00093 | addi x1, x0, 10 | x1=10                 |
| 08 | 01400113 | addi x2, x0, 20 | x2=20                 |
| 0C | 002081b3 | add x3, x1, x2  | x3=30                 |
| 10 | 40110233 | sub x4, x2, x1  | x4=10                 |


IMMEDIATE INSTRUCTIONS-

| PC | Instruction      | Result     |
| -: | ---------------  | ---------- |
| 14 | andi x5, x2, 15  | 20&15=4    |
| 18 | ori x6, x1, 5    | 10|5=15    |
| 1C | xori x7, x1, 3   | 10⊕3=9    |
| 20 | slti x8, x1, 15  | 1          |
| 24 | sltiu x9, x1, 5  | 0          |
| 28 | slli x10, x1, 2  | 40         |
| 2C | srli x11, x2, 2  | 5          |
| 30 | srai x12, x2, 1  | 10         |
| 34 | addi x13, x0, -4 | 0xFFFFFFFC |
| 38 | srai x14, x13, 2 | 0xFFFFFFFF |

REGISTER OPERATIONS-

| PC | Instruction      | Result    |
| -: | ---------------  | --------- |
| 3C | and x15, x3, x4  | 10        |
| 40 | or x16, x3, x4   | 30        |
| 44 | xor x17, x3, x4  | 20        |
| 48 | sll x18, x1, x5  | 10<<4=160 |
| 4C | srl x19, x18, x5 | 10        |
| 50 | sra x20, x13, x5 | -4>>4=-1  |


U-TYPE-

| PC | Instruction        | Result     |
| -: | ---------------    | ---------- |
| 54 | lui x21, 0x12345   | 0x12345000 |
| 58 | auipc x22, 0x02000 | 0x02000058 |


MEMORY OPERATIONS-

addi x23, 0
addi x24, 255
sb x24, 0(x23)
lb x25, 0(x23)
lbu x26, 0(x23)
lui x24, 8
sh x24, 4(x23)
lh x27, 4(x23)
lhu x28, 4(x23)
sw x3, 8(x23)
lw x29, 8(x23)

BRANCHES-

beq x1, x1, +8
bne x1, x1, +8
blt x1, x2, +8
blt x13, x1, +8
bge x2, x1, +8
bge x1, x2, +8
bltu x1, x2, +8
bgeu x1, x2, +8
bltu x13, x1, +8
bgeu x13, x1, +8


JUMPS-

jal x31, +8
addi x10, 228
jalr x1, x10, 0
nop

FAULT TESTING-

addi x2, 1
lw x3, 0(x2)
sw x3, 0(x2)
lw x4, 2000(x0)
addi x10, 1024
jalr x0, x10, 0

*/

module tb_CPU;
    reg clk;
    reg reset;

    // Testbench tracking variables
    integer total_tests;
    integer total_failures;
    integer i;
    
    reg [31:0] current_pc;
    reg [31:0] current_instr;

    // Instantiate Device Under Test
    CPU dut (
        .clk(clk),
        .reset(reset)
    );

    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Waveform Dump Setup
    initial begin
        $dumpfile("waves/tb_CPU.vcd");
        $dumpvars(0, tb_CPU);
    end

    // Simulation Timeout Protection
    initial begin
        #15000;
        $display("\n[TIMEOUT ERROR] Simulation forced to terminate.\n");
        $finish;
    end

    // Helper Task: Dump entire register file contents upon failures
    task dump_registers;
        begin
            $display(
                "t=%0t PC=%08h INSTR=%08h OPCODE=%02h Branch=%b Taken=%b NextPC=%08h",
                $time,
                dut.pc,
                dut.instruction,
                dut.opcode,
                dut.Branch,
                dut.BranchTaken,
                dut.pc_next
            );
            $display("IMEM[0]=%h", dut.instruction_memory.memory[0]);
            $display("IMEM[1]=%h", dut.instruction_memory.memory[1]);
            $display("IMEM[2]=%h", dut.instruction_memory.memory[2]);
            $display("IMEM[3]=%h", dut.instruction_memory.memory[3]);
            $display("IMEM[4]=%h", dut.instruction_memory.memory[4]);
            $display("IMEM[5]=%h", dut.instruction_memory.memory[5]);
            $display("==================================================================");
            $display("                    REGISTER FILE SNAPSHOT                        ");
            $display("==================================================================");
            for (i = 0; i < 32; i = i + 4) begin
                $display("x%02d: 0x%h    x%02d: 0x%h    x%02d: 0x%h    x%02d: 0x%h", 
                         i,   dut.register_file.registers[i],
                         i+1, dut.register_file.registers[i+1],
                         i+2, dut.register_file.registers[i+2],
                         i+3, dut.register_file.registers[i+3]);
            end
            $display("==================================================================");
        end
    endtask

    // Helper Task: Asserts specific register value match
    task check_reg;
        input [4:0] idx;
        input [31:0] expected;
        input string test_case;
        reg [31:0] actual;
        begin
            total_tests = total_tests + 1;
            actual = dut.register_file.registers[idx];
            if (actual !== expected) begin
                total_failures = total_failures + 1;
                $display("\n[FAIL] %s", test_case);
                $display("  Executed PC       : 0x%h", current_pc);
                $display("  Instruction Word  : 0x%h", current_instr);
                $display("  Target Register   : x%0d", idx);
                $display("  Expected Output   : %d (0x%h)", expected, expected);
                $display("  Actual Output     : %d (0x%h)", actual, actual);
                dump_registers();
            end else begin
                $display("[PASS] %s", test_case);
            end
        end
    endtask

    // Helper Task: Asserts correct Program Counter progression
    task check_pc;
        input [31:0] expected;
        input string test_case;
        reg [31:0] actual;
        begin
            total_tests = total_tests + 1;
            actual = dut.pc;
            if (actual !== expected) begin
                total_failures = total_failures + 1;
                $display("\n[FAIL] %s (PC Routing Fault)", test_case);
                $display("  Prior PC          : 0x%h", current_pc);
                $display("  Instruction Word  : 0x%h", current_instr);
                $display("  Expected Next PC  : 0x%h", expected);
                $display("  Actual Next PC    : 0x%h", actual);
                dump_registers();
            end else begin
                $display("[PASS] %s (PC Verification)", test_case);
            end
        end
    endtask

    // Helper Task: Step exactly one execution clock cycle
    task execute_cycle;
        begin
            current_pc = dut.pc;
            current_instr = dut.instruction;
            @(posedge clk);
            #1; // Wait for non-blocking state commitments to resolve
        end
    endtask

    // Helper Task: Prints localized structural section breaks
    task print_header;
        input string title;
        begin
            $display("\n--- %s ---", title);
        end
    endtask

    // Helper Task: Post summaries matching tb_ProgramCounter blueprint
    task summary;
        begin
            $display("\n----------------------------------------");
            $display("Total Tests Completed : %0d", total_tests);
            $display("Total Failures Caught : %0d", total_failures);
            $display("----------------------------------------");
            if (total_failures === 0)
                $display("\nOVERALL RESULT: PASS\n");
            else
                $display("\nOVERALL RESULT: FAIL\n");
        end
    endtask

    // Core Verification Sequence
    initial begin
        total_tests = 0;
        total_failures = 0;

        // Synchronous System Reset Assertions
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        #2;
        reset = 0;
        #1;

        
        // SECTION 1: REGISTER ARITHMETIC & HARDWIRED x0 SAFEGUARDS
        
        print_header("Section 1: Register Arithmetic & Hardwired x0");
        
        execute_cycle(); // addi x0, x0, 10
        check_reg(0, 32'd0, "TC01: Immediate operation writing to x0 must be ignored");
        
        execute_cycle(); // addi x1, x0, 10
        check_reg(1, 32'd10, "TC02: Initialize register x1 with 10");
        
        execute_cycle(); // addi x2, x0, 20
        check_reg(2, 32'd20, "TC03: Initialize register x2 with 20");
        
        execute_cycle(); // add x3, x1, x2
        check_reg(3, 32'd30, "TC04: R-Type Addition (x3 = x1 + x2)");
        
        execute_cycle(); // sub x4, x2, x1
        check_reg(4, 32'd10, "TC05: R-Type Subtraction (x4 = x2 - x1)");

        
        // SECTION 2: IMMEDIATE ALU OPERATIONS
        
        print_header("Section 2: Immediate ALU Instructions");
        
        execute_cycle(); // andi x5, x2, 15
        check_reg(5, 32'd4, "TC06: Immediate Bitwise AND (20 & 15)");
        
        execute_cycle(); // ori x6, x1, 5
        check_reg(6, 32'd15, "TC07: Immediate Bitwise OR (10 | 5)");
        
        execute_cycle(); // xori x7, x1, 3
        check_reg(7, 32'd9, "TC08: Immediate Bitwise XOR (10 ^ 3)");
        
        execute_cycle(); // slti x8, x1, 15
        check_reg(8, 32'd1, "TC09: Signed Set Less Than Immediate (10 < 15)");
        
        execute_cycle(); // sltiu x9, x1, 5
        check_reg(9, 32'd0, "TC10: Unsigned Set Less Than Immediate (10 < 5)");
        
        execute_cycle(); // slli x10, x1, 2
        check_reg(10, 32'd40, "TC11: Shift Left Logical Immediate (10 << 2)");
        
        execute_cycle(); // srli x11, x2, 2
        check_reg(11, 32'd5, "TC12: Shift Right Logical Immediate (20 >> 2)");
        
        execute_cycle(); // srai x12, x2, 1
        check_reg(12, 32'd10, "TC13: Shift Right Arithmetic Immediate Positive Base");
        
        execute_cycle(); // addi x13, x0, -4
        check_reg(13, 32'hfffffffc, "TC14: Create negative reference value (-4)");
        
        execute_cycle(); // srai x14, x13, 2
        check_reg(14, 32'hffffffff, "TC15: Shift Right Arithmetic Immediate Negative Base (Sign Extension)");

        
        // SECTION 3: R-TYPE LOGICAL & SHIFT OPERATIONS
        
        print_header("Section 3: Register-Register Shifts & Logic");
        
        execute_cycle(); // and x15, x3, x4
        check_reg(15, 32'd10, "TC16: R-Type Bitwise AND");
        
        execute_cycle(); // or x16, x3, x4
        check_reg(16, 32'd30, "TC17: R-Type Bitwise OR");
        
        execute_cycle(); // xor x17, x3, x4
        check_reg(17, 32'd20, "TC18: R-Type Bitwise XOR");
        
        execute_cycle(); // sll x18, x1, x5
        check_reg(18, 32'd160, "TC19: R-Type Shift Left Logical (10 << 4)");
        
        execute_cycle(); // srl x19, x18, x5
        check_reg(19, 32'd10, "TC20: R-Type Shift Right Logical (160 >> 4)");
        
        execute_cycle(); // sra x20, x13, x5
        check_reg(20, 32'hffffffff, "TC21: R-Type Shift Right Arithmetic Negative Base");

        
        // SECTION 4: UPPER IMMEDIATE OPERATIONS
        
        print_header("Section 4: Upper Immediate Verification");
        
        execute_cycle(); // lui x21, 0x12345
        check_reg(21, 32'h12345000, "TC22: Load Upper Immediate (LUI)");
        
        execute_cycle(); // auipc x22, 0x02000
        check_reg(22, 32'h02000058, "TC23: Add Upper Immediate to PC (AUIPC)");

        
        // SECTION 5: LOADS & STORES (SIGN VS ZERO EXTENSIONS CHECK)
        
        print_header("Section 5: Data Memory Extensions & Accesses");
        
        execute_cycle(); // addi x23, x0, 0
        execute_cycle(); // addi x24, x0, 255
        execute_cycle(); // sb x24, 0(x23)
        check_pc(32'h68, "TC24-26: Store Byte execution tracking");
        
        execute_cycle(); // lb x25, 0(x23)
        check_reg(25, 32'hffffffff, "TC27: Load Byte (LB) - verifying forced sign-extension of 0xFF");
        
        execute_cycle(); // lbu x26, 0(x23)
        check_reg(26, 32'h000000ff, "TC28: Load Byte Unsigned (LBU) - verifying forced zero-extension of 0xFF");
        
        execute_cycle(); // lui x24, 8
        execute_cycle(); // sh x24, 4(x23)
        check_pc(32'h78, "TC29-30: Store Halfword execution tracking");
        
        execute_cycle(); // lh x27, 4(x23)
        check_reg(27, 32'hffff8000, "TC31: Load Halfword (LH) - verifying forced sign-extension of 0x8000");
        
        execute_cycle(); // lhu x28, 4(x23)
        check_reg(28, 32'h00008000, "TC32: Load Halfword Unsigned (LHU) - verifying forced zero-extension of 0x8000");
        
        execute_cycle(); // sw x3, 8(x23)
        execute_cycle(); // lw x29, 8(x23)
        check_reg(29, 32'd30, "TC33-34: Store Word and Load Word verification match");

        
        // SECTION 6: BRANCH EVALUATION MATRICES
        
        print_header("Section 6: Exhaustive Branch Evaluation Conditions");
        
        execute_cycle(); // beq x1, x1, 8 -> Taken
        check_pc(32'h90, "TC35: BEQ Condition - Taken Path Validation");
        
        execute_cycle(); // beq x1, x2, 8 -> Not Taken
        check_pc(32'h94, "TC36: BEQ Condition - Bypassed Path Validation");
        
        execute_cycle(); // bne x1, x2, 8 -> Taken
        check_pc(32'h9C, "TC37: BNE Condition - Taken Path Validation");
        
        execute_cycle(); // bne x1, x1, 8 -> Not Taken
        check_pc(32'hA0, "TC38: BNE Condition - Bypassed Path Validation");
        
        execute_cycle(); // blt x1, x2, 8 -> Taken (10 < 20)
        check_pc(32'hA8, "TC39: BLT Signed Condition - Taken Path Validation");
        
        execute_cycle(); // blt x2, x1, 8 -> Not Taken
        check_pc(32'hAC, "TC40: BLT Signed Condition - Bypassed Path Validation");
        
        execute_cycle(); // blt x13, x1, 8 -> Taken (-4 < 10)
        check_pc(32'hB4, "TC41: BLT Signed Negative Condition - Taken Path Validation");
        
        execute_cycle(); // bge x2, x1, 8 -> Taken (20 >= 10)
        check_pc(32'hBC, "TC42: BGE Signed Condition - Taken Path Validation");
        
        execute_cycle(); // bge x1, x2, 8 -> Not Taken
        check_pc(32'hC0, "TC43: BGE Signed Condition - Bypassed Path Validation");
        
        execute_cycle(); // bltu x1, x2, 8 -> Taken (10 < 20 unsigned)
        check_pc(32'hC8, "TC44: BLTU Unsigned Condition - Taken Path Validation");
        
        execute_cycle(); // bltu x13, x1, 8 -> Not Taken (0xFFFFFFFC < 10 is false)
        check_pc(32'hCC, "TC45: BLTU Unsigned Condition - Bypassed Path Validation");
        
        execute_cycle(); // bgeu x13, x1, 8 -> Taken (0xFFFFFFFC >= 10 unsigned)
        check_pc(32'hD4, "TC46: BGEU Unsigned Condition - Taken Path Validation");

        
        // SECTION 7: CONTROL FLOW JUMP CONTROL
        
        print_header("Section 7: Asynchronous Control Flow Jumps");
        
        execute_cycle(); // jal x31, 8
        check_reg(31, 32'hD8, "TC47: JAL link target stored inside x31");
        check_pc(32'hDC, "TC48: JAL destination targeting path routing routing");
        
        execute_cycle(); // addi x10, x0, 228 (0xE4)
        execute_cycle(); // jalr x1, x10, 0
        check_reg(1, 32'hE4, "TC49: JALR link target stored inside x1");
        check_pc(32'hE4, "TC50: JALR destination targeting path routing");
        
        execute_cycle(); // NOP Target buffer instruction catch
        check_pc(32'hE8, "TC51: Target code recovery check");

        
        // SECTION 8: ERROR ACCURACY & SYSTEM BOUNDARY FAULTS
        
        print_header("Section 8: Boundary Conditions & Assertion Diagnostics");
        
        execute_cycle(); // addi x2, x0, 1
        
        $display("[INFO] Triggering unaligned data load assertion...");
        execute_cycle(); // lw x3, 0(x2) - Misaligned Word Load Fault
        
        $display("[INFO] Triggering unaligned data store assertion...");
        execute_cycle(); // sw x3, 0(x2) - Misaligned Word Store Fault
        
        $display("[INFO] Triggering out-of-bounds memory load address mapping...");
        execute_cycle(); // lw x4, 2000(x0) - Address Out of Depth Bounds
        
        execute_cycle(); // addi x10, x0, 1024
        
        $display("[INFO] Directing PC to execute out-of-range memory address space fetch...");
        execute_cycle(); // jalr x0, x10, 0 - Instruction Boundary Fault
        check_pc(32'd1024, "TC52: Program Counter forced out of structural RAM limits");

        // Finish and present localized execution matrix summary
        summary();
        $finish;
    end

endmodule