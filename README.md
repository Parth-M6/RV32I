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
- Directed architectural test suite (hand-written, self-checking)
- Official `riscv-tests` RV32UI regression
- Randomized program generation + differential testing against Spike

---

## Verification

Correctness is checked in two tiers: self-checking (directed & official) tests
that assert their own outcome, and randomized differential testing that
checks every retired instruction against Spike.

### Layer 1: Directed Tests

The first layer of testing uses a custom assembly program, `tests/directed_tests.S`, to verify the correctness of the RV32I CPU. It contains **50 directed subtests**, covering individual instructions as well as situations where multiple instructions interact with each other in the pipeline.

These tests target specific cases that are easy to get wrong when implementing a pipelined processor. Each subtest checks its result against an expected value and reports a failure code if the check fails.

#### What is covered?

| Test range | Coverage |
|---|---|
| 1–5 | Basic arithmetic, subtraction, two's complement, 32-bit overflow behaviour, and immediate arithmetic |
| 6–8 | Bitwise operations: AND, OR, and XOR, including their immediate variants |
| 9–11 | Logical and arithmetic shifts, including register-based and immediate shift instructions |
| 12–13 | Signed and unsigned comparisons using SLT, SLTI, SLTU, and SLTIU |
| 14–16 | LUI, AUIPC, PC-relative addressing, JAL, and AUIPC/JALR sequences |
| 17–23 | Byte, halfword, and word loads/stores; sign extension; zero extension; little-endian memory layout; and negative offsets |
| 24–27 | Conditional branches, covering both taken and not-taken paths and signed versus unsigned comparisons |
| 28–30 | JAL/JALR jump targets, link addresses, non-zero offsets, and JALR's clearing of the target address's least significant bit |
| 31–33 | Data forwarding between dependent instructions |
| 34–39 | Load-use hazards, branch dependencies, load-to-store forwarding, dependent store addresses, store-data forwarding, and store/load consistency |
| 40–41 | Pipeline flushing after branches and jumps, including preventing a flushed store from modifying memory |
| 42 | Register `x0` remaining zero, even when instructions attempt to write to it or forwarding is involved |
| 43–45 | Branch predictor behaviour across repeated outcomes, alternating branch outcomes, and consecutive branch/jump sequences |
| 46–47 | Forwarding into branch comparisons and handling a JALR base-register dependency |
| 48–50 | Shift amounts using the lower five bits, byte-lane isolation, and back-to-back loads followed by dependent ALU operations |

The tests are intended to exercise both the RV32I instruction implementation and the additional control logic required to keep a five-stage pipeline working correctly.

#### How the test program reports results

The assembly program uses the `gp` register to identify the current subtest. When a check fails, the program places the corresponding test number in `a0` and executes an `ecall`. This gives the testbench a failure code that can be used to identify the failing subtest.

If all checks complete successfully, the program sets `a0` to zero, emits a custom `0x00000400` instruction as a success marker, and then executes an `ecall` as a fallback termination mechanism.

The testbench monitors instructions retiring from the write-back stage to detect these termination conditions. It reports a successful run when it observes the success marker or a successful terminating `ecall`. A non-zero failure code indicates that a test failed, while exceeding the cycle limit results in a timeout.

The testbench also prints test progress as `gp` changes, generates a VCD waveform file for debugging, and dumps the final register state and relevant pipeline signals. This makes it easier to investigate failures involving forwarding, stalls, branch decisions, or incorrect flush behaviour.

#### Building and running the tests

The directed test program is assembled and linked using the RISC-V GCC toolchain. The resulting ELF file is converted into a binary, which is then converted into the instruction-memory hex format expected by the testbench. Finally, Icarus Verilog compiles the RTL and testbench, and the resulting simulation is run with `vvp`.

Run the following commands from the project root:

