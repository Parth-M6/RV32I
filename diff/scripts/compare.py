import os, queue, re, shutil, subprocess, sys, threading

SPIKE_BASE, END_INSN = 0x80000000, 0x05500F93
ELF = os.environ.get("DIFF_ELF", "diff/tests/random.elf")
RTL_TRACE = os.environ.get("DIFF_RTL_LOG", "diff/rtl/rtl_trace.log")


def find_spike():
    cands = [os.environ.get("SPIKE_BIN"), "spike", os.path.expanduser("~/spike-install/bin/spike"),
             "/home/parth/spike-install/bin/spike"]
    for p in cands:
        if p and shutil.which(p):
            return [p]
    if os.name == "nt" and shutil.which("wsl"):
        wsl_cands = [os.environ.get("SPIKE_BIN"), "spike", "~/spike-install/bin/spike",
                     "/home/parth/spike-install/bin/spike"]
        for c in wsl_cands:
            if not c:
                continue
            res = subprocess.run(["wsl", "sh", "-c", f"command -v {c} || [ -x {c} ]"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if res.returncode == 0:
                return ["wsl", c]
    return ["spike"]


# Spike --log-commits lines:  core   0: 3 0x80000000 (0x00100293) x5  0x00000001
# stores have no rd; loads append "mem 0xADDR" after the value (must not be captured as the value).
LINE = re.compile(r"core\s+0:\s+(?:\d+\s+)?0x([0-9a-fA-F]+)\s+\(0x([0-9a-fA-F]+)\)"
                  r"(?:\s+x\s*(\d+)\s+0x([0-9a-fA-F]+)(?:\s+mem\s+0x[0-9a-fA-F]+)?)?")
BAR = "=" * 40


def run_spike():
    # 4 KB at 0x2000 covers the data addresses (Spike's boot ROM owns [0, 0x2000)); keep the default 2 GB at 0x80000000.
    spike_cmd = find_spike()
    elf_arg = str(ELF).replace("\\", "/")
    cmd = [*spike_cmd, "--isa=RV32I", "--log-commits", "-m0x2000:0x1000,0x80000000:0x80000000", elf_arg]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    q = queue.Queue()

    def enqueue_output(out, q):
        try:
            for line in iter(out.readline, ''):
                q.put(line)
        except Exception:
            pass
        finally:
            out.close()

    t = threading.Thread(target=enqueue_output, args=(p.stdout, q), daemon=True)
    t.start()

    lines = []
    try:
        while True:
            try:
                line = q.get(timeout=30)
            except queue.Empty:
                print("WARNING: Spike produced no output for 30 s — likely hung in "
                      "a trap handler (misaligned access / illegal instruction).")
                break
            if not line:
                break
            lines.append(line)
            if "(0x05500f93)" in line.lower():  # Spike never exits (infinite loop); stop at the sentinel
                break
    finally:
        p.kill()
        p.wait()
    return "".join(lines)


def parse_spike(output):
    trace = []
    for line in output.splitlines():
        m = LINE.search(line)
        if not m:
            continue
        pc, insn = int(m[1], 16), int(m[2], 16)
        if pc < SPIKE_BASE:  # skip boot ROM; RTL PC also resets to SPIKE_BASE, so no rebasing needed
            continue
        trace.append((pc, insn, int(m[3] or 0), int(m[4] or "0", 16)))
        if insn == END_INSN:
            break
    return trace


def parse_rtl():
    trace = []
    with open(RTL_TRACE, encoding="utf-8") as f:
        for line in f:
            p = line.split()
            if len(p) != 4:
                continue
            trace.append((int(p[0], 16), int(p[1], 16), int(p[2]), int(p[3], 16)))
            if trace[-1][1] == END_INSN:
                break
    return trace


def fmt(t):
    return f"PC={t[0]:08x} INSN={t[1]:08x} RD={t[2]:02d} VALUE={t[3]:08x}"


def compare(spike, rtl):
    print(f"Spike retired instructions : {len(spike)}\nRTL retired instructions   : {len(rtl)}\n")
    for i, (s, r) in enumerate(zip(spike, rtl)):
        if s != r:
            print(f"{BAR}\n           DIFFERENTIAL MISMATCH\n{BAR}\nInstruction index : {i}\n")
            print(f"Spike : {fmt(s)}\nRTL   : {fmt(r)}\n\nResult: FAIL")
            return False
    if len(spike) != len(rtl):
        print(f"{BAR}\n        TRACE LENGTH MISMATCH\n{BAR}\nSpike : {len(spike)}\nRTL   : {len(rtl)}\n\nResult: FAIL")
        return False
    print(f"{BAR}\n       DIFFERENTIAL TEST PASSED\n{BAR}\nInstructions compared : {len(spike)}")
    return True


def main():
    out = run_spike()
    spike, rtl = parse_spike(out), parse_rtl()
    if not spike:
        print(f"ERROR: Spike produced no parsed trace (ELF = {ELF!r}).\n--- Raw Spike output (first 20 lines) ---")
        print("\n".join("  " + l for l in out.splitlines()[:20]))
        sys.exit(2)
    if not rtl:
        print(f"ERROR: RTL trace is empty (expected at {RTL_TRACE!r}).")
        sys.exit(2)
    sys.exit(0 if compare(spike, rtl) else 1)


if __name__ == "__main__":
    main()
