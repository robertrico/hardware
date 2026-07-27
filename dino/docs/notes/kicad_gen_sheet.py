#!/usr/bin/env python3
"""Declarative .kicad_sch generator: apply a YAML/JSON ops file to a sheet.

Replaces the one-shot MAR-specific generator. You describe WHAT connects
(symbols, per-pin nets, power taps, no-connects); this computes WHERE
(pin-absolute positions via the same placement transform kicad_netlist uses)
and splices valid s-expression blocks into the sheet.

Deterministic: every UUID is uuid5-derived from the sheet name + element
identity, so running the same ops file twice produces byte-identical output
(and re-running on an already-patched sheet is refused by the applied-marker).

Ops file (YAML if PyYAML is installed, JSON always — same shape):

    sheet: dino_v0_0_2/root.kicad_sch      # relative to repo root
    applied_marker: "U61"                  # refuse if this string exists
    donors:                                # lib_id -> sheet to copy lib from
      "74xx:74LS02": dino_v0_0_2/alu.kicad_sch
    symbols:                               # place new symbol units
      - {ref: U61, lib: "74xx:74LS02", value: 74LS02, at: [160, 140], unit: 1}
    connect:                               # attach nets to pins (new OR existing symbols)
      - {pin: U61/2, label: RESET, dir: left}    # stub wire + label
      - {pin: U61/14, power: "+5V"}              # power symbol on pin point
      - {pin: U28/15, nc: true}                  # no_connect marker
    wires:                                 # raw wires (label-pair joins etc.)
      - [[125.73, 49.53], [137.16, 49.53]]
    labels:                                # label at an existing wire point
      - {at: [138.43, 111.76], text: "~{HALT}", dir: left}

dir: left|right|up|down = which way the stub leaves the pin (5.08mm).
Escaping: any double-quote inside generated strings is escaped automatically
(the bug class that bit the MAR session).

ALWAYS verify after running: kicad_netlist.py on the sheet AND a
`kicad-cli sch export netlist` — see dino_session_state.md tooling ledger.
"""
import json
import os
import re
import sys
import uuid
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kicad_netlist as knl

NS = uuid.uuid5(uuid.NAMESPACE_URL, "dino-kicad-gen-sheet")
STUB = 5.08
DIRV = {"left": (-STUB, 0), "right": (STUB, 0), "up": (0, -STUB), "down": (0, STUB)}


def power_value_dy(kind):
    """Value-text offset from a power symbol's pin (sheet Y grows DOWN).
    GND's body hangs below the pin, so its label goes below; every other
    flavor points up, label above — same as KiCad's autoplace. Replaces
    the fixed y-6.35 that stranded GND/+5V labels far from the node."""
    return 3.81 if kind == "GND" else -3.81


def esc(s):
    return s.replace('"', '\\"')


def load_ops(path):
    text = open(path).read()
    try:
        import yaml
        return yaml.safe_load(text)
    except ImportError:
        return json.loads(text)