```powershell
riscv-none-elf-gcc -march=rv32i -mabi=ilp32 -nostdlib -nostartfiles -T linker.ld -o tests\artifacts\directed_tests.elf tests\directed_tests.S

riscv-none-elf-objcopy -O binary -j .text tests\artifacts\directed_tests.elf tests\artifacts\directed_tests.bin

python diff\scripts\bin_to_hex.py tests\artifacts\directed_tests.bin tests\artifacts\instructions.hex

iverilog -g2012 -o tests\artifacts\directed_tests.vvp rtl\*.v tb\tb_cpu_directed.v

vvp tests\artifacts\directed_tests.vvp
```

The simulation prints the test progress and final result to the console. It also generates `tb_cpu_directed.vcd`, which can be opened in a waveform viewer to inspect the pipeline when debugging a failure.

**Note:** The per-test `[PASS]` messages are based on the testbench observing the `gp` register advance to the next test. The final success marker or successful terminating `ecall` is the stronger indication that the complete test program finished successfully.

**CAUTION:** `tests/artifacts` directory is created to store the artifacts created by the directed tests. It contains the ELF file, the binary file, the hex file, and the VCD file. All files in the directory must be deleted before running/rerunning the tests or after modifications in tests otherwise it will reuse the previously generated .elf file giving unintended results.

Separately, `tb_cpu_official` runs the official
[riscv-tests](https://github.com/riscv-software-src/riscv-tests) RV32UI
suite. The harness detects the `ecall` instruction at WB stage; `a0=0` →
**PASS**, `a0≠0` → **FAIL** (failing sub-test number in `a0`).

```bash
python scripts/rv.py run riscv-tests/isa/rv32ui/<test_name>.S
python scripts/rv.py regress   # full suite
```

**Currently passing (41/42):** `add addi and andi auipc beq bge bgeu blt
bltu bne jal jalr lb lbu ld_st lh lhu lui lw ma_data or ori sb sh simple sll slli slt slti
sltiu sltu sra srai srl srli st_ld sub sw xor xori`

**Intentionally excluded:** `fence_i`. This core does not implement
`FENCE.I`. The implemented RV32I instruction subset is fully verified; FENCE/FENCE.I is currently outside the implementation scope.

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

Regression runs multiple random seeds to exercise different instruction
mixes and dependency patterns each time, including back-to-back dependent
chains (forwarding) and load-immediately-followed-by-use (load-use stall).

Differential testing has been successfully run on randomized programs
exceeding 10,000 instructions across multiple seeds, including programs
designed to stress forwarding, load-use stalls, branches, and jumps.

```bash
Windows/Linux:
python scripts/gen_random.py --seed <M> --count <N>  # Generates a random RV32I program
python scripts/run_diff.py --seed <M> --count <N> # auto executes gen_random.py script with same parameters

WSL/Linux:
python compare.py
```
**NOTE:** Update the Spike installation path in `_cands` (Line 7 & 8 in `diff/scripts/compare.py`) to match the directory where Spike is installed on your system.
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
diff/         Differential-testing harness (Spike compare, traces, build artifacts)
rtl/          Processor RTL
scripts/      Build, generation, and regression python scripts (for both official tests and spike)
tb/           All testbenches
tests/        Directed tests and artifacts
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
| Directed Tests (50 subtests) | ✅ |
| Official riscv-tests RV32UI | ✅ (41/42, `fence_i` excluded by design) |
| Randomized RV32I Testing | ✅ |
| Long-trace testing (>10,000 instr.) | ✅ |
| Synthesizable RTL | ✅ |

---

## Future Work

- Run C programs compiled with GCC
- Implement the M extension (`MUL`/`DIV`)
- Implement FENCE/FENCE.I
- Implement CSR instructions
- Add performance counters and CPI measurements
- FPGA implementation

---

## References

- Harris & Harris, *Digital Design and Computer Architecture: RISC-V Edition*
- RISC-V Unprivileged ISA Specification
- Official RISC-V ISA Tests (https://github.com/riscv-software-src/riscv-tests)
- Spike, the RISC-V ISA Simulator (https://github.com/riscv-software-src/riscv-isa-sim)
