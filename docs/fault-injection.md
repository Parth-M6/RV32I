# Fault Injection Validation

This document describes the exhaustive RTL fault-injection campaign used to validate
the mutation-detection coverage of the regression suite.

## Methodology

Fault injection is performed in RTL files. Each fault is a single,
realistic RTL mutation applied to one source file in `rtl/`. After each mutation the
full `rv.py regress` suite (41 architectural compliance tests) is executed. A fault
is declared **CAUGHT** if at least one test fails, and **MISSED** if all 41 still pass.
The original file is restored after each run.


## Fault Layers

Faults are organised in ascending structural depth:

| Layer | RTL File | What is mutated |
|---|---|---|
| ALU result | `ALU.v` | Arithmetic / logical output |
| ALU decode | `ALUControl.v` | funct3/funct7 -> ALU opcode dispatch |
| Hazard | `HazardUnit.v` | Forwarding, load-use stall, misprediction flush |
| Branch | `BranchComparator.v` | Condition evaluation per branch type |
| Immediate | `ImmediateGenerator.v` | Sign-extension and bit-field assembly |
| Control | `MainControl.v` | Opcode -> control signal decode |
| Write-back | `WriteBackMux.v` | Result source selection |
| PC | `PCMux.v` | Misprediction correction override |

## Fault Catalogue

### ALU.v

| # | Fault | Instructions broken |
|---|---|---|
| 1 | XOR computed as OR | `xor`, `xori` |
| 2 | AND computed as OR | `and`, `andi` |
| 3 | ADD computed as SUB | `add`, `addi`, all load/store addresses, `auipc`, `jalr` |
| 4 | SUB computed as ADD | `sub` |
| 5 | SLL computed as SRL | `sll`, `slli` |
| 6 | SRL computed as SLL | `srl`, `srli` |
| 7 | SRA computed as SRL (logical vs arithmetic) | `sra`, `srai` |
| 8 | SLT computed as SLTU (signed vs unsigned) | `slt`, `slti` |
| 9 | SLTU computed as SLT (unsigned vs signed) | `sltu`, `sltiu` |
| 10 | OR computed as AND | `or`, `ori` |

### ALUControl.v

| # | Fault | Instructions broken |
|---|---|---|
| 11 | XORI decoded as AND | `xori` |
| 12 | ANDI decoded as OR | `andi` |
| 13 | ORI decoded as XOR | `ori` |
| 14 | ADDI decoded as SUB | `addi` |
| 15 | SLLI decoded as SRLI | `slli` |
| 16 | SRLI decoded as SRA | `srli` |
| 17 | SRAI decoded as SRL (arithmetic dropped) | `srai` |
| 18 | XOR decoded as OR | `xor` |
| 19 | AND decoded as XOR | `and` |
| 20 | OR decoded as AND | `or` |
| 21 | ADD decoded as OR | `add` |
| 22 | SUB decoded as ADD | `sub` |
| 23 | SLL decoded as SRL | `sll` |
| 24 | SRL decoded as SLL | `srl` |
| 25 | SRA decoded as SRL | `sra` |
| 26 | SLT decoded as SLTU | `slt` |
| 27 | SLTU decoded as SLT | `sltu` |
| 28 | SLTI decoded as SLTIU | `slti` |
| 29 | SLTIU decoded as SLTI | `sltiu` |

### HazardUnit.v

| # | Fault | Mechanism broken |
|---|---|---|
| 30 | EX->EX forward A disabled (ForwardAE=10 never set) | All back-to-back RAW hazards on rs1 |
| 31 | EX->EX forward B disabled (ForwardBE=10 never set) | All back-to-back RAW hazards on rs2 |
| 32 | MEM->EX forward A disabled (ForwardAE=01 never set) | Two-cycle-apart RAW hazards on rs1 |
| 33 | Load-use stall disabled (lwStall=0) | All load-followed-by-use sequences |
| 34 | Misprediction FlushE disabled | Wrong-path instructions enter EX after misprediction |
| 35 | Misprediction FlushD disabled | Wrong-path instruction stays in IF/ID after misprediction |