class Gen:
    def __init__(self, ops_path):
        self.ops = load_ops(ops_path)
        here = os.path.dirname(os.path.abspath(__file__))
        self.repo = os.path.normpath(os.path.join(here, "..", ".."))
        self.sch_path = os.path.join(self.repo, self.ops["sheet"])
        self.sch = open(self.sch_path).read()
        marker = self.ops.get("applied_marker")
        if marker and f'"{marker}"' in self.sch:
            sys.exit(f"REFUSING: {self.ops['sheet']} already contains \"{marker}\".")
        self.uuid_seq = defaultdict(int)
        self.blocks = []
        self.libs_to_add = []
        self.root = knl.parse(knl.tokenize(self.sch))
        self.path_id = self._sheet_path_id()
        self.pwr_n = self._next_pwr()

    def uid(self, *key):
        k = ":".join(map(str, key))
        self.uuid_seq[k] += 1
        return str(uuid.uuid5(NS, f"{self.ops['sheet']}:{k}:{self.uuid_seq[k]}"))

    def _sheet_path_id(self):
        m = re.search(r'\(path "(/[^"]+)"\s*\(reference "', self.sch)
        if not m:
            sys.exit("cannot find an instance path in the sheet")
        return m.group(1)

    def _next_pwr(self):
        ns = [int(m) for f in os.listdir(os.path.dirname(self.sch_path))
              if f.endswith(".kicad_sch")
              for m in re.findall(r'"#PWR0?(\d+)"',
                                  open(os.path.join(os.path.dirname(self.sch_path), f)).read())]
        return max(ns, default=0) + 1

    # ---------- pin geometry ----------
    def _libpins(self, root):
        out = {}
        lp = knl.child(root, "lib_symbols")
        for sym in knl.children(lp, "symbol") if lp else []:
            for sub in knl.children(sym, "symbol"):
                m = re.match(re.escape(sym[1].split(":")[-1]) + r"_(\d+)_(\d+)$", sub[1])
                if not m:
                    continue
                unit = int(m.group(1))
                for pin in knl.children(sub, "pin"):
                    at = knl.child(pin, "at")
                    num = knl.child(pin, "number")[1]
                    out.setdefault(sym[1], {}).setdefault(
                        (unit, num), (float(at[1]), float(at[2])))
        return out

    def pin_pos(self, ref, num):
        """Absolute position of ref/pin — placed symbols in the sheet,
        plus symbols this run is adding."""
        libpins = self._libpins(self.root)
        for lib_id, donor in self.ops.get("donors", {}).items():
            droot = knl.parse(knl.tokenize(open(os.path.join(self.repo, donor)).read()))
            for k, v in self._libpins(droot).items():
                libpins.setdefault(k, v)
        placements = []
        for s in knl.children(self.root, "symbol"):
            r = next((p[2] for p in knl.children(s, "property") if p[1] == "Reference"), "?")
            if r != ref:
                continue
            at = knl.child(s, "at")
            mir = knl.child(s, "mirror")
            unit = int(knl.child(s, "unit")[1]) if knl.child(s, "unit") else 1
            placements.append((knl.child(s, "lib_id")[1], float(at[1]), float(at[2]),
                               float(at[3]), mir[1] if mir else None, unit))
        for spec in self.ops.get("symbols", []):
            if spec["ref"] == ref:
                placements.append((spec["lib"], spec["at"][0], spec["at"][1],
                                   spec.get("rot", 0), None, spec.get("unit", 1)))
        for lib, sx, sy, rot, mir, unit in placements:
            for (u, n), (px, py) in libpins.get(lib, {}).items():
                if n == num and (u in (0, unit)):
                    dx, dy = knl.transform(px, py, rot, mir)
                    return (round(sx + dx, 3), round(sy + dy, 3))
        sys.exit(f"pin {ref}/{num} not found (placed or in symbols:)")

    # ---------- emitters ----------
    def wire(self, a, b, key):
        self.blocks.append(
            f'\t(wire\n\t\t(pts\n\t\t\t(xy {a[0]:g} {a[1]:g}) (xy {b[0]:g} {b[1]:g})\n\t\t)\n'
            f'\t\t(stroke\n\t\t\t(width 0)\n\t\t\t(type default)\n\t\t)\n'
            f'\t\t(uuid "{self.uid("wire", key)}")\n\t)')

    def label(self, text, pt, ddir, key):
        ang, just = (0, "left bottom") if ddir in ("right", "down") else (180, "right bottom")
        self.blocks.append(
            f'\t(label "{esc(text)}"\n\t\t(at {pt[0]:g} {pt[1]:g} {ang})\n'
            f'\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n'
            f'\t\t\t(justify {just})\n\t\t)\n\t\t(uuid "{self.uid("label", key)}")\n\t)')

    def no_connect(self, pt, key):
        self.blocks.append(
            f'\t(no_connect\n\t\t(at {pt[0]:g} {pt[1]:g})\n'
            f'\t\t(uuid "{self.uid("nc", key)}")\n\t)')

    def _prop(self, name, val, x, y, hide=False):
        h = "\n\t\t\t(hide yes)" if hide else ""
        return (f'\t\t(property "{name}" "{esc(val)}"\n\t\t\t(at {x:g} {y:g} 0){h}\n'
                f'\t\t\t(show_name no)\n\t\t\t(do_not_autoplace no)\n'
                f'\t\t\t(effects\n\t\t\t\t(font\n\t\t\t\t\t(size 1.27 1.27)\n\t\t\t\t)\n\t\t\t)\n\t\t)')

    def symbol(self, lib, ref, value, desc, x, y, unit, pins, extra=(),
               value_dy=-6.35):
        pb = "\n".join(
            f'\t\t(pin "{p}"\n\t\t\t(uuid "{self.uid("pin", ref, unit, p)}")\n\t\t)'
            for p in pins)
        props = [self._prop("Reference", ref, x, y - 8.89, hide=ref.startswith("#")),
                 self._prop("Value", value, x, y + value_dy),
                 self._prop("Footprint", "", x, y, hide=True),
                 self._prop("Datasheet", "", x, y, hide=True),
                 self._prop("Description", desc, x, y, hide=True)]
        self.blocks.append(
            f'\t(symbol\n\t\t(lib_id "{lib}")\n\t\t(at {x:g} {y:g} 0)\n\t\t(unit {unit})\n'
            f'\t\t(body_style 1)\n\t\t(exclude_from_sim no)\n\t\t(in_bom yes)\n'
            f'\t\t(on_board yes)\n\t\t(in_pos_files yes)\n\t\t(dnp no)\n'
            f'\t\t(fields_autoplaced yes)\n\t\t(uuid "{self.uid("sym", ref, unit)}")\n'
            + "\n".join(props) + "\n" + pb + "\n"
            f'\t\t(instances\n\t\t\t(project "dino_v0_0_2"\n\t\t\t\t(path "{self.path_id}"\n'
            f'\t\t\t\t\t(reference "{ref}")\n\t\t\t\t\t(unit {unit})\n'
            f'\t\t\t\t)\n\t\t\t)\n\t\t)\n\t)')

    def power(self, kind, pt):
        ref = f"#PWR0{self.pwr_n}"
        self.pwr_n += 1
        desc = (f'Power symbol creates a global label with name "{kind}"'
                + (" , ground" if kind == "GND" else ""))
        self.symbol(f"power:{kind}", ref, kind, desc, pt[0], pt[1], 1, ["1"],
                    value_dy=power_value_dy(kind))

    # ---------- lib transplant ----------
    def ensure_lib(self, lib_id):
        if f'(symbol "{lib_id}"' in self.sch:
            return
        donor = self.ops.get("donors", {}).get(lib_id)
        if not donor:
            sys.exit(f"lib {lib_id} not in sheet and no donor given")
        d = open(os.path.join(self.repo, donor)).read()
        start = d.index(f'\n\t\t(symbol "{lib_id}"') + 1
        nxt = d.index('\n\t\t(symbol "', start)  # newline-anchored: skips 3-tab sub-symbols
        block = d[start:nxt].rstrip("\n")
        assert block.count("(") == block.count(")"), f"unbalanced lib block for {lib_id}"
        anchor = re.search(r"\t\(lib_symbols\n", self.sch).end()
        self.sch = self.sch[:anchor] + block + "\n" + self.sch[anchor:]

    # ---------- pin numbering helpers ----------
    def unit_pins(self, lib, unit):
        libpins = self._libpins(knl.parse(knl.tokenize(self.sch)))
        if lib not in libpins:
            for lid, donor in self.ops.get("donors", {}).items():
                if lid == lib:
                    droot = knl.parse(knl.tokenize(open(os.path.join(self.repo, donor)).read()))
                    libpins.update(self._libpins(droot))
        return sorted(n for (u, n) in libpins[lib] if u == unit)

    # ---------- collision detection ----------
    def _sheet_geometry(self):
        """Existing conductors: wire segments, pin points, label points."""
        segs, pts = [], set()
        for w in knl.children(self.root, "wire"):
            xys = knl.children(knl.child(w, "pts"), "xy")
            a = (round(float(xys[0][1]), 3), round(float(xys[0][2]), 3))
            b = (round(float(xys[1][1]), 3), round(float(xys[1][2]), 3))
            segs.append((a, b))
            pts.update((a, b))
        for kind in ("label", "global_label", "hierarchical_label"):
            for l in knl.children(self.root, kind):
                at = knl.child(l, "at")
                pts.add((round(float(at[1]), 3), round(float(at[2]), 3)))
        libpins = self._libpins(self.root)
        for s in knl.children(self.root, "symbol"):
            lib = knl.child(s, "lib_id")[1]
            at = knl.child(s, "at")
            mir = knl.child(s, "mirror")
            unit = int(knl.child(s, "unit")[1]) if knl.child(s, "unit") else 1
            for (uu, n), (px, py) in libpins.get(lib, {}).items():
                if uu in (0, unit):
                    dx, dy = knl.transform(px, py, float(at[3]), mir[1] if mir else None)
                    pts.add((round(float(at[1]) + dx, 3), round(float(at[2]) + dy, 3)))
        return segs, pts

    def check_collisions(self, new_points, allowed):
        """new_points: points this run creates that must NOT touch existing
        conductors. allowed: points where touching is intended (target pins)."""
        segs, pts = self._sheet_geometry()
        bad = []
        for p, why in new_points:
            if p in allowed:
                continue
            if p in pts:
                bad.append(f"{why} at {p}: lands on existing pin/label/wire-end")
                continue
            for a, b in segs:
                if p not in (a, b) and knl.on_seg(p, a, b):
                    bad.append(f"{why} at {p}: lands on existing wire {a}-{b}")
                    break
        if bad:
            sys.exit("COLLISIONS (nothing written):\n  " + "\n  ".join(bad))

    # ---------- run ----------
    def run(self):
        # pass 1: compute all geometry, collision-check before touching anything
        new_points, allowed = [], set()
        for s in self.ops.get("symbols", []):
            unit = s.get("unit", 1)
            for num in self.unit_pins(s["lib"], unit):
                p = self.pin_pos(s["ref"], num)
                new_points.append((p, f'{s["ref"]}/{num}'))
        planned = []
        for c in self.ops.get("connect", []):
            ref, num = c["pin"].split("/")
            pt = self.pin_pos(ref, num)
            allowed.add(pt)  # touching the target pin is the point
            if "label" in c:
                d = c.get("dir", "left")
                dx, dy = DIRV[d]
                q = (round(pt[0] + dx, 3), round(pt[1] + dy, 3))
                new_points.append((q, f'{c["pin"]} stub end "{c["label"]}"'))
                planned.append(("stub", c, pt, q, d))
            else:
                planned.append(("point", c, pt, None, None))
        for l in self.ops.get("labels", []):
            allowed.add(tuple(l["at"]))  # attaching to existing geometry is the point
        self.check_collisions(new_points, allowed)

        # pass 2: emit
        for lib in {s["lib"] for s in self.ops.get("symbols", [])}:
            self.ensure_lib(lib)
        for s in self.ops.get("symbols", []):
            unit = s.get("unit", 1)
            self.symbol(s["lib"], s["ref"], s.get("value", s["lib"].split(":")[-1]),
                        s.get("desc", ""), s["at"][0], s["at"][1], unit,
                        self.unit_pins(s["lib"], unit))
        for kind, c, pt, q, d in planned:
            if c.get("nc"):
                self.no_connect(pt, c["pin"])
            elif "power" in c:
                self.power(c["power"], pt)
            elif "label" in c:
                self.wire(pt, q, c["pin"])
                self.label(c["label"], q, d, c["pin"])
        for i, (a, b) in enumerate(self.ops.get("wires", [])):
            self.wire(tuple(a), tuple(b), f"raw{i}")
        for l in self.ops.get("labels", []):
            self.label(l["text"], tuple(l["at"]), l.get("dir", "left"), f'lbl:{l["text"]}:{l["at"]}')

        out = self.sch.rstrip()
        assert out.endswith(")")
        out = out[:-1] + "\n".join(self.blocks) + "\n)\n"
        open(self.sch_path, "w").write(out)
        print(f"applied {len(self.blocks)} blocks to {self.ops['sheet']}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    Gen(sys.argv[1]).run()
