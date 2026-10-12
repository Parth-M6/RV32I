#!/usr/bin/env python3
"""gen_random.py - write a random RV32I program to diff/build/random_prog.S

  python scripts/gen_random.py --seed N --count M

Uses only x5-x28 and ends with the `addi x31, x0, 85` sentinel (0x05500f93).
"""
import argparse, itertools, random, time
from pathlib import Path

REGS = [f"x{i}" for i in range(5, 29)]
LABEL_GAP = 4      # chunks between labels
NEAR_LABELS = 5    # jump targets: the next N labels
DATA_ADDRS = [0x2000 + i * 4 for i in range(32)]  # valid in RTL and in Spike's -m0x2000:0x1000
_labels = itertools.count(100)                    # unique numeric labels for auipc/jalr pairs


def _reg():
    return random.choice(REGS)


def gen_r_type(_=()):
    op = random.choice(["add", "sub", "and", "or", "xor", "sll", "srl", "sra", "slt", "sltu"])
    return [f"    {op} {_reg()}, {_reg()}, {_reg()}"]


def gen_i_arith(_=()):
    op = random.choice(["addi", "andi", "ori", "xori", "slti", "sltiu"])
    return [f"    {op} {_reg()}, {_reg()}, {random.randint(-2048, 2047)}"]


def gen_i_shift(_=()):
    op = random.choice(["slli", "srli", "srai"])
    return [f"    {op} {_reg()}, {_reg()}, {random.randint(0, 31)}"]


def gen_lui(_=()):
    return [f"    lui {_reg()}, {random.randint(0, 0xFFFFF)}"]


def gen_auipc(_=()):
    return [f"    auipc {_reg()}, {random.randint(0, 0xFFFFF)}"]


def gen_load_store(_=()):
    """Store then matching load. data_reg != base_reg so the data addi can't clobber the lui'd base."""
    base = _reg()
    data = random.choice([r for r in REGS if r != base])
    val = _reg()
    addr = random.choice(DATA_ADDRS)
    width = random.choice(["w", "h", "b", "hu", "bu"])
    load = {"w": "lw", "h": "lh", "b": "lb", "hu": "lhu", "bu": "lbu"}[width]
    store = {"w": "sw", "h": "sh", "b": "sb", "hu": "sh", "bu": "sb"}[width]
    return [
        f"    lui  {base}, {addr >> 12}",
        f"    addi {data}, x0, {random.randint(0, 127)}",
        f"    {store} {data}, {addr & 0xFFF}({base})",
        f"    {load}  {val}, {addr & 0xFFF}({base})",
    ]


# The three below only ever target FORWARD labels (no infinite loops).
def gen_branch(labels):
    if not labels:
        return gen_r_type()
    op = random.choice(["beq", "bne", "blt", "bge", "bltu", "bgeu"])
    return [f"    {op} {_reg()}, {_reg()}, {random.choice(labels)}"]


def gen_jal(labels):
    if not labels:
        return gen_r_type()
    return [f"    jal {_reg()}, {random.choice(labels)}"]


def gen_jalr(labels):
    """auipc+jalr pc-relative pair (what `call` expands to), so the target is a real forward label."""
    if not labels:
        return gen_r_type()
    rd = _reg()
    base = random.choice([r for r in REGS if r != rd])
    target = random.choice(labels)
    n = next(_labels)
    return [f"{n}:  auipc {base}, %pcrel_hi({target})", f"    jalr  {rd}, %pcrel_lo({n}b)({base})"]


GENS = [(4, gen_r_type), (3, gen_i_arith), (1, gen_i_shift), (1, gen_lui), (1, gen_auipc),
        (2, gen_load_store), (1, gen_branch), (1, gen_jal), (1, gen_jalr)]


def build_program(count, seed):
    rng = random.Random(seed)
    random.seed(seed)
    pool = [g for w, g in GENS for _ in range(w)]

    lines = ["# auto-generated random RV32I program", f"# seed={seed}  count={count}",
             ".section .text.init", ".global _start", "_start:",
             "    # initialise safe register pool to small known values"]
    lines += [f"    addi {r}, x0, {i + 1}" for i, r in enumerate(REGS)] + [""]

    # A label every LABEL_GAP chunks; jumps only reach the next NEAR_LABELS labels,
    # so a jump skips a few chunks and most of the program actually executes.
    sched = {(i + 1) * LABEL_GAP: f"L{i}" for i in range(count // LABEL_GAP)}

    for slot in range(1, count + 1):
        if slot in sched:
            lines.append(f"{sched[slot]}:")
        future = [name for s, name in sorted(sched.items()) if s > slot][:NEAR_LABELS]
        lines += pool[rng.randint(1, len(pool)) - 1](future)

    # addi x31,x0,85 = 0x05500f93 (testbench stop marker); the trailing loop is never reached.
    lines += ["", "#--- end of random instructions ---", "", "    addi x31, x0, 85", "1:", "    jal x0, 1b"]
    return "\n".join(lines) + "\n"


def main():
    ap = argparse.ArgumentParser(description="Generate a random RV32I assembly program.")
    ap.add_argument("--seed", type=int, default=None, help="RNG seed (default: time-based)")
    ap.add_argument("--count", type=int, default=500, help="instructions to generate (default: 500)")
    a = ap.parse_args()

    seed = a.seed if a.seed is not None else int(time.time() * 1000) % (2**31)
    out = Path(__file__).resolve().parent.parent / "diff" / "build" / "random_prog.S"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build_program(a.count, seed))
    print(f"seed={seed} count={a.count} -> {out}")


if __name__ == "__main__":
    main()