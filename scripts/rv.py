#!/usr/bin/env python3
"""rv.py - build / run / regress for the RV32I toolchain
(replaces _common.py, build.py, run.py, regress.py).

  python scripts/rv.py build ROOT/riscv-tests/isa/rv32ui/<test_name>.S  (directory of assembly file)
  python scripts/rv.py run ROOT/riscv-tests/isa/rv32ui/<test_name>.S   (wherever the tests are stored)
  python scripts/rv.py regress 

All commands accept --root and --format. Exit code 0 = success/PASS, 1 otherwise.
"""
import argparse, os, re, shutil, struct, subprocess as sp, sys, time
from collections import namedtuple
from pathlib import Path

if os.name == "nt":  # make the Windows RISC-V toolchain visible
    _p = r"C:\riscv-gnu\bin"
    if os.path.exists(_p) and _p.lower() not in os.environ.get("PATH", "").lower():
        os.environ["PATH"] = _p + os.pathsep + os.environ.get("PATH", "")

PREFIX, MARCH, MABI = "riscv-none-elf-", "rv32i_zicsr", "ilp32"
HEX_NAME, MAX_CYCLES, SIM_TIMEOUT = "instructions.hex", 10000, 30


def _col(n):
    return (lambda s: f"\033[{n}m{s}\033[0m") if sys.stdout.isatty() else str
ok, bad, info = _col(32), _col(31), _col(36)


def find_root(explicit=None):
    cwd = Path.cwd().resolve()
    cands = ([Path(explicit).resolve()] if explicit else []) + [Path(__file__).resolve().parent.parent, cwd, *cwd.parents]
    for d in cands:
        if all((d / m).exists() for m in ("linker.ld", "rtl", "scripts")):
            return d
    raise RuntimeError("project root not found (needs linker.ld, rtl/, scripts/); use --root")


def ensure_dirs(root):
    for d in ("build", "sim", "waves", "logs"):
        (root / d).mkdir(parents=True, exist_ok=True)


def verilog_sources(root, tb="tb_cpu_official"):
    def g(d): return [f for e in ("v", "sv") for f in sorted(d.glob(f"*.{e}"))]
    t = root / "tb" / f"{tb}.v"
    return g(root / "rtl") + ([t] if t.exists() else g(root / "tb"))


def include_dirs(root):
    hints, found = {"riscv_test.h", "test_macros.h", "encoding.h"}, set()
    for p, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in {"build", "sim", "waves", "logs", ".git"}]
        if hints & set(files):
            found.add(p)
    return sorted(found)


def sh(*cmd, **kw):
    """Run a tool with its output going straight to the terminal; raises on failure."""
    sp.run([str(c) for c in cmd], check=True, **kw)


Built = namedtuple("Built", "name elf hex dis installed")


def build_one(root, source, *, march=MARCH, mabi=MABI, fmt="words", dis=True, out_name=None, quiet=False):
    say = (lambda m: None) if quiet else (lambda m: print(info(f"  -> {m}")))
    ensure_dirs(root)
    src = root / source
    name = out_name or src.stem
    obj, elf, hx = (root / "build" / f"{name}{e}" for e in (".o", ".elf", ".hex"))
    arch = (f"-march={march}", f"-mabi={mabi}")

    say(f"assembling {src}")
    sh(PREFIX + "gcc", *arch, *[f"-I{d}" for d in include_dirs(root)], "-c", "-o", obj, src)
    say("linking (linker.ld)")
    sh(PREFIX + "gcc", *arch, "-static", "-nostdlib", "-nostartfiles", "-T", root / "linker.ld", "-o", elf, obj)

    say(f"objcopy -> {fmt} hex")
    if fmt == "words":  # one 32-bit LE word per line
        tmp = hx.with_suffix(".bin")
        sh(PREFIX + "objcopy", "-O", "binary", elf, tmp)
        d = tmp.read_bytes()
        d += b"\0" * (-len(d) % 4)
        hx.write_text("".join(f"{w:08x}\n" for w in struct.unpack(f"<{len(d) // 4}I", d)))
        tmp.unlink()
    else:  # native "-O verilog" (@addr annotated)
        sh(PREFIX + "objcopy", "-O", "verilog", elf, hx)

    dp = None
    if dis:
        say("objdump -> .dis")
        dp = root / "build" / f"{name}.dis"
        with open(dp, "w") as f:
            sh(PREFIX + "objdump", "-d", elf, stdout=f)

    say(f"copy -> rtl/{HEX_NAME}")
    dest = root / "rtl" / HEX_NAME
    shutil.copyfile(hx, dest)
    return Built(name, elf, hx, dp, dest)


def compile_rtl(root, vvp_name="run", tb_name="tb_cpu_official"):
    out = root / "sim" / f"{vvp_name}.vvp"
    sh("iverilog", "-g2012", "-o", out, *verilog_sources(root, tb_name))
    return out


