# RV32I Directed Tests
# Conventions used:
#   x3  (gp)  : current sub-test number, the testbench watches this to know where it died
#   x10 (a0)  : exit code (0 = PASS. non-zero = failing test number)
#   x1  (ra)  : link register for JAL / JALR
#   others used in tests
#
# Flow: each test sets x3, runs its checks, and branches to fail on the first wrong value.
# If everything passes we fall through into the pass block.
# On completion of all tests it executes sentinel 0x00000400 (and ecall)

.section .text.init
.global _start

_start:

# __________________________________________________________________________________________________

# PART 1: Integer Arithmetic and Logic (R and I type instructions)

# Test 1: ADD (5 + 7 = 12)
test1:
    addi x3, x0, 1
    addi x5, x0, 5
    addi x6, x0, 7
    add  x7, x5, x6
    addi x8, x0, 12
    bne  x7, x8, fail

# Test 2: SUB (100 - 37 = 63)
test2:
    addi x3, x0, 2
    addi x5, x0, 100
    addi x6, x0, 37
    sub  x7, x5, x6
    addi x8, x0, 63
    bne  x7, x8, fail

# Test 3: ADD with negative operands / two's complement (-1 + 1 = 0, -10 + 3 = -7)
test3:
    addi x3, x0, 3
    addi x5, x0, -1
    addi x6, x0, 1
    add  x7, x5, x6
    bne  x7, x0, fail
    addi x5, x0, -10
    addi x6, x0, 3
    add  x7, x5, x6
    addi x8, x0, -7
    bne  x7, x8, fail

# Test 4: ADD 32-bit overflow wrap-around (0x7FFFFFFF + 1 = 0x80000000)
test4:
    addi x3, x0, 4
    lui  x5, 0x80000          # x5 = 0x80000000
    lui  x6, 0x80000
    addi x6, x6, -1           # x6 = 0x7FFFFFFF
    addi x7, x6, 1            # 0x7FFFFFFF + 1 -> 0x80000000
    bne  x7, x5, fail

# Test 5: ADDI with positive, negative, and zero immediates
test5:
    addi x3, x0, 5
    addi x5, x0, 0
    bne  x5, x0, fail
    addi x5, x0, 2047        # Max positive 12-bit signed immediate
    addi x6, x5, -2048       # Min negative 12-bit signed immediate
    addi x7, x0, -1
    bne  x6, x7, fail

# Test 6: AND and ANDI bitwise masking
test6:
    addi x3, x0, 6
    li   x5, 0xAAAAAAAA
    li   x6, 0x55555555
    and  x7, x5, x6
    bne  x7, x0, fail
    li   x5, 0x12345678
    andi x6, x5, 0x078
    addi x7, x0, 0x078
    bne  x6, x7, fail

# Test 7: OR and ORI bitwise operations
test7:
    addi x3, x0, 7
    li   x5, 0x00FF0000
    li   x6, 0x0000FF00
    or   x7, x5, x6
    li   x8, 0x00FFFF00
    bne  x7, x8, fail
    ori  x9, x7, 0x0FF
    li   x10, 0x0FFFFFF
    bne  x9, x10, fail

# Test 8: XOR and XORI bitwise operations
test8:
    addi x3, x0, 8
    li   x5, 0xFFFFFFFF
    li   x6, 0x0F0F0F0F
    xor  x7, x5, x6
    li   x8, 0xF0F0F0F0
    bne  x7, x8, fail
    xori x9, x7, 0x0F0
    li   x10, 0xF0F0F000
    bne  x9, x10, fail

# Test 9: SLL and SLLI (Logical Shift Left)
test9:
    addi x3, x0, 9
    addi x5, x0, 1
    slli x6, x5, 4           # 1 << 4 = 16
    addi x7, x0, 16
    bne  x6, x7, fail
    addi x8, x0, 31
    sll  x9, x5, x8          # 1 << 31 = 0x80000000
    lui  x10, 0x80000
    bne  x9, x10, fail
    slli x11, x5, 0          # shift by 0
    bne  x11, x5, fail

