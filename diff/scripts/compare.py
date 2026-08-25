import re
import subprocess
import sys
import os

SPIKE_BASE = 0x80000000
END_INSN = 0x05500F93

# Paths relative to the project root (where this script is invoked from).
# Can be overridden via environment variables:
#   DIFF_ELF      - path to the ELF file to run through Spike
#   DIFF_RTL_LOG  - path to the RTL trace log
ELF       = os.environ.get("DIFF_ELF",      "diff/tests/random50.elf")
RTL_TRACE = os.environ.get("DIFF_RTL_LOG",  "diff/rtl/rtl_trace.log")

import shutil

# Locate the spike binary.  Try PATH first, then the known local build.
_SPIKE_CANDIDATES = [
    "spike",
    os.path.expanduser("~/spike-install/bin/spike"),
    "/home/parth/spike-install/bin/spike",
]
SPIKE_BIN = next((c for c in _SPIKE_CANDIDATES if shutil.which(c)), None)
if SPIKE_BIN is None:
    print("ERROR: Could not find the 'spike' binary.")
    print("       Add it to PATH or set SPIKE_BIN env var.")
    sys.exit(2)
SPIKE_BIN = os.environ.get("SPIKE_BIN", SPIKE_BIN)

def run_spike():


    cmd = [
        SPIKE_BIN,
        "--isa=RV32I",
        "--log-commits",
        # Map 4 KB at 0x2000 to cover data addresses 0x2000-0x207C.
        # Cannot use 0x0 — Spike's boot ROM occupies [0x0, 0x2000).
        # Also keep the default 2 GB region at 0x80000000 for the code.
        "-m0x2000:0x1000,0x80000000:0x80000000",
        ELF,
    ]

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    import select

    lines = []
    try:
        while True:
            # Wait up to 30 s for a line — if nothing arrives Spike is stuck
            # (e.g. trapped in a fault handler).  Kill and report.
            ready, _, _ = select.select([process.stdout], [], [], 30)
            if not ready:
                print("WARNING: Spike produced no output for 30 s — likely hung in "
                      "a trap handler (misaligned access / illegal instruction).")
                break

            line = process.stdout.readline()
            if not line:        # EOF: Spike exited on its own
                break

            lines.append(line)

            # Stop as soon as the sentinel instruction is committed —
            # no need to wait for Spike to exit (it never will: infinite loop).
            if "(0x05500f93)" in line.lower():
                break
    finally:
        process.kill()
        process.wait()

    return "".join(lines)

def parse_spike(output):

    trace = []

    # Spike --log-commits format (varies by version):
    #   core   0: 3 0x80000000 (0x00100293) x5  0x00000001
    #   core   0: 3 0x80000060 (0x008ca023)                      <- store, no rd
    #   core   0: 3 0x80000060 (0x0182a283) x5  0x80000000 mem 0x00001018  <- load
    #
    # Key points:
    #   - privilege level '3' before PC is present in this Spike version
    #   - loads append 'mem 0xADDR' AFTER the register value; we must stop
    #     the value match before 'mem' so we don't accidentally capture it
    pattern = re.compile(
        r"core\s+0:\s+(?:\d+\s+)?"            # optional priv level / commit idx
        r"0x([0-9a-fA-F]+)\s+"                # PC (32 or 64-bit)
        r"\(0x([0-9a-fA-F]+)\)"               # instruction encoding
        r"(?:\s+x\s*(\d+)\s+0x([0-9a-fA-F]+)" # rd + value (if register written)
        r"(?:\s+mem\s+0x[0-9a-fA-F]+)?)?"     # optional mem addr suffix (loads)
    )

    for line in output.splitlines():

        match = pattern.search(line)

        if not match:
            continue

        pc = int(match.group(1), 16)
        insn = int(match.group(2), 16)

        # Ignore Spike boot ROM. (RTL's PC also resets to SPIKE_BASE now, so
        # no further rebasing of pc or of AUIPC/JAL/JALR result values is
        # needed anywhere below -- both sides live in the same absolute
        # address space from reset onward.)
        if pc < SPIKE_BASE:
            continue

        rd = 0
        value = 0

        if match.group(3) is not None:
            rd = int(match.group(3))
            value = int(match.group(4), 16)

        trace.append(
            (pc, insn, rd, value)
        )

        # Stop after completion instruction.
        if insn == END_INSN:
            break

    return trace


def parse_rtl():

    trace = []

    with open(RTL_TRACE, "r") as f:

        for line in f:

            parts = line.split()

            if len(parts) != 4:
                continue

            pc = int(parts[0], 16)
            insn = int(parts[1], 16)
            rd = int(parts[2])
            value = int(parts[3], 16)

            trace.append(
                (pc, insn, rd, value)
            )

            if insn == END_INSN:
                break

    return trace


def compare(spike, rtl):

    print(f"Spike retired instructions : {len(spike)}")
    print(f"RTL retired instructions   : {len(rtl)}")
    print()

    count = min(len(spike), len(rtl))

    for i in range(count):

        s = spike[i]
        r = rtl[i]

        if s != r:

            print("========================================")
            print("           DIFFERENTIAL MISMATCH")
            print("========================================")
            print(f"Instruction index : {i}")
            print()

            print(
                f"Spike : PC={s[0]:08x} "
                f"INSN={s[1]:08x} "
                f"RD={s[2]:02d} "
                f"VALUE={s[3]:08x}"
            )

            print(
                f"RTL   : PC={r[0]:08x} "
                f"INSN={r[1]:08x} "
                f"RD={r[2]:02d} "
                f"VALUE={r[3]:08x}"
            )

            print()
            print("Result: FAIL")
            return False

    if len(spike) != len(rtl):

        print("========================================")
        print("        TRACE LENGTH MISMATCH")
        print("========================================")

        print(f"Spike : {len(spike)}")
        print(f"RTL   : {len(rtl)}")

        print()
        print("Result: FAIL")

        return False

    print("========================================")
    print("       DIFFERENTIAL TEST PASSED")
    print("========================================")

    print(f"Instructions compared : {len(spike)}")

    return True


def main():

    spike_output = run_spike()

    spike_trace = parse_spike(spike_output)
    rtl_trace = parse_rtl()

    if not spike_trace:
        print("ERROR: Spike produced no parsed trace.")
        print("       Check that 'spike' is on PATH and that the ELF is correct.")
        print(f"       ELF = {ELF!r}")
        print("--- Raw Spike output (first 20 lines) ---")
        for ln in spike_output.splitlines()[:20]:
            print(" ", ln)
        sys.exit(2)

    if not rtl_trace:
        print("ERROR: RTL trace is empty.")
        print(f"       Expected trace at: {RTL_TRACE!r}")
        sys.exit(2)

    ok = compare(spike_trace, rtl_trace)

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()