def run_sim(root, vvp, log, timeout=None):
    """Run vvp with CWD=rtl/ (where $readmemh finds instructions.hex); returns and logs its output."""
    t = timeout if timeout is not None else SIM_TIMEOUT
    rtl = root / "rtl"
    try:
        out = sp.run(["vvp", str(vvp)], cwd=rtl, stdout=sp.PIPE, stderr=sp.STDOUT, text=True, timeout=t).stdout
    except sp.TimeoutExpired as e:
        out = e.output or ""
        if isinstance(out, bytes):
            out = out.decode(errors="replace")
        out += f"\n[watchdog] process exceeded {t}s and was killed"
    log.write_text(out)
    for v in rtl.glob("*.vcd"):
        v.replace(root / "waves" / v.name)
    return out


def parse_sim_result(t):
    """Returns (status, detail); status in PASS / FAIL / TIMEOUT / ERROR."""
    if "TIMEOUT" in t:
        return "TIMEOUT", f"exceeded {MAX_CYCLES} cycles"
    if "RV32I TEST FAILED" in t:
        return "FAIL", "testbench timeout or explicit failure"
    f = re.findall(r"TEST\s+(\d+)\s+PC=[0-9a-fA-F]+", t)
    if f:
        return "FAIL", f"gp(x3)={f[-1]}"
    if any(s in t for s in ("PROGRAM TERMINATED", "RV32I TEST PASSED", "DIRECTED TESTS PASSED")):
        return "PASS", ""
    return "ERROR", "no PASS/FAIL/TIMEOUT marker found in simulation output"


def cmd_build(a, root):
    r = build_one(root, Path(a.source), march=a.march, mabi=a.mabi, fmt=a.format, dis=not a.no_dis, out_name=a.out_name)
    print(ok(f"BUILD OK: {r.name}"))
    for k, p in (("elf", r.elf), ("hex", r.hex), ("dis", r.dis), ("installed", r.installed)):
        if p:
            print(f"  {k}: {p.relative_to(root)}")
    return 0


def cmd_run(a, root):
    t0 = time.perf_counter()
    r = build_one(root, Path(a.source), fmt=a.format, dis=not a.no_dis)
    vvp = compile_rtl(root, r.name, a.tb)
    status, detail = parse_sim_result(run_sim(root, vvp, root / "logs" / f"{r.name}.log", a.timeout))
    line = f"{status} {r.name}" + (f"  ({detail})" if detail else "") + f"  [{time.perf_counter() - t0:.2f}s]"
    print((ok if status == "PASS" else bad)(line))
    return int(status != "PASS")


def cmd_regress(a, root):
    d = root / "riscv-tests" / "isa" / "rv32ui"
    g = d.rglob if a.recursive else d.glob
    tests = sorted({*g("*.S"), *g("*.s")})
    if not tests:
        raise FileNotFoundError(f"no .S/.s test sources found under {d}")
    print("RV32I Regression")
    t0 = time.perf_counter()
    vvp = compile_rtl(root, "regress", a.tb)  # compiled once, reused for every test
    p = f = 0
    for s in tests:
        name = re.sub(r"^rv32[a-z0-9]*-[pv]-", "", s.stem)
        try:
            r = build_one(root, s, fmt=a.format, dis=False, quiet=True)
            status, detail = parse_sim_result(run_sim(root, vvp, root / "logs" / f"{r.name}.log", a.timeout))
        except (sp.CalledProcessError, OSError) as e:
            status, detail = "ERROR", str(e).split("\n")[0]
        if status == "PASS":
            p += 1
            print(ok(f"PASS {name}"))
        else:
            f += 1
            print(bad(f"{status} {name}" + (f" ({detail})" if detail else "")))
            if a.stop_on_fail:
                break
    print(f"\nPassed: {p}\nFailed: {f}\nElapsed: {time.perf_counter() - t0:.2f} s")
    return int(f > 0)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def add(name, fn, src=True):
        p = sub.add_parser(name)
        p.set_defaults(fn=fn)
        p.add_argument("--root")
        p.add_argument("--format", choices=["words", "verilog"], default="words")
        if src:
            p.add_argument("source")
        if name != "build":
            p.add_argument("--tb", default="tb_cpu_official")
            p.add_argument("--timeout", type=float, default=None)
        if name != "regress":
            p.add_argument("--no-dis", action="store_true")
        return p

    b = add("build", cmd_build)
    b.add_argument("--march", default=MARCH)
    b.add_argument("--mabi", default=MABI)
    b.add_argument("--out-name")
    add("run", cmd_run)
    g = add("regress", cmd_regress, src=False)
    g.add_argument("--recursive", action="store_true")
    g.add_argument("--stop-on-fail", action="store_true")

    a = ap.parse_args(argv)
    root = find_root(a.root)
    if a.cmd != "regress":
        print(info(f"project root: {root}"))
    return a.fn(a, root)


if __name__ == "__main__":
    sys.exit(main())
