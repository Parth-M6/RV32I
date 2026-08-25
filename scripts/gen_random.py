#!/usr/bin/env python3
"""
gen_random.py  —  Generate, assemble, and simulate a random 500-instruction
                   RV32I program on every run.

Usage:
    python scripts/gen_random.py                  # fully random seed
    python scripts/gen_random.py --seed 42        # reproducible
    python scripts/gen_random.py --count 200      # custom instruction count
    python scripts/gen_random.py --no-sim         # generate only, no simulation
    python scripts/gen_random.py --tb tb_cpu_custom

The generated program:
  • Uses only "safe" registers (x5–x28); avoids x0,x1,x2,x3 which the
    testbench monitors and x29-x31 (reserved).
  • Emits a final XOR checksum of all live registers into x5, then
    writes x5 to a0 (must be 0 for PASS via ecall convention).
    Instead we end with the 0x00000400 sentinel so tb_cpu_custom sees PASS.


Exit code: 0 = PASS, 1 = FAIL/ERROR.
"""
from __future__ import annotations

import argparse
import itertools
import random
import sys
import time
from pathlib import Path

# Make sure sibling scripts are importable when run from the project root
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

import _common as c
from build import build_one
from run import compile_rtl, run_sim

# ---------------------------------------------------------------------------
# Register pool (avoid x0=zero, x1=ra, x2=sp, x3=gp, x4=tp)
# ---------------------------------------------------------------------------
REGS = [f"x{i}" for i in range(5, 29)]   # x5..x28

# Data memory addresses (word-aligned).
# Must be in a region that is:
#   - Valid in the RTL flat address space (DataMemory has 4096 words = 0x0000-0x3FFF)
#   - Mappable in Spike without conflicting with boot ROM [0x0, 0x2000)
# 0x2000-0x207C satisfies both: RTL word index 2048-2079 (within 0-4095);
# Spike gets -m0x2000:0x1000,0x80000000:... which avoids the [0,0x2000) boot ROM.
DATA_ADDRS = [0x2000 + i * 4 for i in range(32)]   # 0x2000–0x207C (128 bytes)

# Monotonically increasing counter used to mint unique numeric local labels
# for the auipc/jalr pcrel pair (see gen_jalr). Using a counter instead of
# reusing "1" (like the footer's infinite loop does) keeps every jalr's
# anchor label unambiguous and easy to spot in the disassembly, even though
# GNU as would technically tolerate reuse of numeric local labels.
_pcrel_label_counter = itertools.count(100)

# ---------------------------------------------------------------------------
# Instruction generators — each returns a list of assembly text lines
# ---------------------------------------------------------------------------

def _reg() -> str:
    return random.choice(REGS)


def _imm12() -> int:
    """Random signed 12-bit immediate."""
    return random.randint(-2048, 2047)


def _uimm5() -> int:
    """Random shift amount 0–31."""
    return random.randint(0, 31)


def gen_r_type() -> list[str]:
    op = random.choice(["add", "sub", "and", "or", "xor",
                        "sll", "srl", "sra", "slt", "sltu"])
    rd, rs1, rs2 = _reg(), _reg(), _reg()
    return [f"    {op} {rd}, {rs1}, {rs2}"]


def gen_i_arith() -> list[str]:
    op = random.choice(["addi", "andi", "ori", "xori", "slti", "sltiu"])
    rd, rs1 = _reg(), _reg()
    imm = _imm12()
    return [f"    {op} {rd}, {rs1}, {imm}"]


def gen_i_shift() -> list[str]:
    op = random.choice(["slli", "srli", "srai"])
    rd, rs1 = _reg(), _reg()
    shamt = _uimm5()
    return [f"    {op} {rd}, {rs1}, {shamt}"]


def gen_lui() -> list[str]:
    rd = _reg()
    uimm = random.randint(0, 0xFFFFF)
    return [f"    lui {rd}, {uimm}"]


