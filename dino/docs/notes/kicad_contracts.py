#!/usr/bin/env python3
"""Per-sheet I/O contracts: derive each module's boundary signals and stamp
them onto the physical sheets.

For every sheet in the hierarchy, lists the signals that CROSS its boundary:
  IN    — consumed here, driven on another sheet (shows the driving sheet)
  OUT   — driven here, consumed on other sheets (shows the consuming sheets)
  BIDIR — both (shared buses like W)
Direction comes from netlist pin types (output/power_out = drives,
tri_state = drives-when-enabled, input = consumes). Power nets (+5V/GND) and
sheet-internal nets are excluded — the contract is exactly what a bench rig
(MCU, logic analyzer) must supply and observe to test the board alone.

Usage:
  python3 kicad_contracts.py            # print contracts + write markdown
  python3 kicad_contracts.py --stamp    # also place/refresh a text block on
                                        # each .kicad_sch (idempotent: any
                                        # previous MODULE CONTRACT block is
                                        # replaced)

Markdown lands in docs/notes/dino_sheet_contracts.md.
"""
import os
import re
import sys
import uuid
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kicad_xsheet_audit as kxa

MARK = "MODULE CONTRACT"
NS = uuid.uuid5(uuid.NAMESPACE_URL, "dino-kicad-contracts")


def sheet_name_map(root_path):
    """netlist sheet path ('/Memory/') -> .kicad_sch file, plus '/' -> root."""
    text = open(root_path).read()
    d = os.path.dirname(root_path)
    out = {"/": root_path}
    for m in re.finditer(
            r'\(property "Sheetname" "([^"]+)"[\s\S]*?\(property "Sheetfile" "([^"]+)"',
            text):
        out["/" + m.group(1) + "/"] = os.path.join(d, m.group(2))
    return out


def compress(names):
    """['W0'..'W7','CLK'] -> ['W0-7','CLK'] (numeric runs collapsed)."""
    groups = defaultdict(list)
    plain = []
    for n in sorted(set(names)):
        m = re.match(r"^(.*?)(\d+)$", n)
        if m:
            groups[m.group(1)].append(int(m.group(2)))
        else:
            plain.append(n)
    out = []
    for base, nums in groups.items():
        nums.sort()
        runs, s = [], nums[0]
        for a, b in zip(nums, nums[1:] + [None]):
            if b != a + 1:
                runs.append(f"{base}{s}" if s == a else f"{base}{s}-{a}")
                s = b
        out.extend(runs)
    return sorted(out + plain)


def parse_with_pinfunction(netfile):
    text = open(netfile).read()
    values = dict(re.findall(
        r'\(comp\s*\(ref "([^"]+)"\)\s*\(value "([^"]+)"\)', text))
    nets = []
    body = text[text.index("(nets"):]
    for chunk in re.split(r"\(net\n", body)[1:]:
        name = re.search(r'\(name "([^"]+)"\)', chunk).group(1)
        nodes = re.findall(
            r'\(ref "([^"]+)"\)\s*\(pin "([^"]+)"\)\s*(?:\(pinfunction "([^"]*)"\)\s*)?\(pintype "([^"]+)"\)',
            chunk)
        nets.append((name, nodes))
    return values, nets


def build_contracts(root_path):
    netfile = kxa.export_netlist(root_path)
    values, nets = parse_with_pinfunction(netfile)
    os.unlink(netfile)

    alias_rep, alias_note = {}, {}
    for sf in kxa.sheet_files(root_path):
        for group in kxa.label_alias_groups(sf):
            rep = min(group)
            for g in group:
                rep = alias_rep.get(g, rep)
            for g in group:
                alias_rep[g] = rep
            alias_note[rep] = "=".join(sorted(group))

    # merged[label] = {sheetpath: set((ref, pintype))}
    merged = defaultdict(lambda: defaultdict(set))
    for name, nodes in nets:
        if name.startswith(("unconnected-", "Net-(")):
            continue
        label = kxa.leaf(name)
        label = alias_note.get(alias_rep.get(label, label), label)
        if label in ("+5V", "GND"):
            continue
        sheet = name.rsplit("/", 1)[0] + "/" if "/" in name else "/"
        for r, _p, fn, t in nodes:
            merged[label][sheet].add((r, fn or "", t.split("+")[0]))

    DRV = {"output", "power_out"}

    def is_mem_data(ref, fn):
        # EEPROM/RAM I/O pins are mistyped 'input' in the 74xx lib; only the
        # DATA pins can drive — address/CE/OE/WE really are inputs.
        return (kxa.MEMORY_REFS_HINT.search(values.get(ref, ""))
                and re.match(r"(D|DQ|I/?O)\d*(_\d+)?$", fn))

    contracts = defaultdict(lambda: {"IN": [], "OUT": [], "BIDIR": []})
    for label, sheets in merged.items():
        if len(sheets) < 2:
            continue  # sheet-internal
        hard_on = {s for s, rft in sheets.items()
                   if any(t in DRV for _, _, t in rft)}
        tri_on = {s for s, rft in sheets.items()
                  if any(t == "tri_state" for _, _, t in rft)}
        mem_on = {s for s, rft in sheets.items()
                  if any(is_mem_data(r, fn) for r, fn, _ in rft)}
        for s, rft in sheets.items():
            has_in = any(t == "input" and not is_mem_data(r, fn)
                         for r, fn, t in rft)
            others = set(sheets) - {s}
            if s in hard_on:
                contracts[s]["OUT"].append((label, others))
            elif s in tri_on and has_in:
                contracts[s]["BIDIR"].append((label, others))
            elif s in tri_on:
                contracts[s]["OUT"].append((label, others))
            elif s in mem_on:
                # RAM data pins are true bidir; EEPROM data with no other
                # driver anywhere is the plain source
                kind = "BIDIR" if (hard_on | tri_on) else "OUT"
                contracts[s][kind].append((label, others))
            else:
                contracts[s]["IN"].append(
                    (label, (hard_on | tri_on | mem_on) - {s}))
    return contracts