# Test 10: SRL and SRLI (Logical Shift Right, zero fill)
test10:
    addi x3, x0, 10
    lui  x5, 0x80000         # 0x80000000
    srli x6, x5, 1           # 0x40000000
    lui  x7, 0x40000
    bne  x6, x7, fail
    addi x8, x0, 31
    srl  x9, x5, x8          # 0x80000000 >> 31 = 1
    addi x10, x0, 1
    bne  x9, x10, fail

# Test 11: SRA and SRAI (Arithmetic Shift Right, sign extension)
test11:
    addi x3, x0, 11
    addi x5, x0, -16
    srai x6, x5, 2           # -16 >> 2 = -4
    addi x7, x0, -4
    bne  x6, x7, fail
    addi x8, x0, 31
    sra  x9, x5, x8          # -16 >> 31 = -1
    addi x10, x0, -1
    bne  x9, x10, fail

# Test 12: SLT and SLTI (Set Less Than, Signed)
test12:
    addi x3, x0, 12
    addi x5, x0, -5
    addi x6, x0, 3
    slt  x7, x5, x6          # -5 < 3 -> 1
    addi x8, x0, 1
    bne  x7, x8, fail
    slt  x9, x6, x5          # 3 < -5 -> 0
    bne  x9, x0, fail
    slti x10, x5, 0          # -5 < 0 -> 1
    bne  x10, x8, fail
    slti x11, x6, 0          # 3 < 0 -> 0
    bne  x11, x0, fail

# Test 13: SLTU and SLTIU (Set Less Than, Unsigned)
test13:
    addi x3, x0, 13
    addi x5, x0, 1
    addi x6, x0, -1          # 0xFFFFFFFF unsigned
    sltu x7, x5, x6          # 1 < 0xFFFFFFFF -> 1
    addi x8, x0, 1
    bne  x7, x8, fail
    sltu x9, x6, x5          # 0xFFFFFFFF < 1 -> 0
    bne  x9, x0, fail
    sltiu x10, x6, 1         # 0xFFFFFFFF < 1 -> 0
    bne  x10, x0, fail
    sltiu x11, x5, 2         # 1 < 2 -> 1
    bne  x11, x8, fail

# __________________________________________________________________________________________________

# PART 2: Upper Immediate and Address Calculation (LUI, AUIPC)

# Test 14: LUI (Load Upper Immediate)
test14:
    addi x3, x0, 14
    lui  x5, 0x12345         # x5 = 0x12345000
    srli x6, x5, 12
    li   x7, 0x12345
    bne  x6, x7, fail
    li   x7, 0xFFF
    and  x8, x5, x7          # Lower 12 bits must be zero
    bne  x8, x0, fail

# Test 15: AUIPC (Add Upper Immediate to PC)
test15:
    addi x3, x0, 15
t15_here:
    auipc x5, 0              # x5 = PC of t15_here
    jal   x6, t15_next       # x6 = PC of t15_here + 8 (return address)
t15_next:
    sub   x7, x6, x5         # Difference must be exactly 8 bytes
    addi  x8, x0, 8
    bne   x7, x8, fail

# Test 16: AUIPC + JALR Target Resolution (PIC calling convention)
test16:
    addi x3, x0, 16
    la    x5, t16_target     # Expands to auipc + addi
    jalr  x1, x5, 0          # Jump to computed target
    j     fail
t16_target:
    addi  x6, x0, 42
    addi  x7, x0, 42
    bne   x6, x7, fail

# __________________________________________________________________________________________________

# PART 3: Memory Operations (Stores and Loads of All Sizes and Alignments)

# Test 17: SW + LW (Store Word and Load Word Round-Trip)
test17:
    addi x3, x0, 17
    lui  x9, 2               # Base scratch address: 0x2000
    li   x10, 0xDEADBEEF
    sw   x10, 0(x9)
    lw   x11, 0(x9)
    bne  x11, x10, fail

# Test 18: SB + LB / LBU at byte offset 0 (Sign vs Zero Extension)
test18:
    addi x3, x0, 18
    lui  x9, 2
    addi x10, x0, 0x7F       # +127
    sb   x10, 0(x9)
    lb   x11, 0(x9)
    bne  x11, x10, fail
    addi x12, x0, -1         # 0xFF
    sb   x12, 0(x9)
    lb   x13, 0(x9)          # Sign-extended -> -1
    bne  x13, x12, fail
    lbu  x14, 0(x9)          # Zero-extended -> 255
    addi x15, x0, 255
    bne  x14, x15, fail

