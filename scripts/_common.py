#!/usr/bin/env python3
"""
_common.py - shared helpers for the RV32I build/test toolchain.

New: find_verilog_sources() accepts an optional `tb_name` argument
(e.g. "tb_cpu_official" or "tb_cpu_custom") so only that one testbench
file is compiled.  When tb/ held a single file this was not needed; now
that both testbenches live under tb/ we must select exactly one to avoid
a duplicate-module iverilog error.

Imported by build.py, run.py and regress.py. Not meant to be run directly.

Design goals:
  - Auto-detect the project root so scripts work from any CWD, on any
    machine, without hardcoded absolute paths.
  - Centralize toolchain/simulator configuration in one place (CONFIG below)
    so the whole flow is easy to retarget.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import List, Optional, Sequence

# Windows-specific: Add C:\riscv-gnu\bin to PATH if it exists and is missing
if os.name == 'nt':
    _rv_path = r"C:\riscv-gnu\bin"
    if os.path.exists(_rv_path) and _rv_path.lower() not in os.environ.get("PATH", "").lower():
        os.environ["PATH"] = _rv_path + os.pathsep + os.environ.get("PATH", "")

# --------------------------------------------------------------------------
# Configuration - edit here if your toolchain/simulator names differ.
# --------------------------------------------------------------------------
CONFIG = {
    "toolchain_prefix": "riscv-none-elf-",
    "march": "rv32i_zicsr",
    "mabi": "ilp32",
    "iverilog": "iverilog",
    "vvp": "vvp",
    "hex_filename": "instructions.hex",   # fixed name the testbench $readmemh's
    "max_cycles_hint": 10000,             # informational only; enforced in RTL
    "sim_wall_timeout_s": 30,             # python-level watchdog, safety net
}

# --------------------------------------------------------------------------
# Terminal colors (auto-disabled when not attached to a tty, e.g. CI logs)
# --------------------------------------------------------------------------
class C:
    USE = sys.stdout.isatty()
    GREEN = "\033[32m" if USE else ""
    RED = "\033[31m" if USE else ""
    YELLOW = "\033[33m" if USE else ""
    CYAN = "\033[36m" if USE else ""
    BOLD = "\033[1m" if USE else ""
    RESET = "\033[0m" if USE else ""


def ok(msg: str) -> str:
    return f"{C.GREEN}{msg}{C.RESET}"


def bad(msg: str) -> str:
    return f"{C.RED}{msg}{C.RESET}"


def warn(msg: str) -> str:
    return f"{C.YELLOW}{msg}{C.RESET}"


def info(msg: str) -> str:
    return f"{C.CYAN}{msg}{C.RESET}"


# --------------------------------------------------------------------------
# Project root auto-detection
# --------------------------------------------------------------------------
_MARKERS = ("linker.ld", "rtl", "scripts")


def find_project_root(explicit: Optional[str] = None) -> Path:
    """
    Locate the riscv/ project root so every script is portable across
    machines and callable from any working directory.

    Resolution order:
      1. --root, if the caller passed one explicitly.
      2. The parent of this file's directory (scripts/_common.py -> root).
      3. Walking upward from the current working directory.

    A candidate is accepted only if it contains all of _MARKERS, so we don't
    silently pick the wrong ancestor directory.
    """
    candidates: List[Path] = []

    if explicit:
        candidates.append(Path(explicit).resolve())

    candidates.append(Path(__file__).resolve().parent.parent)

    cwd = Path.cwd().resolve()
    candidates.append(cwd)
    candidates.extend(cwd.parents)

    for cand in candidates:
        if cand.exists() and all((cand / m).exists() for m in _MARKERS):
            return cand

    raise RuntimeError(
        "Could not auto-detect the project root (expected to find "
        f"{_MARKERS} together under a common ancestor). Run scripts from "
        "inside the riscv/ project tree, or pass --root /path/to/riscv."
    )


# --------------------------------------------------------------------------
# Directory layout helpers
# --------------------------------------------------------------------------
def ensure_dirs(root: Path) -> None:
    for d in ("build", "sim", "waves", "logs"):
        (root / d).mkdir(parents=True, exist_ok=True)


def rtl_dir(root: Path) -> Path:
    return root / "rtl"


def tb_dir(root: Path) -> Path:
    return root / "tb"


def find_verilog_sources(root: Path, tb_name: str = "tb_cpu_official") -> List[Path]:
    """All RTL + testbench sources, in a stable, deterministic order.

    `tb_name` selects which top-level testbench to compile (file stem,
    without the .v suffix).  Only the matching file from tb/ is included;
    this prevents duplicate-module errors when multiple testbench files
    coexist in the same directory.
    """
    sources: List[Path] = []

    # All RTL files
    rtl = rtl_dir(root)
    if rtl.exists():
        sources.extend(sorted(rtl.glob("*.v")))
        sources.extend(sorted(rtl.glob("*.sv")))

    # Only the requested testbench
    tb = tb_dir(root)
    if tb.exists():
        tb_file = tb / f"{tb_name}.v"
        if tb_file.exists():
            sources.append(tb_file)
        else:
            # Fall back: accept any .v/.sv in tb/ (legacy single-file layout)
            sources.extend(sorted(tb.glob("*.v")))
            sources.extend(sorted(tb.glob("*.sv")))

    if not sources:
        raise RuntimeError(
            f"No .v/.sv files found under {rtl_dir(root)} or {tb_dir(root)}"
        )
    return sources


_HEADER_HINTS = {"riscv_test.h", "test_macros.h", "encoding.h"}
_SKIP_DIRS = {"build", "sim", "waves", "logs", ".git"}


def find_include_dirs(root: Path) -> List[str]:
    """
    Auto-discover include directories needed by the official riscv-tests
    sources (riscv_test.h, test_macros.h, encoding.h live under
    build/riscv-tests/...). Harmless / unused for plain hand-written .S
    files in mytests/, since gcc simply won't need those headers.
    """
    found = set()
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in _SKIP_DIRS]
        if _HEADER_HINTS.intersection(filenames):
            found.add(dirpath)
    return sorted(found)


# --------------------------------------------------------------------------
# Subprocess helpers
# --------------------------------------------------------------------------
class CommandError(RuntimeError):
    def __init__(self, cmd: Sequence[str], returncode: int, output: str):
        super().__init__(f"command failed ({returncode}): {' '.join(map(str, cmd))}\n{output}")
        self.cmd = cmd
        self.returncode = returncode
        self.output = output


def run_cmd(cmd: Sequence[str], cwd: Optional[Path] = None, timeout: Optional[float] = None) -> str:
    """Run a command to completion, returning combined stdout+stderr.
    Raises CommandError on non-zero exit, missing executable, or timeout."""
    cmd = [str(c) for c in cmd]
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError as e:
        raise CommandError(cmd, -1, f"executable not found on PATH: {e}") from e
    except subprocess.TimeoutExpired as e:
        out = e.output or ""
        raise CommandError(
            cmd, -2, out + f"\n[watchdog] process exceeded {timeout}s and was killed"
        ) from e

    if proc.returncode != 0:
        raise CommandError(cmd, proc.returncode, proc.stdout or "")
    return proc.stdout or ""


def timed(fn, *args, **kwargs):
    t0 = time.perf_counter()
    result = fn(*args, **kwargs)
    return result, time.perf_counter() - t0


# --------------------------------------------------------------------------
# Simulation output parsing (matches the tb_ubuntu testbench convention)
# --------------------------------------------------------------------------
_TEST_LINE_RE = re.compile(r"TEST\s+(\d+)\s+PC=([0-9a-fA-F]+)")


def parse_sim_result(log_text: str):
    """
    Interpret tb_ubuntu's simulation log.

    Convention (matches the standard riscv-tests pass/fail trap):
      - the tb prints "TEST <n> PC=<pc>" every cycle where gp (x3) != 0,
        i.e. ANY such line means some riscv-tests assertion failed.
      - reaching the self-loop instruction 0x00000063 (beq x0,x0,0) prints
        "PROGRAM TERMINATED" and dumps registers, then $finish.
      - exceeding the cycle budget prints "TIMEOUT" then $finish.

    Returns (status, detail) with status in {"PASS", "FAIL", "TIMEOUT", "ERROR"}.
    """
    if "TIMEOUT" in log_text:
        return "TIMEOUT", f"exceeded {CONFIG['max_cycles_hint']} cycles"

    if "RV32I TEST FAILED" in log_text:
        return "FAIL", "testbench timeout or explicit failure"

    fails = _TEST_LINE_RE.findall(log_text)
    if fails:
        last_gp = fails[-1][0]
        return "FAIL", f"gp(x3)={last_gp}"

    if ("PROGRAM TERMINATED" in log_text
            or "RV32I TEST PASSED" in log_text
            or "DIRECTED TESTS PASSED" in log_text):
        return "PASS", ""

    return "ERROR", "no PASS/FAIL/TIMEOUT marker found in simulation output"
