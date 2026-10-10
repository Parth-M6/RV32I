#!/usr/bin/env python3
"""run_diff.py - generate a random RV32I program and run the RTL side of the differential test.
Prints tool output only on failure.

  python scripts/run_diff.py --seed N --count M
"""
import argparse, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "diff"
ELF, BIN = D / "tests" / "random50.elf", D / "tests" / "random50.bin"
HEX, VVP, TB = D / "rtl" / "instructions.hex", D / "rtl" / "diff.vvp", D / "rtl" / "tb_cpu_diff.v"


def run(cmd, quiet=True):
    p = subprocess.run([str(x) for x in cmd], cwd=ROOT, capture_output=quiet, text=True)
    if p.returncode and quiet:
        sys.stderr.write(f"$ {' '.join(map(str, cmd))}\n{p.stdout}{p.stderr}")
    p.check_returncode()


def main():
    ap = argparse.ArgumentParser(description="Generate and run a random RV32I differential test.")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--count", type=int, default=500)
    a = ap.parse_args()
    if a.count <= 0:
        ap.error("--count must be greater than 0")

    tools = ["riscv-none-elf-gcc", "riscv-none-elf-objcopy", "iverilog", "vvp"]
    if missing := [t for t in tools if not shutil.which(t)]:
        sys.exit("ERROR: not found in PATH: " + ", ".join(missing))

    gen = [sys.executable, ROOT / "scripts" / "gen_random.py", "--count", a.count]
    run(gen + (["--seed", a.seed] if a.seed is not None else []))
    run(["riscv-none-elf-gcc", "-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles",
         "-T", D / "tests" / "link.ld", "-o", ELF, D / "build" / "random_prog.S"])
    run(["riscv-none-elf-objcopy", "-O", "binary", "-j", ".text", ELF, BIN])
    run([sys.executable, D / "scripts" / "bin_to_hex.py", BIN, HEX])
    run(["iverilog", "-g2012", "-o", VVP, *sorted((ROOT / "rtl").glob("*.v")), TB])
    run(["vvp", VVP], quiet=False)  # sim output is the result: always shown
    return 0


if __name__ == "__main__":
    sys.exit(main())