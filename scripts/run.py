#!/usr/bin/env python3
"""
run.py - single-command test pipeline for the RV32I single-cycle CPU.

Usage:
    python3 scripts/run.py mytests/add.S
    python3 scripts/run.py build/riscv-tests/isa/rv32ui/rv32ui-p-addi.S --timeout 60

Pipeline:
    Assemble -> Link -> Objcopy -> Copy instructions.hex -> Compile RTL
    -> Run simulation -> PASS/FAIL

Exit code: 0 on PASS, 1 on FAIL/TIMEOUT/ERROR (so this composes cleanly with
shell scripts / CI).
"""
from __future__ import annotations

import argparse
import shutil
import sys
import time
from pathlib import Path
from typing import Optional

# Ensure sibling scripts are importable when invoked as `python scripts/run.py`
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import _common as c
from build import build_one


def compile_rtl(root: Path, vvp_name: str = "run",
                tb_name: str = "tb_cpu_official") -> Path:
    """Compile all rtl/ + tb/ sources into a single vvp image."""
    sources = c.find_verilog_sources(root, tb_name=tb_name)
    out_vvp = root / "sim" / f"{vvp_name}.vvp"
    cmd = [c.CONFIG["iverilog"], "-g2012", "-o", str(out_vvp)] + [str(s) for s in sources]
    c.run_cmd(cmd, cwd=root)
    return out_vvp


def run_sim(root: Path, vvp_path: Path, log_path: Path,
            timeout: Optional[float] = None) -> str:
    """
    Execute the compiled testbench. Runs with CWD = rtl/, since that's where
    instructions.hex is installed and where the testbench's $readmemh call
    expects to find it.
    """
    timeout = timeout if timeout is not None else c.CONFIG["sim_wall_timeout_s"]
    work_dir = c.rtl_dir(root)

    try:
        log_text = c.run_cmd([c.CONFIG["vvp"], str(vvp_path)], cwd=work_dir, timeout=timeout)
    except c.CommandError as e:
        log_text = e.output

    log_path.write_text(log_text)

    # Move any VCD dumps the testbench produced into waves/
    waves_dir = root / "waves"
    for vcd in work_dir.glob("*.vcd"):
        dest = waves_dir / vcd.name
        shutil.move(str(vcd), str(dest))

    return log_text


def full_pipeline(root: Path, source: Path, *, fmt: str = "words", dis: bool = True,
                   timeout: Optional[float] = None, quiet: bool = False,
                   shared_vvp: Optional[Path] = None,
                   tb_name: str = "tb_cpu_official"):
    """
    Runs the whole Assemble->Link->Objcopy->Copy->Compile->Simulate flow for
    one test. If `shared_vvp` is given (used by regress.py), RTL compilation
    is skipped and that pre-built vvp is reused - only the hex is swapped
    out and the simulation is re-run.

    Returns (status, detail, elapsed_seconds, build_result_name).
    """
    c.ensure_dirs(root)
    t0 = time.perf_counter()

    result = build_one(root, source, fmt=fmt, dis=dis, quiet=quiet)

    vvp_path = shared_vvp if shared_vvp is not None else compile_rtl(
        root, result.name, tb_name=tb_name
    )

    log_path = root / "logs" / f"{result.name}.log"
    log_text = run_sim(root, vvp_path, log_path, timeout=timeout)

    status, detail = c.parse_sim_result(log_text)
    elapsed = time.perf_counter() - t0
    return status, detail, elapsed, result.name


def main(argv=None):
    ap = argparse.ArgumentParser(description="Assemble, link, simulate and check one RV32I test.")
    ap.add_argument("source", help="path to a .S test source (e.g. mytests/add.S)")
    ap.add_argument("--root", help="override auto-detected project root")
    ap.add_argument("--format", choices=["words", "verilog"], default="words")
    ap.add_argument("--no-dis", action="store_true")
    ap.add_argument("--tb", default="tb_cpu_official",
                     help="testbench module to compile (default: tb_cpu_official)")
    ap.add_argument("--timeout", type=float, default=None,
                     help=f"python-level wall clock watchdog in seconds "
                          f"(default {c.CONFIG['sim_wall_timeout_s']}s)")
    args = ap.parse_args(argv)

    root = c.find_project_root(args.root)
    print(c.info(f"project root: {root}"))

    try:
        status, detail, elapsed, name = full_pipeline(
            root, Path(args.source), fmt=args.format, dis=not args.no_dis,
            timeout=args.timeout, tb_name=args.tb,
        )
    except (c.CommandError, RuntimeError, FileNotFoundError) as e:
        print(c.bad(f"PIPELINE ERROR: {e}"))
        return 1

    line = f"{status} {name}"
    if detail:
        line += f"  ({detail})"
    line += f"  [{elapsed:.2f}s]"

    print(c.ok(line) if status == "PASS" else c.bad(line))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