def gen_auipc() -> list[str]:
    """AUIPC is a pure data instruction (rd = PC + imm<<12); it never
    touches control flow, so it's exactly as safe as LUI — no special
    handling needed."""
    rd = _reg()
    uimm = random.randint(0, 0xFFFFF)
    return [f"    auipc {rd}, {uimm}"]


def gen_load_store() -> list[str]:
    """Generate a store followed by the matching load (safe: no stale data risk).

    DATA_ADDRS are in 0x2000-0x207C.  These need two instructions to load:
      lui base, 0x2        # base = 0x00002000
      addi data, x0, val   # data value 0-127
      store data, offset(base)
      load  rd,   offset(base)

    IMPORTANT: base_reg must differ from data_reg.  If they were the same,
    the addi (which loads the small data value) would overwrite the base
    register set by lui, causing a misaligned or out-of-range access.

    Widths include the unsigned variants (lbu/lhu). These only change the
    sign-extension behavior of the load, not the address computation, so
    they're exactly as safe as their signed counterparts (lb/lh) — there is
    no unsigned *store*, so the store op is shared with the signed width.
    """
    base_reg = _reg()
    # data_reg MUST be different from base_reg
    other_regs = [r for r in REGS if r != base_reg]
    data_reg = random.choice(other_regs)
    val_reg  = _reg()   # can overlap base_reg (written last)
    addr = random.choice(DATA_ADDRS)   # e.g. 0x2000, 0x2004, ...
    upper = addr >> 12               # bits [31:12]; e.g. 2 for 0x2000
    lower = addr & 0xFFF             # bits [11:0];  e.g. 0x000..0x07C
    # Lower bits are all < 0x800 for our range, so no sign-extension fixup needed.
    width    = random.choice(["w", "h", "b", "hu", "bu"])
    load_op  = {"w": "lw",  "h": "lh",  "b": "lb",  "hu": "lhu", "bu": "lbu"}[width]
    store_op = {"w": "sw",  "h": "sh",  "b": "sb",  "hu": "sh",  "bu": "sb"}[width]
    lines = [
        f"    lui  {base_reg}, {upper}",                          # base_reg = addr & ~0xFFF
        f"    addi {data_reg}, x0, {random.randint(0, 127)}",
        f"    {store_op} {data_reg}, {lower}({base_reg})",
        f"    {load_op}  {val_reg}, {lower}({base_reg})",
    ]
    return lines


def gen_branch(label_pool: list[str]) -> list[str]:
    """Generate a conditional branch to a forward label.

    Caller MUST pass only labels that appear ahead of the current
    position (see `future_labels` in build_program). Branching to a
    label that has already been emitted creates a backward edge, which
    can turn into an infinite loop depending on register contents.
    """
    if not label_pool:
        return gen_r_type()
    op = random.choice(["beq", "bne", "blt", "bge", "bltu", "bgeu"])
    rs1, rs2 = _reg(), _reg()
    target = random.choice(label_pool)
    return [
        f"    {op} {rs1}, {rs2}, {target}"
    ]


def gen_jal(label_pool: list[str]) -> list[str]:
    """JAL to a forward label. Caller MUST pass only labels ahead of the
    current position (see `future_labels` in build_program) — otherwise
    this creates a backward (looping) jump."""
    if not label_pool:
        return gen_r_type()
    rd = _reg()
    target = random.choice(label_pool)
    return [
        f"    jal {rd}, {target}"
    ]