# Test 19: SB + LB / LBU across byte offsets 1, 2, 3
test19:
    addi x3, x0, 19
    lui  x9, 2
    sw   x0, 0(x9)           # Clear word at 0x2000
    # Byte offset 1: negative byte 0x81 (-127 signed, 129 unsigned)
    addi x10, x0, -127
    sb   x10, 1(x9)
    lb   x11, 1(x9)
    bne  x11, x10, fail
    lbu  x12, 1(x9)
    addi x13, x0, 129
    bne  x12, x13, fail

    # Byte offset 2: positive byte 0x5A (90)
    addi x14, x0, 90
    sb   x14, 2(x9)
    lb   x15, 2(x9)
    bne  x15, x14, fail

    # Byte offset 3: negative byte 0xFE (-2 signed, 254 unsigned)
    addi x16, x0, -2
    sb   x16, 3(x9)
    lb   x17, 3(x9)
    bne  x17, x16, fail
    lbu  x18, 3(x9)
    addi x19, x0, 254
    bne  x18, x19, fail

# Test 20: Byte lane isolation (4 separate SBs form full word)
test20:
    addi x3, x0, 20
    lui  x9, 2
    addi x10, x0, 0x12
    addi x11, x0, 0x34
    addi x12, x0, 0x56
    addi x13, x0, 0x78
    sb   x10, 0(x9)          # byte 0 = 0x12
    sb   x11, 1(x9)          # byte 1 = 0x34
    sb   x12, 2(x9)          # byte 2 = 0x56
    sb   x13, 3(x9)          # byte 3 = 0x78
    lw   x14, 0(x9)          # little-endian word = 0x78563412
    li   x15, 0x78563412
    bne  x14, x15, fail

# Test 21: SH + LH / LHU at halfword offsets 0 and 2
test21:
    addi x3, x0, 21
    lui  x9, 2
    # Offset 0: negative halfword 0x8001 (-32767 signed, 32769 unsigned)
    li   x10, -32767
    sh   x10, 0(x9)
    lh   x11, 0(x9)
    bne  x11, x10, fail
    lhu  x12, 0(x9)
    li   x13, 32769
    bne  x12, x13, fail

    # Offset 2: positive halfword 0x1234
    li   x14, 0x1234
    sh   x14, 2(x9)
    lh   x15, 2(x9)
    bne  x15, x14, fail
    lhu  x16, 2(x9)
    bne  x16, x14, fail

# Test 22: Halfword lane isolation (two SHs form full word)
test22:
    addi x3, x0, 22
    lui  x9, 2
    li   x10, 0x1122
    li   x11, 0x3344
    sh   x10, 0(x9)          # halfword 0 = 0x1122
    sh   x11, 2(x9)          # halfword 1 = 0x3344
    lw   x12, 0(x9)          # packed word = 0x33441122
    li   x13, 0x33441122
    bne  x12, x13, fail

# Test 23: Load and Store with negative immediate offset
test23:
    addi x3, x0, 23
    lui  x9, 2
    addi x9, x9, 16          # x9 = 0x2010
    li   x10, 0xCAFEBABE
    sw   x10, -8(x9)         # store to 0x2008
    lw   x11, -8(x9)         # load from 0x2008
    bne  x11, x10, fail

# __________________________________________________________________________________________________

# PART 4: Control Flow (Branches and Jumps)

# Test 24: BEQ taken and not-taken
test24:
    addi x3, x0, 24
    addi x5, x0, 42
    addi x6, x0, 42
    beq  x5, x6, t24_taken
    j    fail
t24_taken:
    addi x6, x0, 43
    beq  x5, x6, fail        # Must NOT branch

# Test 25: BNE taken and not-taken
test25:
    addi x3, x0, 25
    addi x5, x0, 10
    addi x6, x0, 20
    bne  x5, x6, t25_taken
    j    fail
t25_taken:
    bne  x5, x5, fail        # Must NOT branch

