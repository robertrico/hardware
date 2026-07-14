#!/usr/bin/env python3
"""Cross-sheet completeness audit for the DINO hierarchy.

KiCad treats each sheet's local labels as a netlist island (strike-5 class in
dino_session_state.md): a label spelled two ways never connects and per-sheet
ERC can't see it. This tool exports the authoritative netlist via kicad-cli,
merges per-sheet nets by leaf label text (the project's physical wiring
convention between boards), then checks:

  1. floating pins    — KiCad 'unconnected-' nets (real, per-pin)
  2. undriven nets    — consumed somewhere, no output/tri_state/power_out
                        anywhere (memory-chip I/O pins are typed 'input' in
                        the 74xx lib, so ROM/RAM/EEPROM refs are annotated)
  3. unconsumed nets  — driven somewhere, no input pin anywhere
  4. name near-misses — net names identical modulo case/_/~{} wrapper
  5. single-pin nets  — a label that touches exactly one pin project-wide

Usage: python3 kicad_xsheet_audit.py [root.kicad_sch]
Default root: dino_v0_0_2/dino_v0_0_2.kicad_sch relative to the repo.
"""
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kicad_netlist as knl

KICAD_CLI = "/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli"
DRIVER_TYPES = {"output", "tri_state", "bidirectional", "power_out"}
# chips whose data pins are mistyped 'input' in the KiCad lib (see session
# notes: CW0-15 false positive class)
MEMORY_REFS_HINT = re.compile(r"AT28|628128|HM62|27C|28C|EEPROM|RAM|ROM", re.I)


def export_netlist(root):
    fd, path = tempfile.mkstemp(suffix=".net")
    os.close(fd)
    subprocess.run(
        [KICAD_CLI, "sch", "export", "netlist", "--format", "kicadsexpr",
         "-o", path, root],
        check=True, capture_output=True)
    return path


def parse(netfile):
    text = open(netfile).read()
    # component ref -> value (for memory-chip annotation)
    values = dict(re.findall(
        r'\(comp\s*\(ref "([^"]+)"\)\s*\(value "([^"]+)"\)', text))
    nets = []  # (name, [(ref, pin, pintype), ...])
    body = text[text.index("(nets"):]
    for chunk in re.split(r"\(net\n", body)[1:]:
        name = re.search(r'\(name "([^"]+)"\)', chunk).group(1)
        nodes = re.findall(
            r'\(ref "([^"]+)"\)\s*\(pin "([^"]+)"\)\s*(?:\(pinfunction "[^"]*"\)\s*)?\(pintype "([^"]+)"\)',
            chunk)
        nets.append((name, nodes))
    return values, nets


def leaf(name):
    return name.rsplit("/", 1)[-1]


def canon(label):
    """Fold the spelling variations that produced strike-5 bugs."""
    s = label.replace("~{", "").replace("}", "").replace("_", "").upper()
    return s


def sheet_files(root):
    text = open(root).read()
    d = os.path.dirname(root)
    files = [root]
    for m in re.finditer(r'\(property "Sheetfile" "([^"]+)"', text):
        files.append(os.path.join(d, m.group(1)))
    return files


