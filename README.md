# RV32I Single-Cycle Processor

A synthesizable 5-Stage RV32I processor written in Verilog.

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

---

## Verification

### Directed tests

Custom assembly programs covering:

- Arithmetic
- Logical operations
- Branches
- Memory operations
- Jumps

### Official ISA tests

Verified against the official RV32I architectural test suite.

Passing:

- Arithmetic instructions
- Immediate instructions
- Branch instructions
- Jump instructions
- Load instructions
- Store instructions

Currently excluded:

- `fence_i`
- `ma_data`
- `ld_st`

These require functionality that is intentionally outside the scope of this implementation.

---

## Toolchain

- Verilog
- Icarus Verilog
- GTKWave
- RISC-V GNU Toolchain

---

## Repository structure

```
rtl/        Processor RTL
tb_custom/  Directed Testbench designed by me
tb/         Testbench for running official RV32UI tests
scripts/    Build and regression python scripts
```

---

```bash
python scripts/run.py riscv-tests/isa/rv32ui/<test_name>.S
```


---

## Current Status

| Feature | Status |
|----------|--------|
| RV32I Core | ✔ |
| 5 Stage Pipelined Datapath | ✔ |
| Directed Tests | ✔ |
| Official ISA Tests | ✔ (except excluded tests) |
| Synthesizable RTL | ✔ |

---

## Future Work

- Branch prediction
- Performance counters
- FPGA implementation

---

## References

- Harris & Harris — *Digital Design and Computer Architecture: RISC-V Edition*
- RISC-V Unprivileged ISA Specification
- Official RISC-V ISA Tests