# Test 26: BLT and BGE (Signed Comparisons)
test26:
    addi x3, x0, 26
    addi x5, x0, -10
    addi x6, x0, 5
    blt  x5, x6, t26_blt_ok  # -10 < 5 -> taken
    j    fail
t26_blt_ok:
    bge  x6, x5, t26_bge_ok  # 5 >= -10 -> taken
    j    fail
t26_bge_ok:
    blt  x6, x5, fail        # 5 < -10 -> not taken
    bge  x5, x5, t26_eq_ok   # -10 >= -10 -> taken
    j    fail
t26_eq_ok:
    nop

# Test 27: BLTU and BGEU (Unsigned Comparisons)
test27:
    addi x3, x0, 27
    addi x5, x0, 1
    addi x6, x0, -1          # 0xFFFFFFFF unsigned
    bltu x5, x6, t27_bltu_ok # 1 < 0xFFFFFFFF -> taken
    j    fail
t27_bltu_ok:
    bgeu x6, x5, t27_bgeu_ok # 0xFFFFFFFF >= 1 -> taken
    j    fail
t27_bgeu_ok:
    bltu x6, x5, fail        # not taken
    bgeu x6, x6, t27_eq_ok   # taken
    j    fail
t27_eq_ok:
    nop

# Test 28: JAL (Jump and Link) - verify target jump and return address rd = PC+4
test28:
    addi x3, x0, 28
t28_jal_call:
    auipc x5, 0              # x5 = PC of t28_jal_call
    jal   x6, t28_target     # x6 = PC of t28_jal_call + 8
    j     fail
t28_target:
    sub   x7, x6, x5         # Difference must be 8
    addi  x8, x0, 8
    bne   x7, x8, fail

# Test 29: JALR (Jump and Link Register) with offset and return address verification
test29:
    addi x3, x0, 29
    la    x5, t29_target
t29_jalr_call:
    auipc x6, 0              # x6 = PC of t29_jalr_call
    jalr  x7, x5, 0          # x7 = PC of t29_jalr_call + 8
    j     fail
t29_target:
    sub   x8, x7, x6         # Difference must be 8
    addi  x10, x0, 8
    bne   x8, x10, fail
    # Test JALR with non zero immediate offset:
    la    x5, t29_target2 - 12
    jalr  x0, x5, 12         # Target: (x5 + 12) = t29_target2
    j     fail
t29_target2:
    nop

# Test 30: JALR LSB Clear Behavior ((rs1 + imm) and ~1)
test30:
    addi x3, x0, 30
    la    x5, t30_target
    ori   x5, x5, 1          # Set bit 0 (odd address)
    jalr  x0, x5, 0          # Hardware must mask bit 0 to jump to even address
    j     fail
t30_target:
    nop

# __________________________________________________________________________________________________

# PART 5: Pipeline Hazards and Forwarding Stress

# Test 31: EX-to-EX Data Forwarding Chain (Consecutive Dependent Instructions)
test31:
    addi x3, x0, 31
    addi x5, x0, 1
    add  x6, x5, x5          # x6 = 2  (EX->EX forward from x5)
    add  x7, x6, x6          # x7 = 4  (EX->EX forward from x6)
    add  x8, x7, x7          # x8 = 8  (EX->EX forward from x7)
    add  x9, x8, x8          # x9 = 16 (EX->EX forward from x8)
    addi x10, x0, 16
    bne  x9, x10, fail

# Test 32: MEM-to-EX Data Forwarding (1 Bubble/Independent Instruction Between)
test32:
    addi x3, x0, 32
    addi x5, x0, 7
    nop                      # gap so value comes via the bypass from WB
    addi x6, x5, 3           # x6 = 10 (MEM->EX forward from x5)
    addi x7, x0, 10
    bne  x6, x7, fail

# Test 33: Simultaneous Forwarding for Both rs1 and rs2
test33:
    addi x3, x0, 33
    addi x5, x0, 10
    addi x6, x0, 20
    add  x7, x5, x6          # x5 from MEM, x6 from EX
    addi x8, x0, 30
    bne  x7, x8, fail