def short(sheetpath):
    return sheetpath.strip("/") or "root"


def render(contracts):
    lines = ["# DINO sheet-to-sheet contracts",
             "",
             "Generated by docs/notes/kicad_contracts.py — regenerate after any",
             "schematic change; do not hand-edit. Direction is derived from pin",
             "types: OUT(tri) means drives-when-enabled (a tri-state bus driver).",
             ""]
    for sheet in sorted(contracts):
        c = contracts[sheet]
        lines.append(f"## {short(sheet)}")
        for kind in ("IN", "OUT", "BIDIR"):
            if not c[kind]:
                continue
            bysrc = defaultdict(list)
            for label, others in c[kind]:
                bysrc[", ".join(sorted(short(o) for o in others))].append(label)
            for src, labels in sorted(bysrc.items()):
                arrow = {"IN": "<-", "OUT": "->", "BIDIR": "<->"}[kind]
                lines.append(f"- {kind:5s} {', '.join(compress(labels))}  {arrow} {src}")
        lines.append("")
    return "\n".join(lines)


def stamp(contracts, root_path):
    names = sheet_name_map(root_path)
    for sheetpath, sch_file in names.items():
        c = contracts.get(sheetpath)
        if not c:
            continue
        rows = [f"{MARK} — generated, do not hand-edit (kicad_contracts.py --stamp)"]
        for kind in ("IN", "OUT", "BIDIR"):
            if not c[kind]:
                continue
            bysrc = defaultdict(list)
            for label, others in c[kind]:
                bysrc[", ".join(sorted(short(o) for o in others))].append(label)
            for src, labels in sorted(bysrc.items()):
                arrow = {"IN": "<-", "OUT": "->", "BIDIR": "<->"}[kind]
                rows.append(f"{kind}: {', '.join(compress(labels))} {arrow} {src}")
        body = "\\n".join(r.replace('"', '\\"') for r in rows)

        t = open(sch_file).read()
        # remove any previous stamped block (idempotent regeneration)
        t = re.sub(r'\t\(text "' + re.escape(MARK) + r'[\s\S]*?\n\t\)\n', "", t)
        # place below existing content, left margin
        ys = [float(m.group(2)) for m in re.finditer(r"\(xy ([\d.]+) ([\d.]+)\)", t)]
        ys += [float(m.group(2)) for m in re.finditer(r"\(at ([\d.]+) ([\d.]+)", t)]
        y = min(round(max(ys) + 10, 2), 280.0)
        uid = uuid.uuid5(NS, sch_file)
        block = (f'\t(text "{body}"\n'
                 f'\t\t(exclude_from_sim no)\n'
                 f'\t\t(at 15.24 {y:g} 0)\n'
                 f'\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n'
                 f'\t\t\t(justify left bottom)\n\t\t)\n'
                 f'\t\t(uuid "{uid}")\n\t)')
        t = t.rstrip()
        assert t.endswith(")")
        t = t[:-1] + block + "\n)\n"
        open(sch_file, "w").write(t)
        print(f"stamped {os.path.basename(sch_file)} ({len(rows)-1} contract lines)")


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.normpath(os.path.join(here, "..", "..",
                                         "dino_v0_0_2", "dino_v0_0_2.kicad_sch"))
    contracts = build_contracts(root)
    md = render(contracts)
    out = os.path.join(here, "dino_sheet_contracts.md")
    open(out, "w").write(md + "\n")
    print(md)
    print(f"[written to {out}]")
    if "--stamp" in sys.argv:
        stamp(contracts, root)
