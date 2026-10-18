#!/usr/bin/env python3
"""run_diff.py - generate a random RV32I program and run the RTL side of the differential test.
Prints tool output only on failure.

  python scripts/run_diff.py --seed N --count M
"""
import argparse, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
D = ROOT / "diff"
ELF, BIN = D / "tests" / "random.elf", D / "tests" / "random.bin"
HEX, VVP, TB = D / "rtl" / "instructions.hex", D / "rtl" / "diff.vvp", D / "rtl" / "tb_cpu_diff.v"


def setup_toolchain():
    """Ensure RISC-V toolchain directory is visible on PATH."""
    for env_k in ("RISCV_PATH", "RISCV_GNU_PATH", "RISCV_TOOLCHAIN_PATH"):
        if env_v := os.environ.get(env_k):
            bin_dir = os.path.join(env_v, "bin") if not env_v.endswith("bin") and os.path.exists(os.path.join(env_v, "bin")) else env_v
            if os.path.exists(bin_dir) and bin_dir.lower() not in os.environ.get("PATH", "").lower():
                os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")
    if os.name == "nt":  # default Windows RISC-V toolchain fallback path
        _p = r"C:\riscv-gnu\bin"
        if os.path.exists(_p) and _p.lower() not in os.environ.get("PATH", "").lower():
            os.environ["PATH"] = _p + os.pathsep + os.environ.get("PATH", "")


def find_toolchain_prefix(explicit=None):
    """Find the RISC-V GCC toolchain prefix (e.g. riscv-none-elf-, riscv64-unknown-elf-)."""
    if explicit:
        return explicit if explicit.endswith("-") else f"{explicit}-"
    if env_p := os.environ.get("RISCV_PREFIX"):
        return env_p if env_p.endswith("-") else f"{env_p}-"
    for cand in ("riscv-none-elf-", "riscv64-unknown-elf-", "riscv32-unknown-elf-", "riscv64-elf-", "riscv32-elf-"):
        if shutil.which(f"{cand}gcc"):
            return cand
    return "riscv-none-elf-"


def run(cmd, quiet=True):
    p = subprocess.run([str(x) for x in cmd], cwd=ROOT, capture_output=quiet, text=True)
    if p.returncode and quiet:
        sys.stderr.write(f"$ {' '.join(map(str, cmd))}\n{p.stdout}{p.stderr}")
    p.check_returncode()


def main():
    ap = argparse.ArgumentParser(description="Generate and run a random RV32I differential test.")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--count", type=int, default=500)
    ap.add_argument("--prefix", default=None, help="RISC-V toolchain prefix (e.g. riscv-none-elf-, riscv64-unknown-elf-)")
    a = ap.parse_args()
    if a.count <= 0:
        ap.error("--count must be greater than 0")

    setup_toolchain()
    prefix = find_toolchain_prefix(a.prefix)
    tools = [f"{prefix}gcc", f"{prefix}objcopy", "iverilog", "vvp"]
    if missing := [t for t in tools if not shutil.which(t)]:
        sys.exit("ERROR: not found in PATH: " + ", ".join(missing))

    gen = [sys.executable, str(ROOT / "scripts" / "gen_random.py"), "--count", str(a.count)]
    if a.seed is not None:
        gen += ["--seed", str(a.seed)]
    run(gen)
    run([f"{prefix}gcc", "-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles",
         "-T", ROOT / "linker.ld", "-o", ELF, D / "build" / "random_prog.S"])
    run([f"{prefix}objcopy", "-O", "binary", "-j", ".text", ELF, BIN])
    run([sys.executable, str(D / "scripts" / "bin_to_hex.py"), BIN, HEX])
    run(["iverilog", "-g2012", "-o", VVP, *sorted((ROOT / "rtl").glob("*.v")), TB])
    run(["vvp", VVP], quiet=False)  # sim output is the result: always shown
    return 0


if __name__ == "__main__":
    sys.exit(main())