# Test 34: Load-Use Hazard with ALU Instruction (1-Cycle Stall + Forward)
test34:
    addi x3, x0, 34
    lui  x9, 2
    li   x10, 500
    sw   x10, 0(x9)
    lw   x11, 0(x9)          # Load in EX
    addi x12, x11, 15        # Dependent use in ID: HazardUnit must stall 1 cycle
    li   x13, 515
    bne  x12, x13, fail

# Test 35: Load-Use Hazard with Branch Condition
test35:
    addi x3, x0, 35
    lui  x9, 2
    li   x10, 777
    sw   x10, 0(x9)
    lw   x11, 0(x9)          # Load in EX
    beq  x11, x10, t35_taken # Branch in ID: must stall, then evaluate condition
    j    fail
t35_taken:
    nop

# Test 36: Load-to-Store Data Forwarding (Load used as Store Data)
test36:
    addi x3, x0, 36
    lui  x9, 2
    li   x10, 0x55AA
    sw   x10, 0(x9)
    lw   x11, 0(x9)          # Load data
    sw   x11, 4(x9)          # Store data immediately (load-to-store forward)
    lw   x12, 4(x9)
    bne  x12, x10, fail

# Test 37: Load-Use Hazard with Store Base Address
test37:
    addi x3, x0, 37
    lui  x9, 2
    addi x10, x9, 8          # Target address = 0x2008
    sw   x10, 0(x9)
    li   x11, 0x12345678
    lw   x12, 0(x9)          # Load address into x12
    sw   x11, 0(x12)         # Store using x12 immediately: must stall 1 cycle
    lw   x13, 8(x9)          # Verify data arrived at 0x2008
    bne  x13, x11, fail

# Test 38: EX-to-MEM Store Data Forwarding (ALU Result Stored Next Cycle)
test38:
    addi x3, x0, 38
    lui  x9, 2
    addi x10, x0, 10
    addi x11, x10, 20        # x11 = 30 (computed in EX)
    sw   x11, 0(x9)          # Stored next cycle: EX->MEM forward
    lw   x12, 0(x9)
    addi x13, x0, 30
    bne  x12, x13, fail

# Test 39: RAW Memory Hazard (Store followed immediately by Load from same address)
test39:
    addi x3, x0, 39
    lui  x9, 2
    li   x10, 0x98765432
    sw   x10, 0(x9)          # Store in cycle N
    lw   x11, 0(x9)          # Load in cycle N+1
    bne  x11, x10, fail

# __________________________________________________________________________________________________

# PART 6: Pipeline Flush, Branch Prediction and Architectural Corner Cases

# Test 40: Branch Taken Flush Verification (Delay-Slot Instructions Flushed)
test40:
    addi x3, x0, 40
    addi x6, x0, 0
    addi x7, x0, 1
    beq  x7, x7, t40_target
    addi x6, x0, 99          # MUST BE FLUSHED: never execute!
    addi x6, x0, 100         # MUST BE FLUSHED: never execute!
t40_target:
    bne  x6, x0, fail        # If x6 != 0, pipeline flush failed!
    # Also verify store instruction in flush slot does not commit:
    lui  x9, 2
    sw   x0, 0(x9)
    beq  x7, x7, t40_target2
    addi x8, x0, 0x55
    sw   x8, 0(x9)           # MUST BE FLUSHED: must not write to memory!
t40_target2:
    lw   x10, 0(x9)
    bne  x10, x0, fail

# Test 41: JAL / JALR Flush Verification (Instructions Following Jump Flushed)
test41:
    addi x3, x0, 41
    addi x6, x0, 0
    jal  x1, t41_target
    addi x6, x0, 77          # MUST BE FLUSHED!
t41_target:
    bne  x6, x0, fail

# Test 42: Register x0 Hardwired to Zero (Invariance Under Writes and Forwarding)
test42:
    addi x3, x0, 42
    addi x0, x0, 123         # Attempt ADDI to x0
    bne  x0, x0, fail
    lui  x0, 0x12345         # Attempt LUI to x0
    bne  x0, x0, fail
    add  x0, x3, x3          # Attempt ADD to x0
    bne  x0, x0, fail
    # Forwarding unit must not forward written values for x0:
    addi x0, x0, 99
    addi x5, x0, 0           # x5 must read 0, NOT forwarded 99!
    bne  x5, x0, fail

