#!/usr/bin/env python3
"""
regress.py - one-command regression runner for the RV32I single-cycle CPU.

Usage:
    python3 scripts/regress.py official
    python3 scripts/regress.py mytests
    python3 scripts/regress.py build/riscv-tests/isa/rv32ui

"official" is a convenience keyword: it resolves to whichever of these
exists first:
    <root>/official
    <root>/build/riscv-tests/isa/rv32ui

Any other argument is treated as a directory path, relative to the project
root (or absolute).

Output:
    RV32I Regression
    PASS add
    PASS addi
    ...
    PASS auipc

    Passed: 23
    Failed: 0
    Elapsed: 2.17 s

RTL is compiled ONCE up front and reused for every test (only
rtl/instructions.hex changes between runs), which is what makes a full
regression fast.

Exit code: 0 if every test passed, 1 otherwise.
"""
from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path
from typing import List

import _common as c
from build import build_one
from run import compile_rtl, run_sim

_PREFIX_RE = re.compile(r"^rv32[a-z0-9]*-[pv]-")


def resolve_test_dir(root: Path, arg: str) -> Path:
    if arg == "official":
        for cand in (root / "official", root / "build" / "riscv-tests" / "isa" / "rv32ui"):
            if cand.is_dir():
                return cand
        raise FileNotFoundError(
            "could not find an official test directory - looked for "
            f"{root / 'official'} and {root / 'build/riscv-tests/isa/rv32ui'}"
        )

    p = Path(arg)
    p = p if p.is_absolute() else (root / p)
    if not p.is_dir():
        raise FileNotFoundError(f"test directory not found: {p}")
    return p


def collect_tests(test_dir: Path, recursive: bool = False) -> List[Path]:
    pattern_glob = test_dir.rglob if recursive else test_dir.glob
    tests = sorted(set(pattern_glob("*.S")) | set(pattern_glob("*.s")))
    if not tests:
        raise FileNotFoundError(f"no .S/.s test sources found under {test_dir}")
    return tests


def display_name(source: Path) -> str:
    return _PREFIX_RE.sub("", source.stem)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Run a full regression over a directory of RV32I tests.")
    ap.add_argument("suite", help="'official', or a directory path (e.g. mytests)")
    ap.add_argument("--root", help="override auto-detected project root")
    ap.add_argument("--recursive", action="store_true", help="search test_dir recursively")
    ap.add_argument("--format", choices=["words", "verilog"], default="words")
    ap.add_argument("--timeout", type=float, default=None,
                     help="python-level per-test wall clock watchdog, seconds")
    ap.add_argument("--stop-on-fail", action="store_true")
    args = ap.parse_args(argv)

    root = c.find_project_root(args.root)
    c.ensure_dirs(root)

    try:
        test_dir = resolve_test_dir(root, args.suite)
        tests = collect_tests(test_dir, recursive=args.recursive)
    except FileNotFoundError as e:
        print(c.bad(f"ERROR: {e}"))
        return 1

    print(f"{c.C.BOLD}RV32I Regression{c.C.RESET}")

    t_start = time.perf_counter()

    try:
        vvp_path = compile_rtl(root, vvp_name="regress")
    except c.CommandError as e:
        print(c.bad(f"RTL COMPILE FAILED:\n{e}"))
        return 1

    passed = 0
    failed = 0

    for source in tests:
        name = display_name(source)
        try:
            result = build_one(root, source, fmt=args.format, dis=False, quiet=True)
            log_path = root / "logs" / f"{result.name}.log"
            log_text = run_sim(root, vvp_path, log_path, timeout=args.timeout)
            status, detail = c.parse_sim_result(log_text)
        except (c.CommandError, RuntimeError, FileNotFoundError) as e:
            status, detail = "ERROR", str(e).splitlines()[0]

        if status == "PASS":
            passed += 1
            print(c.ok(f"PASS {name}"))
        else:
            failed += 1
            suffix = f" ({detail})" if detail else ""
            print(c.bad(f"{status} {name}{suffix}"))
            if args.stop_on_fail:
                break

    elapsed = time.perf_counter() - t_start

    print()
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Elapsed: {elapsed:.2f} s")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
