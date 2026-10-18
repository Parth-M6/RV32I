# Differential Testing

Instruction-retirement differential testing compares the RTL simulation of the
RV32I pipelined processor against **Spike** (the official RISC-V ISA reference
simulator) on the same random assembly program.  For every instruction that
retires in the pipeline a 4-tuple is matched in lockstep:

```bash
(PC, instruction encoding, destination register rd, write-back value)
```

This methodology catches any architectural divergence between the RTL and the
specification, regardless of the structural cause (wrong ALU result, missing
forward, bad branch target, incorrect load sign-extension, etc.).

---

## Toolchain

| Tool | Role |
|---|---|
| `scripts/gen_random.py` | Generates a deterministic random RV32I assembly program |
| `scripts/run_diff.py` | Compiles + simulates the program in RTL; writes `diff/rtl/rtl_trace.log` |
| `diff/scripts/compare.py` | Runs Spike with `--log-commits`, parses both traces, compares lockstep |
| Spike (`riscv-isa-sim`) | Golden reference simulator; run inside WSL Ubuntu |

---

## Pipeline

```
gen_random.py  ──►  diff/build/random_prog.S
                          │
         ┌────────────────┴───────────────────┐
         │  Windows/Linux (run_diff.py)       │  WSL/Linux (compare.py)
         │  riscv-none-elf-gcc + objcopy      │  Spike --log-commits
         │  iverilog + vvp                    │  parse spike output
         │  writes rtl_trace.log              │  compare lockstep
         └────────────────────────────────────┘
                          │
                    PASS / FAIL
```

---

## Running the Tests

### Step A — Generate program and run RTL simulation (Windows/Linux)

```bash
# Working directory: project root
python scripts/run_diff.py --seed <seed> --count <count>  # <seed> and <count> should be integers
```

`run_diff.py` performs all five sub-steps automatically:
1. `gen_random.py --seed <seed> --count <count>` → `diff/build/random_prog.S`
2. `riscv-none-elf-gcc` → `diff/tests/random<count>.elf`
3. `riscv-none-elf-objcopy` → `diff/tests/random<count>.bin`
4. `bin_to_hex.py` → `diff/rtl/instructions.hex`
5. `iverilog + vvp` → simulation writes `diff/rtl/rtl_trace.log`

### Step B — Compare against Spike (WSL/Linux)

```bash
# Compare RTL trace against Spike (Windows via WSL / Linux native)
python diff/scripts/compare.py
```

`compare.py` will:
1. Launch Spike with `--log-commits` and the same ELF (`diff/tests/random.elf`)
2. Stop Spike at the sentinel instruction `addi x31, x0, 85` (0x05500f93)
3. Parse the Spike retirement log and the RTL trace
4. Compare every (PC, INSN, RD, VALUE) tuple; print PASS or the first mismatch

---

## Measured Results

All runs below confirmed **DIFFERENTIAL TEST PASSED** with RTL and Spike
retirement counts matching exactly. Every run was reproduced in sequence:
Step A via `run_diff.py` , Step B via `compare.py` in WSL/Linux with Spike at `/home/parth/spike-install/bin/spike`.

| Seed | Count | RTL Cycles | Retired Instructions | Result |
|---|---|---|---|---|
| 42   |  500 | 435 | 369 | **PASS** |
| 1337 |  500 | 369 | 300 | **PASS** |
| 2024 |  500 | 332 | 258 | **PASS** |
| 9999 |  500 | 327 | 249 | **PASS** |
| 42   | 1000 | 789 | 651 | **PASS** |
| 1337 | 1000 | 726 | 601 | **PASS** |
| 2024 | 1000 | 682 | 552 | **PASS** |
| 9999 | 1000 | 600 | 463 | **PASS** |

> Retired instruction counts are lower than `--count` because: (a) branch/jump
> instructions skip forward, reducing the executed count; (b) the retirement
> trace only records instructions that reach WB with `RegWrite=1` or that have
> no write-back (stores, unconditional branches logged as rd=x0); (c) the
> sentinel instruction terminates the trace early.

---

## Scope and Boundaries

**What differential testing validates:**
- Arithmetic and logical correctness for every retired instruction
- Memory load/store values (byte, halfword, word; signed and unsigned)
- Branch outcomes and target PC values
- JAL/JALR return addresses
- Data-forwarding correctness (EX→EX, MEM→EX)
- Load-use stall timing (incorrect stalling → wrong value visible to Spike)
- Branch prediction misprediction recovery (wrong-path retirement → mismatch)
- AUIPC PC-relative addressing

**What differential testing does NOT validate:**
- Cycle-accurate microarchitecture (only instruction-retirement equivalence)
- CSR state, privilege modes, or exception handling
- Spike's boot-ROM startup sequence (skipped by PC filtering `>= 0x80000000`)
- `FENCE.I` / `FENCE` (not in the random program generator)
- Precise trap / interrupt timing

---

## Spike Memory Map

Spike is launched with a custom memory layout to match the RTL:

```
-m0x2000:0x1000,0x80000000:0x80000000
```

- `0x2000:0x1000` — 4 KB data region matching the RTL `DATA_ADDRS` used by `gen_random.py`
- `0x80000000:0x80000000` — main program region where the ELF loads
