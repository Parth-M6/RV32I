#!/usr/bin/env python3
"""
build.py - assemble + link + objcopy (+ optional disassembly) a single
RV32I test source, for a hand-rolled single-cycle CPU.

Usage:
    python3 scripts/build.py mytests/add.S
    python3 scripts/build.py build/riscv-tests/isa/rv32ui/rv32ui-p-addi.S
    python3 scripts/build.py mytests/add.S --format verilog --no-dis

Pipeline:
    <source>.S --(gcc -c)--> .o --(gcc -T linker.ld)--> .elf
              --(objcopy)--> .hex   [--(objdump)--> .dis]
              --(copy)--> rtl/instructions.hex

Notes:
  - Auto-detects the project root (see _common.find_project_root), so this
    works regardless of the machine or the directory you invoke it from.
  - The hex is ALWAYS copied to rtl/instructions.hex after a successful
    build - there is no --copy flag anymore, copying just always happens.
  - Two hex formats are supported:
      "words"   (default) - one 32-bit little-endian instruction word per
                 line, no addresses. This is the common format expected by
                 a simple $readmemh-based instruction memory in a
                 single-cycle student CPU.
      "verilog" - objcopy's native "-O verilog" output (contains @addr
                 annotations). Use this if your instruction memory expects
                 sparse / addressed $readmemh data instead.
"""
from __future__ import annotations

import argparse
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional

# Ensure sibling scripts are importable when invoked as `python scripts/build.py`
_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

import _common as c


@dataclass
class BuildResult:
    name: str
    source: Path
    obj: Path
    elf: Path
    hex: Path
    dis: Optional[Path]
    hex_installed_at: Path


def _tool(prefix: str, name: str) -> str:
    return f"{prefix}{name}"


def assemble(root: Path, source: Path, out_obj: Path, march: str, mabi: str,
             include_dirs: List[str], prefix: str) -> None:
    cmd = [
        _tool(prefix, "gcc"),
        f"-march={march}", f"-mabi={mabi}",
    ] + [f"-I{d}" for d in include_dirs] + [
        "-c", "-o", str(out_obj), str(source),
    ]
    c.run_cmd(cmd, cwd=root)


def link(root: Path, obj: Path, out_elf: Path, march: str, mabi: str, prefix: str) -> None:
    linker_script = root / "linker.ld"
    if not linker_script.exists():
        raise RuntimeError(f"linker.ld not found at {linker_script}")
    cmd = [
        _tool(prefix, "gcc"),
        f"-march={march}", f"-mabi={mabi}",
        "-static", "-nostdlib", "-nostartfiles",
        "-T", str(linker_script),
        "-o", str(out_elf), str(obj),
    ]
    c.run_cmd(cmd, cwd=root)


def objcopy_words(root: Path, elf: Path, out_hex: Path, prefix: str) -> None:
    """objcopy -> raw binary -> one 8-hex-digit instruction word per line."""
    tmp_bin = out_hex.with_suffix(".bin")
    c.run_cmd([_tool(prefix, "objcopy"), "-O", "binary", str(elf), str(tmp_bin)], cwd=root)

    data = tmp_bin.read_bytes()
    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)  # pad to a whole number of words

    words = struct.unpack(f"<{len(data)//4}I", data)
    out_hex.write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    tmp_bin.unlink(missing_ok=True)


def objcopy_verilog(root: Path, elf: Path, out_hex: Path, prefix: str) -> None:
    c.run_cmd([_tool(prefix, "objcopy"), "-O", "verilog", str(elf), str(out_hex)], cwd=root)


def objdump_dis(root: Path, elf: Path, out_dis: Path, prefix: str) -> None:
    text = c.run_cmd([_tool(prefix, "objdump"), "-d", str(elf)], cwd=root)
    out_dis.write_text(text)


def copy_hex_to_rtl(root: Path, hex_path: Path) -> Path:
    dest = c.rtl_dir(root) / c.CONFIG["hex_filename"]
    dest.write_bytes(hex_path.read_bytes())
    return dest


def build_one(root: Path, source: Path, *, march: Optional[str] = None,
              mabi: Optional[str] = None, fmt: str = "words", dis: bool = True,
              prefix: Optional[str] = None, out_name: Optional[str] = None,
              quiet: bool = False) -> BuildResult:
    march = march or c.CONFIG["march"]
    mabi = mabi or c.CONFIG["mabi"]
    prefix = prefix or c.CONFIG["toolchain_prefix"]

    c.ensure_dirs(root)
    source = source if source.is_absolute() else (root / source)
    if not source.exists():
        raise FileNotFoundError(f"source file not found: {source}")

    name = out_name or source.stem
    build_dir = root / "build"
    obj = build_dir / f"{name}.o"
    elf = build_dir / f"{name}.elf"
    hex_ = build_dir / f"{name}.hex"
    dis_path = build_dir / f"{name}.dis" if dis else None
    include_dirs = c.find_include_dirs(root)

    def step(msg):
        if not quiet:
            print(c.info(f"  -> {msg}"))

    step(f"assembling {source.relative_to(root) if source.is_relative_to(root) else source}")
    assemble(root, source, obj, march, mabi, include_dirs, prefix)

    step("linking (linker.ld)")
    link(root, obj, elf, march, mabi, prefix)

    step(f"objcopy -> {fmt} hex")
    if fmt == "words":
        objcopy_words(root, elf, hex_, prefix)
    elif fmt == "verilog":
        objcopy_verilog(root, elf, hex_, prefix)
    else:
        raise ValueError(f"unknown --format {fmt!r} (expected 'words' or 'verilog')")

    if dis_path is not None:
        step("objdump -> .dis")
        objdump_dis(root, elf, dis_path, prefix)

    step(f"copy -> rtl/{c.CONFIG['hex_filename']}")
    installed = copy_hex_to_rtl(root, hex_)

    return BuildResult(name, source, obj, elf, hex_, dis_path, installed)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Assemble/link/objcopy a single RV32I test.")
    ap.add_argument("source", help="path to a .S test source (e.g. mytests/add.S)")
    ap.add_argument("--root", help="override auto-detected project root")
    ap.add_argument("--march", default=None)
    ap.add_argument("--mabi", default=None)
    ap.add_argument("--format", choices=["words", "verilog"], default="words",
                     help="instruction hex format (default: words)")
    ap.add_argument("--no-dis", action="store_true", help="skip .dis disassembly output")
    ap.add_argument("--out-name", default=None, help="override output basename")
    args = ap.parse_args(argv)

    root = c.find_project_root(args.root)
    print(c.info(f"project root: {root}"))

    try:
        result = build_one(
            root, Path(args.source),
            march=args.march, mabi=args.mabi, fmt=args.format,
            dis=not args.no_dis, out_name=args.out_name,
        )
    except (c.CommandError, RuntimeError, FileNotFoundError) as e:
        print(c.bad(f"BUILD FAILED: {e}"))
        return 1

    print(c.ok(f"BUILD OK: {result.name}"))
    print(f"  elf: {result.elf.relative_to(root)}")
    print(f"  hex: {result.hex.relative_to(root)}")
    if result.dis:
        print(f"  dis: {result.dis.relative_to(root)}")
    print(f"  installed: {result.hex_installed_at.relative_to(root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