def label_alias_groups(sch_path):
    """Groups of label texts that share a conductor on one sheet.

    Reuses kicad_netlist's tokenizer + the same wire-splitting/union rules,
    including its same-name-label merge, so an alias found here is exactly
    what that tool (and the physical build convention) treats as one net.
    """
    root = knl.parse(knl.tokenize(open(sch_path).read()))
    wires = []
    for w in knl.children(root, 'wire'):
        xys = knl.children(knl.child(w, 'pts'), 'xy')
        wires.append(((round(float(xys[0][1]), 3), round(float(xys[0][2]), 3)),
                      (round(float(xys[1][1]), 3), round(float(xys[1][2]), 3))))
    labels = []
    for kind in ('label', 'global_label', 'hierarchical_label'):
        for l in knl.children(root, kind):
            at = knl.child(l, 'at')
            labels.append((l[1], (round(float(at[1]), 3), round(float(at[2]), 3))))

    points = {p for w in wires for p in w} | {l[1] for l in labels}
    segs = []
    for a, b in wires:
        pts = sorted({a, b} | {p for p in points if p not in (a, b) and knl.on_seg(p, a, b)})
        segs += list(zip(pts, pts[1:]))

    parent = {}

    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a, b in segs:
        parent[find(a)] = find(b)
    by_name = defaultdict(list)
    for name, pt in labels:
        by_name[name].append(pt)
    for name, pts in by_name.items():
        for p in pts[1:]:
            parent[find(pts[0])] = find(p)

    groups = defaultdict(set)
    for name, pt in labels:
        groups[find(pt)].add(name)
    return [g for g in groups.values() if len(g) > 1]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.normpath(
        os.path.join(here, "..", "..", "dino_v0_0_2", "dino_v0_0_2.kicad_sch"))
    netfile = export_netlist(root)
    values, nets = parse(netfile)
    os.unlink(netfile)

    # label-alias groups from every sheet: map each label to a canonical
    # group representative so SA2/CW9-style tap pairs merge project-wide
    alias_rep = {}
    alias_note = {}
    for sf in sheet_files(root):
        for group in label_alias_groups(sf):
            rep = min(group)
            for g in group:
                rep = alias_rep.get(g, rep)  # chain into existing group
            for g in group:
                alias_rep[g] = rep
            alias_note[rep] = "=".join(sorted(group))

    floating = []          # unconnected- pins
    merged = {}            # merged label -> {sheets, nodes}
    for name, nodes in nets:
        if name.startswith("unconnected-"):
            floating.extend(f"{r}.{p} ({t})" for r, p, t in nodes)
            continue
        if name.startswith("Net-("):   # anonymous point-to-point, fine
            continue
        key = leaf(name)
        key = alias_note.get(alias_rep.get(key, key), key)
        e = merged.setdefault(key, {"sheets": set(), "nodes": []})
        sheet = name.rsplit("/", 1)[0] or "/"
        e["sheets"].add(sheet)
        e["nodes"].extend(nodes)

    print(f"== merged logical nets: {len(merged)} ==\n")

    print("-- 1. floating pins (KiCad 'unconnected-') --")
    for f in sorted(floating):
        print("   ", f)
    if not floating:
        print("    none")

    undriven, unconsumed, singles = [], [], []
    for label, e in sorted(merged.items()):
        types = [t.split("+")[0] for _, _, t in e["nodes"]]
        pins = [f"{r}.{p}" for r, p, _ in e["nodes"]]
        refs = {r for r, _, _ in e["nodes"]}
        has_driver = any(t in DRIVER_TYPES for t in types)
        has_input = any(t == "input" for t in types)
        mem = any(MEMORY_REFS_HINT.search(values.get(r, "")) for r in refs)
        if label in ("+5V", "GND"):
            continue
        if len(e["nodes"]) == 1:
            singles.append(f"{label:24s} {pins[0]} ({types[0]})")
            continue
        if not has_driver:
            note = "  [memory-chip pins in net: lib mistypes I/O as input]" if mem else ""
            undriven.append(f"{label:24s} pins={pins}{note}")
        elif not has_input and not all(t in ("passive",) for t in types):
            unconsumed.append(f"{label:24s} pins={pins}")

    print("\n-- 2. undriven nets (consumed, no driver anywhere) --")
    for u in undriven:
        print("   ", u)
    if not undriven:
        print("    none")

    print("\n-- 3. driven-but-unconsumed nets --")
    for u in unconsumed:
        print("   ", u)
    if not unconsumed:
        print("    none")

    print("\n-- 4. name near-misses (differ only by case/_/~{}) --")
    groups = {}
    for label in merged:
        groups.setdefault(canon(label), []).append(label)
    hit = False
    for c, labels in sorted(groups.items()):
        if len(labels) > 1:
            print("   ", " <-> ".join(sorted(labels)))
            hit = True
    if not hit:
        print("    none")

    print("\n-- 5. single-pin nets (label touches exactly one pin) --")
    for s in singles:
        print("   ", s)
    if not singles:
        print("    none")


if __name__ == "__main__":
    main()
