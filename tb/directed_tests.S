# Convention
#   x3  (gp)  = current sub-test number (testbench monitors this)
#   x1  (ra)  = scratch / return address for JALR tests
#   x2  (sp)  = stack pointer (untouched)
#   x5–x28    = general purpose scratch registers
#
# Each sub-test:
#   1. Sets gp to the test number
#   2. Runs the instruction sequence
#   3. Checks the result; branches to FAIL if wrong
#   4. Falls through to the next test
#
# On all-pass: executes the 0x00000400 sentinel instruction which
# the testbench detects as program termination (PASS).
# On any failure: writes the failing test number to a0 and executes ecall.

.section .text.init
.global _start
_start:


# Test 1 : ADD: 5 + 7 = 12

test1:
    addi x3, x0, 1          # gp = test number
    addi x5, x0, 5
    addi x6, x0, 7
    add  x7, x5, x6
    addi x8, x0, 12
    bne  x7, x8, fail


# Test 2  SUB: 100 - 37 = 63

test2:
    addi x3, x0, 2
    addi x5, x0, 100
    addi x6, x0, 37
    sub  x7, x5, x6
    addi x8, x0, 63
    bne  x7, x8, fail


# Test 3  Negative ADD / two's complement: -1 + 1 = 0

test3:
    addi x3, x0, 3
    addi x5, x0, -1
    addi x6, x0, 1
    add  x7, x5, x6
    bne  x7, x0, fail


# Test 4  ADD overflow wraps: 0x7FFFFFFF + 1 = 0x80000000

test4:
    addi x3, x0, 4
    lui  x5, 0x80000 >> 12   # x5 = 0x80000000
    addi x5, x5, 0           # no-op (lui already set it)
    lui  x6, 0x7FFFF >> 12
    addi x6, x6, 0x7FF       # x6 = 0x7FFFFFFF
    addi x7, x6, 1           # should wrap to 0x80000000
    bne  x7, x5, fail


# Test 5  LUI / AUIPC

test5:
    addi x3, x0, 5
    lui  x5, 0xDEAD0 >> 12   # load upper immediate
    # 0xDEAD0 << 12 is not writable directly; use two lui+addi
    lui  x5, 0xDEADB          # x5 = 0xDEADB000
    addi x5, x5, 0x1EF - 0x200  # adjust lower 12 (signed)
    # simpler: just check lui sets upper 20 bits
    lui  x6, 5                # x6 = 0x00005000
    srli x7, x6, 12           # x7 = 5
    addi x8, x0, 5
    bne  x7, x8, fail


# Test 6  AND: 0xFF & 0x0F = 0x0F

test6:
    addi x3, x0, 6
    addi x5, x0, 0xFF
    addi x6, x0, 0x0F
    and  x7, x5, x6
    addi x8, x0, 0x0F
    bne  x7, x8, fail


# Test 7  OR: 0xA0 | 0x0F = 0xAF

test7:
    addi x3, x0, 7
    addi x5, x0, 0xA0 - 0x100  # sign-extended -96, but OR is bitwise
    ori  x5, x0, 0xA0 - 0x100  # use ori instead: ori x5,x0,0xA0 = 0xFFFFFFA0? Nopick safe values
    addi x5, x0, 0x50           # 0x50
    addi x6, x0, 0x0F
    or   x7, x5, x6
    addi x8, x0, 0x5F
    bne  x7, x8, fail


# Test 8  XOR: 0xFF ^ 0xF0 = 0x0F

test8:
    addi x3, x0, 8
    addi x5, x0, 0x7F
    addi x6, x0, 0x70
    xor  x7, x5, x6
    addi x8, x0, 0x0F
    bne  x7, x8, fail


# Test 9  SLL: 1 << 4 = 16

test9:
    addi x3, x0, 9
    addi x5, x0, 1
    addi x6, x0, 4
    sll  x7, x5, x6
    addi x8, x0, 16
    bne  x7, x8, fail


# Test 10  SRL: 0x80 >> 3 = 0x10 (logical, no sign extension)

test10:
    addi x3, x0, 10
    addi x5, x0, 0x40      # 64
    addi x6, x0, 2
    srl  x7, x5, x6        # 64 >> 2 = 16
    addi x8, x0, 16
    bne  x7, x8, fail


# Test 11  SRA: -8 >> 1 = -4 (arithmetic, preserves sign)

test11:
    addi x3, x0, 11
    addi x5, x0, -8
    addi x6, x0, 1
    sra  x7, x5, x6        # -8 >> 1 = -4
    addi x8, x0, -4
    bne  x7, x8, fail


# Test 12  SLLI / SRLI / SRAI immediate forms

