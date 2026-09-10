# RV32I Pipelined Processor

A synthesizable 5-Stage pipelined RV32I processor written in Verilog.

This project was developed as part of my computer architecture learning and verification journey. The core executes the RV32I base integer instruction set and is verified using directed tests together with the official RISC-V test suite and a
verification stack built around differential testing against
[Spike](https://github.com/riscv-software-src/riscv-isa-sim), the official RISC-V ISA simulator.

---

## Features

**Core datapath**
- RV32I base ISA, 5-stage pipelined Harvard-architecture datapath
- Byte-addressable data memory, full immediate generator, register file

**Hazards & control flow**
- Hazard detection unit: load-use stalls, EX→EX / MEM→EX forwarding
- Dynamic branch prediction: 2-bit saturating counter + BTB, with
  misprediction recovery (flush + redirect from EX)

**Verification**
- Directed test suite (hand-written, self-checking)
- Official `riscv-tests` RV32UI regression
- Randomized program generation + differential testing against Spike

---

## Verification

Correctness is checked in two tiers: self-checking directed/official tests
that assert their own outcome, and randomized differential testing that
checks every retired instruction against Spike.

### Layer 1: Directed & official tests

`tb/directed_tests.S` is a 30-subtest, hand-written, self-checking program.
Each subtest sets `gp` to its test number, runs a sequence, and branches to
a fail path (writes the test number to `a0`, `ecall`s) if the result is
wrong.

| Tests | Coverage |
|-------|----------|
| 1–5   | ADD, SUB, overflow, LUI/AUIPC |
| 6–12  | AND, OR, XOR, SLL, SRL, SRA, shift-immediate |
| 13    | SLTI, SLTIU |
| 14–16 | SW/LW, SB/LB/LBU, SH/LH/LHU (sign vs. zero extension) |
| 17–20 | BEQ, BNE, BLT/BGE, BLTU/BGEU (taken + not-taken) |
| 21–23 | JAL, JALR, nested call + return |
| 24–25 | Load-use hazard stall, forwarding chain (tested explicitly, not left to chance) |
| 26–28 | ANDI/ORI/XORI, SLT, SLTU |
| 29–30 | Cross-granularity load, branch loop stress |

```bash
python scripts/run.py tb/directed_tests.S --tb tb_cpu_custom
```

`tb_cpu_custom` tracks `gp` (x3) as the sub-test number and prints
`[PASS]`/`[RUN]` for each. It terminates on **either** the custom
`0x00000400` sentinel (directed/random programs) **or** an `ecall` with
`a0==0` (C/official convention), so it works with both flows.

Separately, `tb_cpu_official` runs the official
[riscv-tests](https://github.com/riscv-software-src/riscv-tests) RV32UI
suite. The harness detects the `ecall` instruction at WB stage; `a0=0` →
**PASS**, `a0≠0` → **FAIL** (failing sub-test number in `a0`).

```bash
python scripts/run.py riscv-tests/isa/rv32ui/add.S
python scripts/regress.py   # full suite
```

**Currently passing (40/42):** `add addi and andi auipc beq bge bgeu blt
bltu bne jal jalr lb lbu ld_st lh lhu lui lw or ori sb sh simple sll slli slt slti
sltiu sltu sra srai srl srli st_ld sub sw xor xori`

**Intentionally excluded:** `fence_i` and `ma_data`. This core does not implement
`FENCE.I` or misaligned memory access yet. These are scope decisions, not latent
bugs.The implemented RV32I instruction subset is verified; FENCE/FENCE.I and misaligned memory access are currently outside the implementation scope.

### Layer 2: Random differential testing against Spike

Directed tests catch what you think to test for. Differential testing
catches what you didn't.

`scripts/gen_random.py` generates a random RV32I program (up to 10,000
instructions, seeded for reproducibility) from a weighted instruction mix: 
R-type/I-type arithmetic, shifts, `lui`, load/store round-trips, branches,
and forward-only `jal`s (branch/jump targets are restricted to labels ahead
of the current position, so branch/jump targets are constrained to avoid uncontrolled infinite loops.). The same program is run
through both the RTL simulation and Spike (`--log-commits`).

**What's actually compared:** for every retired instruction, both sides
produce a 4-tuple: `(PC, instruction encoding, destination register,
destination value)`. `compare.py` walks both traces in lockstep and stops
at the first mismatch, so a failure points directly at the exact
instruction where RTL and Spike diverged, rather than just a final,
hard-to-debug register dump. This catches wrong values, wrong destination
registers, missing/extra retirements, and control-flow divergence alike and
not just the accuracy of final answer.

Multiple random seeds are used to exercise different instruction
mixes and dependency patterns each time, including back-to-back dependent
chains (forwarding) and load-immediately-followed-by-use (load-use stall).

Differential testing has been successfully run on randomized programs
exceeding 10,000 instructions across multiple seeds, including programs
designed to stress forwarding, load-use stalls, branches, and jumps.

To generate and simulate a random test:

```bash
python scripts/run_diff.py --seed 53 --count 10000
```
This performs the random program generation, compilation, conversion to the instruction memory format, RTL compilation, and RTL simulation.
The Spike comparison is intentionally kept as a separate manual step. From WSL, navigate to the project directory on the Windows filesystem. Then run:

```bash
python3 diff/scripts/compare.py
```

If the executions diverge, compare.py reports the first mismatching retired instruction, making the failure directly traceable to a specific PC, instruction, register, or value.

---

## Toolchain

- Verilog
- Icarus Verilog
- GTKWave
- RISC-V GNU Toolchain
- Spike (`riscv-isa-sim`)

---

## Repository structure

```
rtl/          Processor RTL
tb/           Testbenches for directed and official tests
scripts/      Build, generation, and regression python scripts
diff/         Differential-testing harness (Testbench, Spike compare, traces, build artifacts)
linker.ld     Linker script for assembly tests
```

---

## Current Status

| Feature | Status |
|----------|--------|
| RV32I Core | ✅ |
| 5-Stage Pipelined Datapath | ✅ |
| Hazard Forwarding & Stalls | ✅ |
| Dynamic Branch Predictor (2-bit + BTB) | ✅ |
| Directed Tests (30 subtests) | ✅ |
| Official riscv-tests RV32UI | ✅ (40/42, `fence_i` and `ma_data` excluded by design) |
| Randomized RV32I Testing | ✅ |
| Long-trace testing (>10,000 instr.) | ✅ |
| Synthesizable RTL | ✅ |

---

## Future Work

- Run C programs compiled with GCC
- Implement the M extension (`MUL`/`DIV`)
- Implement FENCE/FENCE.I
- Add misaligned memory access support
- Implement CSR instructions
- Add performance counters and CPI measurements
- FPGA implementation

---

## References

- Harris & Harris, *Digital Design and Computer Architecture: RISC-V Edition*
- RISC-V Unprivileged ISA Specification
- Official RISC-V ISA Tests (https://github.com/riscv-software-src/riscv-tests)
- Spike, the RISC-V ISA Simulator (https://github.com/riscv-software-src/riscv-isa-sim)