def gen_jalr(label_pool: list[str]) -> list[str]:
    """JALR to a forward label.

    Unlike JAL, plain `jalr rd, imm(rs1)` computes its target from
    whatever garbage value rs1 happens to hold — since REGS get clobbered
    by arbitrary earlier r_type/i_arith/load instructions, using a random
    rs1 as the jump base would risk landing outside the program's
    instruction memory or creating an unintended backward/infinite loop.

    Instead we generate the same auipc+jalr pc-relative pair the RISC-V
    `call` pseudo-instruction expands to:

        100: auipc base, %pcrel_hi(target)
             jalr  rd,   %pcrel_lo(100b)(base)

    This computes `base` from the assembler-known distance to `target`
    (one of the same forward-only labels used by branch/jal), so the
    jump always lands exactly on a real, forward instruction boundary —
    never on garbage. `base` and `rd` are kept distinct only to avoid any
    ambiguity when reading the disassembly (jalr's target address is
    computed from rs1 before rd is written either way, so rd == base
    would technically also be safe).
    """
    if not label_pool:
        return gen_r_type()
    rd = _reg()
    base_regs = [r for r in REGS if r != rd]
    base = random.choice(base_regs)
    target = random.choice(label_pool)
    n = next(_pcrel_label_counter)
    return [
        f"{n}:  auipc {base}, %pcrel_hi({target})",
        f"    jalr  {rd}, %pcrel_lo({n}b)({base})",
    ]


# ---------------------------------------------------------------------------
# Program builder
# ---------------------------------------------------------------------------

