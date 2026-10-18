# Directed Tests Coverage
This document outlines the detailed coverage provided by the 50 self-checking directed subtests implemented in [`tests/directed_tests.S`](../tests/directed_tests.S).
## Subtest Coverage Breakdown
| Test range | Coverage |
|---|---|
| **1–5** | Basic arithmetic, subtraction, two's complement, 32-bit overflow behaviour, and immediate arithmetic (`ADD`, `SUB`, `ADDI`). |
| **6–8** | Bitwise operations: `AND`, `OR`, and `XOR`, including register-register and immediate variants (`ANDI`, `ORI`, `XORI`). |
| **9–11** | Logical and arithmetic shifts: `SLL`, `SRL`, `SRA`, `SLLI`, `SRLI`, `SRAI`. |
| **12–13** | Signed and unsigned comparisons using `SLT`, `SLTI`, `SLTU`, and `SLTIU`. |
| **14–16** | Upper immediates and PC-relative addressing: `LUI`, `AUIPC`, `JAL`, and `AUIPC`/`JALR` sequences. |
| **17–23** | Memory access: Byte, halfword, and word loads and stores (`LB`, `LBU`, `LH`, `LHU`, `LW`, `SB`, `SH`, `SW`); sign and zero extension; little-endian layout; negative offsets. |
| **24–27** | Conditional branches: `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, covering taken and not-taken paths. |
| **28–30** | Control flow: `JAL`/`JALR` jump targets, link register updates (`ra`), non-zero offsets, and LSB masking on `JALR` targets. |
| **31–33** | Hazard resolution: Data forwarding across dependent instructions (EX→EX and MEM→EX paths). |
| **34–39** | Pipeline hazards: Load-use hazard detection and stalling, branch dependencies, load-to-store forwarding, dependent store addresses, store-data forwarding, and store/load memory consistency. |
| **40–41** | Pipeline flushing: Speculative execution recovery after branches/jumps, ensuring flushed instructions (especially stores) do not mutate architectural state or memory. |
| **42** | Constant register enforcement: Verification that register `x0` remains hardwired to zero under attempted writes and forwarding paths. |
| **43–45** | Branch predictor stress: 2-bit saturating counter state machine transitions, alternating branch patterns, and consecutive branch/jump sequences. |
| **46–47** | Dependency corners: Forwarding directly into branch operand comparisons and resolving `JALR` base-register dependencies. |
| **48–50** | Edge cases: Shift amounts masking to low 5 bits (`shift_amt[4:0]`), byte-lane write isolation, and back-to-back load operations feeding dependent ALU instructions. |
## Execution & Verification Guarantees
Every subtest strictly executes its assertions sequentially. If any check fails, the execution diverges immediately to the `fail` routine via conditional branch (`bne ... fail`), placing the failed test number into `a0` and triggering an `ecall`. 
Overall success is determined strictly when the processor reaches the final sentinel block and successfully retires the custom marker instruction (`0x00000400`) or standard exit `ecall` with `a0 == 0`.