### BranchComparator.v

| # | Fault | Instruction broken |
|---|---|---|
| 36 | BEQ: Equal -> ~Equal | `beq` |
| 37 | BNE: ~Equal -> Equal | `bne` |
| 38 | BLT: signed Less -> unsigned LessUnsigned | `blt` (sign-sensitive tests) |
| 39 | BGE: signed GreaterEqual -> unsigned | `bge` (sign-sensitive tests) |
| 40 | BLTU: unsigned LessUnsigned -> signed Less | `bltu` |
| 41 | BGEU: unsigned GreaterEqualUnsigned -> signed | `bgeu` |

### ImmediateGenerator.v

| # | Fault | Instructions broken |
|---|---|---|
| 42 | I-type: zero-extend instead of sign-extend | `lb`, `lh`, `lw`, `addi`, `jalr` with negative imm |
| 43 | S-type: low 5 bits zeroed | All stores with non-zero byte offset |
| 44 | B-type: bit[1] cleared (target off by 2) | All conditional branches |
| 45 | U-type: low 12 bits forced to 0xFFF | `lui`, `auipc` |

### MainControl.v

| # | Fault | Broken |
|---|---|---|
| 46 | R-type: RegWrite=0 (writes suppressed) | All R-type results discarded |
| 47 | Load: MemRead=0 (loads return 0) | All loads |
| 48 | Store: MemWrite=0 (stores silently dropped) | All stores |
| 49 | LUI: WriteBackSelect=ALUResult instead of Immediate | `lui` |
| 50 | JAL: RegWrite=0 (link register not written) | `jal` |
| 51 | JALR: Jalr=0 (no jump, treated as I-type ALU) | `jalr` |
| 52 | AUIPC: UsePC=0 (computes 0+imm instead of PC+imm) | `auipc` |

### WriteBackMux.v

| # | Fault | Broken |
|---|---|---|
| 53 | Load: returns ALUResult instead of ReadData | All loads |
| 54 | JAL/JALR: returns ALUResult instead of PC+4 | Link register |

### PCMux.v

| # | Fault | Broken |
|---|---|---|
| 55 | Misprediction correction disabled | All branch mispredictions unrecoverable |

## Results

All 55 faults are **CAUGHT** by the regression suite (0 MISSED, 0 SKIPPED).


| Metric | Value |
|---|---|
| Total faults | 55 |
| Caught | 55 |
| Missed | 0 |
| Skipped | 0 |
| Mutation detection rate | **100%** |

## Key Observations

1. **Paired R+I coverage**: A single ALU.v fault (e.g. XOR->OR) simultaneously breaks
   both the R-type (`xor`) and the matching I-type (`xori`) because both dispatch to
   the same `ALU_XOR` encoding path. This confirmed full R/I pairing coverage for all
   10 base ALU operations without requiring separate per-variant fault entries.

2. **Hazard coverage depth**: Forwarding disable faults (30-32) are caught on every
   compliance test because back-to-back dependent instructions appear ubiquitously.
   The load-use stall disable (33) is caught by any load->use sequence.

3. **Signed vs unsigned boundary**: Dedicated `slt.S`, `sltu.S`, `blt.S`, `bltu.S`,
   `bge.S`, `bgeu.S` tests include sign-sensitive corner cases that rigorously
   distinguish signed from unsigned semantics.

4. **Branch predictor flush**: FlushD/FlushE faults (34-35) cause wrong-path
   speculative instructions to retire and corrupt architectural state, caught
   immediately by the compliance tests after any taken branch.

5. **fence_i exclusion**: `FENCE.I` (`zifencei` extension) is not implemented.
   `fence_i.S` fails to assemble under `-march=rv32i_zicsr` and is classified
   as a toolchain ERROR (not an architectural failure). This is by design.