# Test 43: Branch Predictor Training Loop (Trains 2-Bit Counter to Strongly Taken)
test43:
    addi x3, x0, 43
    addi x5, x0, 8           # Loop 8 times
    addi x6, x0, 0
t43_loop:
    addi x6, x6, 1
    addi x5, x5, -1
    bne  x5, x0, t43_loop    # Trains predictor to taken, exits when x5 == 0
    addi x7, x0, 8
    bne  x6, x7, fail

# Test 44: Alternating Branch Pattern (Stress Dynamic Prediction)
test44:
    addi x3, x0, 44
    addi x5, x0, 4
    addi x6, x0, 0
t44_loop:
    andi x7, x5, 1
    beq  x7, x0, t44_even
    addi x6, x6, 1           # Odd iteration
    j    t44_next
t44_even:
    addi x6, x6, 2           # Even iteration
t44_next:
    addi x5, x5, -1
    bne  x5, x0, t44_loop
    addi x8, x0, 6           # 4(even:+2) + 3(odd:+1) + 2(even:+2) + 1(odd:+1) = 6
    bne  x6, x8, fail

# Test 45: Consecutive Back-to-Back Branch and Jump Sequences
test45:
    addi x3, x0, 45
    addi x5, x0, 5
    beq  x5, x0, fail        # Not-taken branch
    bne  x5, x0, t45_step1   # Taken branch
    j    fail
t45_step1:
    beq  x5, x5, t45_step2   # Immediately following taken branch
    j    fail
t45_step2:
    jal  x0, t45_step3       # Immediately following jump
    j    fail
t45_step3:
    nop

# __________________________________________________________________________________________________

# Part 7: extra forwarding and corner cases

# test 46: branch compares against a value produced one instruction earlier
test46:
    addi x3, x0, 46
    addi x7, x0, 9
    addi x8, x0, 2
    blt  x8, x7, t46_ok      # x7 is forwarded into the branch
    j    fail
t46_ok:
    addi x9, x0, 5
    addi x10, x0, 5
    bne  x9, x10, fail       # x10 forwarded, should not branch

# test 47: jalr base register produced by la right before the jump
test47:
    addi x3, x0, 47
    la    x5, t47_target
    jalr  x0, x5, 0
    j     fail
t47_target:
    nop

# test 48: shift amounts only use the low 5 bits
test48:
    addi x3, x0, 48
    addi x5, x0, 1
    addi x6, x0, 33          # 33 & 31 = 1
    sll  x7, x5, x6
    addi x8, x0, 2
    bne  x7, x8, fail
    addi x6, x0, 32          # 32 & 31 = 0
    srl  x9, x5, x6
    bne  x9, x5, fail

# test 49: byte store in the middle of a word, then read the whole word
test49:
    addi x3, x0, 49
    lui  x9, 2
    li   x10, 0xFFFFFFFF
    sw   x10, 0(x9)
    sb   x0, 1(x9)           # clear byte 1 only
    lw   x12, 0(x9)          # expect 0xFFFF00FF
    li   x13, 0xFFFF00FF
    bne  x12, x13, fail

# test 50: two loads back to back, both feeding one add
test50:
    addi x3, x0, 50
    lui  x9, 2
    addi x10, x0, 4
    sw   x10, 0(x9)
    addi x11, x0, 8
    sw   x11, 4(x9)
    lw   x12, 0(x9)
    lw   x13, 4(x9)
    add  x14, x12, x13       # second load feeds this right away
    addi x15, x0, 12
    bne  x14, x15, fail

# __________________________________________________________________________________________________

# PASS PATH: All tests succeeded!
pass:
    addi a0, x0, 0           # a0 = 0 (standard PASS code)
    .word 0x00000400         # Custom sentinel instruction detected by tb_cpu_directed
    ecall                    # Fallback termination for official testbenches
1:  j 1b



# FAIL PATH: Sub-test failed! Write failing test number into a0 and ecall

fail:
    add  a0, x0, x3          # a0 = failing sub-test number (non-zero -> FAIL)
    ecall    
1:  j 1b
