#!/usr/bin/env python3
"""Coverage linter: every contract signal must appear in its module's test file.

Turns "every boundary tested" from an intention into an invariant.
Exit 0 = full coverage for all implemented modules. Modules without a
mod_<name>.c yet are listed but don't fail the run (plan 2 backlog).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONTRACTS = os.path.join(HERE, "dino_sheet_contracts.md")
SRC = os.path.normpath(os.path.join(HERE, "..", "..", "tests", "dino_bringup", "src"))

MOD_TOKEN = {"memory address regiser": "mar", "memory data register": "mdr",
             "microcode_decoder": "microcode", "control word module": "control_word",
             "alu module": "alu", "program counter": "pc",
             "register modules": "registers", "output": "io", "root": "root"}


def expand(label):
    label = label.split("=")[-1]
    m = re.match(r"^(.*?)(\d+)-(\d+)$", label)
    if not m:
        return [label]
    return [f"{m.group(1)}{i}" for i in range(int(m.group(2)), int(m.group(3)) + 1)]


def parse_contracts():
    mods, cur = {}, None
    for line in open(CONTRACTS):
        h = re.match(r"^## (.+)$", line)
        if h:
            cur = MOD_TOKEN.get(h.group(1).strip().lower(), h.group(1).strip().lower())
            mods[cur] = set()
            continue
        m = re.match(r"^- (IN|OUT|BIDIR)\s+(.+?)\s+(?:<->|<-|->)", line)
        if m and cur:
            for part in m.group(2).split(", "):
                mods[cur].update(expand(part.strip()))
    return mods


def main():
    mods = parse_contracts()
    failures, pending = [], []
    for mod, signals in sorted(mods.items()):
        path = os.path.join(SRC, f"mod_{mod}.c")
        if not os.path.exists(path):
            pending.append(mod)
            continue
        body = open(path).read()
        missing = sorted(s for s in signals if s not in body)
        if missing:
            failures.append((mod, missing))
    for mod, missing in failures:
        print(f"COVERAGE GAP {mod}: {', '.join(missing)}")
    for mod in pending:
        print(f"not implemented (plan 2): {mod}")
    print(f"{len(failures)} module(s) with gaps, {len(pending)} pending")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