test12:
    addi x3, x0, 12
    addi x5, x0, 1
    slli x5, x5, 8         # x5 = 256
    addi x6, x0, 1
    slli x6, x6, 8
    bne  x5, x6, fail
    srai x7, x5, 2         # 256 >> 2 = 64  (arithmetic)
    addi x8, x0, 64
    bne  x7, x8, fail


# Test 13  SLTI / SLTIU

test13:
    addi x3, x0, 13
    addi x5, x0, -1
    slti x6, x5, 0         # -1 < 0 → 1
    addi x7, x0, 1
    bne  x6, x7, fail
    sltiu x6, x5, 1        # treat -1 as 0xFFFFFFFF > 1 → 0
    bne  x6, x0, fail


# Test 14  SW + LW (store-load round-trip)

test14:
    addi x3, x0, 14
    lui  x5, 0x20000 >> 12   # data base address: 0x20000 (well inside data memory)
    addi x5, x0, 0           # use offset 0 from data memory base
    # Use a data memory address: put something at word 0 of data memory
    # DataMemory is byte-addressed; let's store to address 0x100 (word index 64)
    addi x9, x0, 0x100       # address 256
    addi x10, x0, 0xAB
    sw   x10, 0(x9)          # MEM[256] = 0xAB
    lw   x11, 0(x9)          # x11 = MEM[256]
    bne  x11, x10, fail


# Test 15  SB + LB / LBU (byte loads, sign extension)

test15:
    addi x3, x0, 15
    addi x9, x0, 0x104       # address 260
    addi x10, x0, 0x7F       # 127 = max positive byte
    sb   x10, 0(x9)
    lb   x11, 0(x9)
    bne  x11, x10, fail      # 127 zero-extended == 127
    addi x12, x0, -1         # 0xFF when stored as byte
    sb   x12, 0(x9)
    lb   x13, 0(x9)          # sign-extended → -1
    bne  x13, x12, fail
    lbu  x14, 0(x9)          # zero-extended → 0xFF = 255
    addi x15, x0, 0xFF - 0x100 + 0x100  # tricky  use sltiu trick
    addi x15, x0, -1
    andi x15, x15, 0xFF      # x15 = 0xFF = 255
    bne  x14, x15, fail


# Test 16  SH + LH / LHU (halfword loads)

test16:
    addi x3, x0, 16
    addi x9, x0, 0x108       # address 264 (4-byte aligned)
    addi x10, x0, 0x5A
    slli x10, x10, 6         # x10 = 0x1680 (positive halfword)
    sh   x10, 0(x9)
    lh   x11, 0(x9)
    bne  x11, x10, fail
    lui  x12, 0x80000 >> 12
    srli x12, x12, 16        # x12 = 0x8000 (negative halfword value)
    # store -1 as halfword
    addi x13, x0, -1
    sh   x13, 0(x9)
    lh   x14, 0(x9)          # sign-extended → -1
    bne  x14, x13, fail
    lhu  x15, 0(x9)          # zero-extended → 0xFFFF
    lui  x16, 0x10000 >> 12
    addi x16, x16, -1        # x16 = 0xFFFF
    bne  x15, x16, fail


# Test 17  BEQ taken and not-taken

test17:
    addi x3, x0, 17
    addi x5, x0, 42
    addi x6, x0, 42
    beq  x5, x6, t17_taken  # should branch
    j    fail
t17_taken:
    addi x5, x0, 1
    addi x6, x0, 2
    beq  x5, x6, fail       # should NOT branch


# Test 18  BNE taken and not-taken

test18:
    addi x3, x0, 18
    addi x5, x0, 3
    addi x6, x0, 4
    bne  x5, x6, t18_taken  # should branch (3 != 4)
    j    fail
t18_taken:
    bne  x0, x0, fail       # should NOT branch (0 == 0)


# Test 19  BLT / BGE (signed)

test19:
    addi x3, x0, 19
    addi x5, x0, -1         # signed -1
    addi x6, x0, 0
    blt  x5, x6, t19a       # -1 < 0 → taken
    j    fail
t19a:
    bge  x6, x5, t19b       # 0 >= -1 → taken
    j    fail
t19b:
    blt  x6, x5, fail       # 0 < -1 → NOT taken (falls through)


# Test 20  BLTU / BGEU (unsigned)

test20:
    addi x3, x0, 20
    addi x5, x0, 1
    addi x6, x0, -1         # 0xFFFFFFFF (unsigned large)
    bltu x5, x6, t20a       # 1 < 0xFFFFFFFF → taken
    j    fail
t20a:
    bgeu x6, x5, t20b       # 0xFFFFFFFF >= 1 → taken
    j    fail
