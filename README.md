# RV32I Pipelined Processor

A synthesizable 5-Stage pipelined RV32I processor written in Verilog.

This project was developed as part of my computer architecture learning and verification journey. The core executes the RV32I base integer instruction set and is verified using directed tests together with the official RISC-V test suite.

---

## Features

- RV32I base ISA
- 5 staged pipelined datapath
- Harvard architecture
- Byte-addressable data memory
- Immediate generator
- Branch and jump support
- Load/store unit
- Register file
- ALU with RV32I operations
- Modular RTL
- Hazard Unit
- Branch Prediction

---

## Verification

### Directed tests (`tb_cpu_custom`)

A hand-written 30-subtest program in `tb/directed_tests.S` covering:

| Tests | Coverage |
|-------|----------|
| 1–5   | ADD, SUB, overflow, LUI/AUIPC |
| 6–12  | AND, OR, XOR, SLL, SRL, SRA, shift-immediate |
| 13    | SLTI, SLTIU |
| 14–16 | SW/LW, SB/LB/LBU, SH/LH/LHU |
| 17–20 | BEQ, BNE, BLT/BGE, BLTU/BGEU (taken + not-taken) |
| 21–23 | JAL, JALR, nested call + return |
| 24–25 | Load-use hazard stall, forwarding chain |
| 26–28 | ANDI/ORI/XORI, SLT, SLTU |
| 29–30 | Cross-granularity load, branch loop stress |

```bash
python scripts/run.py tb/directed_tests.S --tb tb_cpu_custom
```

`tb_cpu_custom` tracks `gp` (x3) as the sub-test number and prints `[PASS]`/`[RUN]` for each.

It terminates on **either** the custom `0x00000400` sentinel (directed/random programs)
**or** an `ecall` with `a0==0` (C/official convention), so it works with both flows.


### Official ISA tests (`tb_cpu_official`)

Run a single official riscv-tests test:

```bash
python scripts/run.py riscv-tests/isa/rv32ui/add.S
python scripts/run.py riscv-tests/isa/rv32ui/lb.S
```

Run the full official regression:

```bash
python scripts/regress.py official
```

The harness detects the `ecall` instruction at WB stage; `a0=0` → **PASS**, `a0≠0` → **FAIL** (failing sub-test number in `a0`).

Currently passing: `add addi and andi auipc beq bge bgeu blt bltu bne jal jalr lb lbu ld_st lh lhu lui lw or ori sb sh sll slli slt slti sltiu sltu sra srai srl srli sub sw xor xori`

Excluded (intentionally unsupported): `fence_i` · `ma_data`

---

## Toolchain

- Verilog
- Icarus Verilog
- GTKWave
- RISC-V GNU Toolchain

---

## Repository structure

```
rtl/          Processor RTL
tb/           All testbenches
scripts/      Build and regression python scripts
linker.ld     Linker script for assembly tests
directed.hex  Instruction memory for directed tests
```

---

```bash
python scripts/run.py riscv-tests/isa/rv32ui/<test_name>.S
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
| Official riscv-tests RV32UI | ✅ (37/39 - fence_i/ma_data excluded) |
| Synthesizable RTL | ✅ |

---

## Future Work

- Generate/Run programs with multiple instructions
- Run C programs compiled with GCC
- Spike differential testing
- Implement CSR instructions
- Add performance counters
- FPGA implementation

---

## References

- Harris & Harris — *Digital Design and Computer Architecture: RISC-V Edition*
- RISC-V Unprivileged ISA Specification
- Official RISC-V ISA Tests (https://github.com/riscv-software-src/riscv-tests)