def build_program(count: int, seed: int) -> str:
    """Return the full assembly text of a random program."""
    rng = random.Random(seed)
    random.seed(seed)   # also set module-level random

    lines: list[str] = []

    # ---- Header ----
    lines += [
        "# auto-generated random RV32I program",
        f"# seed={seed}  count={count}",
        ".section .text.init",
        ".global _start",
        "_start:",
        "    # initialise safe register pool to small known values",
    ]
    for i, r in enumerate(REGS):
        lines.append(f"    addi {r}, x0, {i + 1}")
    lines.append("")

    # We'll scatter forward labels through the program and only branch/jump
    # to labels we've ALREADY seen (i.e., labels that are behind us).
    # To keep it simple: pre-generate N_LABELS evenly spaced labels and
    # use only those that have already been emitted.

    past_labels: list[str] = []   # labels emitted so far (available targets)

    # ---- Instruction generation ----
    weights = [
        (4, "r_type"),
        (3, "i_arith"),
        (1, "i_shift"),
        (1, "lui"),
        (1, "auipc"),
        (2, "load_store"),
        (1, "branch"),
        (1, "jal"),
        (1, "jalr"),
    ]
    total_weight = sum(w for w, _ in weights)

    # Labels are only needed when branch/jal/jalr are enabled (weight > 0).
    weight_by_kind = dict((k, w) for w, k in weights)
    branch_enabled = (weight_by_kind["branch"] > 0
                       or weight_by_kind["jal"] > 0
                       or weight_by_kind["jalr"] > 0)
    n_labels = min(40, count // 10) if branch_enabled else 0
    label_spacing = max(1, count // (n_labels + 1)) if n_labels else count + 1
    label_names: list[str] = [f"L{i}" for i in range(n_labels)]
    label_schedule: dict[int, str] = {
        (i + 1) * label_spacing: label_names[i] for i in range(n_labels)
    }

    instr_count = 0
    slot = 0
    while instr_count < count:
        slot += 1

        # Emit a label if scheduled at this slot
        if slot in label_schedule:
            lbl = label_schedule[slot]
            lines.append(f"{lbl}:")
            past_labels.append(lbl)

        # Labels scheduled at a LATER slot than the one we're about to
        # emit are ahead of us in program order -> safe (forward-only)
        # branch/jump targets. Using `past_labels` here instead would
        # create backward edges and risk infinite loops.
        future_labels = [
            name for s, name in label_schedule.items() if s > slot
        ]

        # Pick instruction type by weight
        r = rng.randint(1, total_weight)
        cumulative = 0
        kind = None
        for w, k in weights:
            cumulative += w
            if r <= cumulative:
                kind = k
                break

        if kind == "r_type":
            chosen_lines = gen_r_type()
        elif kind == "i_arith":
            chosen_lines = gen_i_arith()
        elif kind == "i_shift":
            chosen_lines = gen_i_shift()
        elif kind == "lui":
            chosen_lines = gen_lui()
        elif kind == "auipc":
            chosen_lines = gen_auipc()
        elif kind == "load_store":
            chosen_lines = gen_load_store()
        elif kind == "branch":
            chosen_lines = gen_branch(future_labels)
        elif kind == "jal":
            chosen_lines = gen_jal(future_labels)
        elif kind == "jalr":
            chosen_lines = gen_jalr(future_labels)
        else:
            chosen_lines = gen_r_type()  # fallback, should not happen

        lines.extend(chosen_lines)
        instr_count += 1

    # ---- Footer: PASS sentinel + infinite loop ----
    # addi x31, x0, 85  -> encodes as 0x05500f93  (testbench stop marker)
    # The infinite loop uses JAL x0, 0 (0x0000006f) which is safe:
    # it does not write any register and only cycles PC in place.
    # Even with jal weight=0 in the random body, the footer JAL is fine
    # because the testbench halts on the SENTINEL before reaching the loop.
    lines += [
        "",
        "#--- end of random instructions ---",
        "",
        "    addi x31, x0, 85",   # sentinel: 0x05500f93
        "1:",
        "    jal x0, 1b"           # infinite loop — testbench stops before this
    ]

    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Generate, assemble, and simulate a random RV32I program."
    )
    ap.add_argument("--seed", type=int, default=None,
                    help="RNG seed (default: time-based, printed to stdout)")
    ap.add_argument("--count", type=int, default=500,
                    help="Number of random instructions to generate (default: 500)")
    ap.add_argument("--root", help="override auto-detected project root")
    ap.add_argument("--no-sim", action="store_true",
                    help="Generate program only; skip assembly+simulation")
    ap.add_argument("--tb", default="tb_cpu_custom",
                    help="Testbench to use for simulation (default: tb_cpu_custom)")
    ap.add_argument("--timeout", type=float, default=None)
    args = ap.parse_args(argv)

    root = c.find_project_root(args.root)
    c.ensure_dirs(root)

    seed = args.seed if args.seed is not None else int(time.time() * 1000) % (2**31)
    print(c.info(f"Random seed: {seed}  instructions: {args.count}"))

    # Generate the program text
    prog_text = build_program(args.count, seed)

    # Write to diff/build/ (used by the diff testing pipeline)
    out_s = root / "diff" / "build" / "random_prog.S"
    out_s.parent.mkdir(parents=True, exist_ok=True)
    out_s.write_text(prog_text)
    print(c.info(f"Wrote {out_s.relative_to(root)}  ({args.count} instructions)"))

    if args.no_sim:
        print(c.ok("DONE (no-sim mode)"))
        return 0

    # Assemble + link
    print(c.info("Assembling..."))
    try:
        result = build_one(root, out_s, fmt="words", dis=True, quiet=False,
                           out_name="random_prog")
    except c.CommandError as e:
        print(c.bad(f"BUILD FAILED:\n{e}"))
        return 1

    # Compile RTL (always recompile so tb selection is respected)
    print(c.info(f"Compiling RTL with testbench: {args.tb}"))
    try:
        timeout = args.timeout if args.timeout else c.CONFIG["sim_wall_timeout_s"]
        vvp_path = compile_rtl(root, vvp_name="random_prog", tb_name=args.tb)
    except c.CommandError as e:
        print(c.bad(f"RTL COMPILE FAILED:\n{e}"))
        return 1

    # Simulate
    print(c.info("Simulating..."))
    log_path = root / "logs" / "random_prog.log"
    try:
        log_text = run_sim(root, vvp_path, log_path, timeout=timeout)
    except c.CommandError as e:
        log_text = e.output
    log_path.write_text(log_text)

    status, detail = c.parse_sim_result(log_text)
    print()
    if status == "PASS":
        print(c.ok(f"PASS  random_prog  (seed={seed})"))
    else:
        suffix = f" ({detail})" if detail else ""
        print(c.bad(f"{status}  random_prog{suffix}  (seed={seed})"))
        print(f"  Log: {log_path.relative_to(root)}")
        print(f"  Dis: {result.dis.relative_to(root) if result.dis else 'n/a'}")

    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())