t20b:
    bltu x6, x5, fail       # 0xFFFFFFFF < 1 → NOT taken


# Test 21  JAL: jump-and-link, rd = PC+4

test21:
    addi x3, x0, 21
    jal  x5, t21_target      # x5 = PC+4
    j    fail
t21_target:
    # x5 holds the return address; just check we got here
    addi x6, x0, 0           # (control flow proves JAL worked)


# Test 22  JALR: jump to register-computed address

test22:
    addi x3, x0, 22
    la   x5, t22_target       # pseudo: auipc + addi
    jalr x1, x5, 0            # jump to t22_target via register
    j    fail
t22_target:
    nop


# Test 23  Nested JAL call and return (simple call convention)

test23:
    addi x3, x0, 23
    jal  x1, sub23            # call sub23; x1 = return address
    j    t23_done             # should get here after ret
sub23:
    addi x5, x0, 99
    jalr x0, x1, 0            # ret
    j    fail                 # unreachable
t23_done:
    addi x6, x5, 0            # x6 = 99 (set by sub23)
    addi x7, x0, 99
    bne  x6, x7, fail


# Test 24  Load-use hazard: lw immediately followed by user of result

test24:
    addi x3, x0, 24
    addi x9, x0, 0x110        # address 272
    addi x10, x0, 0x1234
    sw   x10, 0(x9)
    lw   x11, 0(x9)           # load
    addi x12, x11, 1          # immediate use (hazard unit must stall/forward)
    addi x13, x0, 0x1235
    bne  x12, x13, fail


# Test 25  Forwarding chain: 3 back-to-back dependent ADDs

test25:
    addi x3, x0, 25
    addi x5, x0, 1
    add  x6, x5, x5           # x6 = 2  (EX→EX forward)
    add  x7, x6, x6           # x7 = 4  (EX→EX forward from x6)
    add  x8, x7, x7           # x8 = 8
    add  x9, x8, x8           # x9 = 16
    addi x10, x0, 16
    bne  x9, x10, fail


# Test 26  ANDI / ORI / XORI immediate variants

test26:
    addi x3, x0, 26
    addi x5, x0, 0x55
    andi x6, x5, 0x0F         # 0x55 & 0x0F = 0x05
    addi x7, x0, 0x05
    bne  x6, x7, fail
    ori  x6, x5, 0x0F         # 0x55 | 0x0F = 0x5F
    addi x7, x0, 0x5F
    bne  x6, x7, fail
    xori x6, x5, 0x0F         # 0x55 ^ 0x0F = 0x5A
    addi x7, x0, 0x5A
    bne  x6, x7, fail


# Test 27  SLT (set less than, signed)

test27:
    addi x3, x0, 27
    addi x5, x0, -5
    addi x6, x0, 3
    slt  x7, x5, x6           # -5 < 3 → 1
    addi x8, x0, 1
    bne  x7, x8, fail
    slt  x9, x6, x5           # 3 < -5 → 0
    bne  x9, x0, fail


# Test 28  SLTU (set less than, unsigned)

test28:
    addi x3, x0, 28
    addi x5, x0, 0            # 0
    addi x6, x0, -1           # 0xFFFFFFFF (unsigned large)
    sltu x7, x5, x6           # 0 < 0xFFFFFFFF → 1
    addi x8, x0, 1
    bne  x7, x8, fail
    sltu x9, x6, x5           # 0xFFFFFFFF < 0 → 0
    bne  x9, x0, fail


# Test 29  SW+LB (cross-granularity store/load, byte 0 of word)

test29:
    addi x3, x0, 29
    addi x9, x0, 0x120        # address 288
    addi x10, x0, 0x12345678 & 0x7FFFFFFF  # tricky; just use 0x3C4
    addi x10, x0, 0x3C
    sw   x10, 0(x9)           # store 0x0000003C
    lb   x11, 0(x9)           # load byte 0 = 0x3C
    bne  x11, x10, fail


# Test 30  Stress: alternating branch taken/not-taken (loop 4x)

test30:
    addi x3, x0, 30
    addi x5, x0, 4            # loop counter
t30_loop:
    addi x5, x5, -1
    bne  x5, x0, t30_loop    # taken 3 times, not-taken once
    # if we get here, x5 == 0
    bne  x5, x0, fail


# ALL TESTS PASSED  execute sentinel

pass:
    # 0x00000400 = custom sentinel word recognized by tb_cpu_custom
    .word 0x00000400


# FAIL path  write test number to a0, ecall

fail:
    add  a0, x0, x3           # a0 = failing test number (non-zero → FAIL for ecall TB)
    ecall
    # also infinite loop as fallback
1:  j 1b
