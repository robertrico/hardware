#!/usr/bin/env python3
"""KiCad .kicad_sch netlist extractor.

Usage: python3 kicad_netlist.py <path/to/schematic.kicad_sch> [grep pattern]

Tokenizes the s-expression, extracts per-unit pin offsets from lib_symbols,
transforms placed-symbol pins to sheet coords (flip Y, mirror, rotate),
splits wires at every touching point, union-finds segments into nets,
attaches label/power-symbol names, and prints a per-pin net table.

Pitfalls: pin-number column is right-aligned ("pin  4" has two spaces —
grep with pin\\s+4\\s); labels can appear twice per net in raw listings
(dedupe); bus vectors are NOT expanded — same-name local labels connect
by name, which is what actually carries a bus within a sheet; power
symbols create the +5V/GND nets; separate wire groups sharing a label
name are the same logical net (merge by name when checking).
"""
import re
import sys
from collections import defaultdict


def tokenize(s):
    tok, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in '()':
            tok.append(c)
            i += 1
        elif c == '"':
            j, buf = i + 1, []
            while j < n:
                if s[j] == '\\' and j + 1 < n:
                    buf.append(s[j + 1])
                    j += 2
                elif s[j] == '"':
                    break
                else:
                    buf.append(s[j])
                    j += 1
            tok.append(('S', ''.join(buf)))
            i = j + 1
        elif c.isspace():
            i += 1
        else:
            j = i
            while j < n and not s[j].isspace() and s[j] not in '()':
                j += 1
            tok.append(('A', s[i:j]))
            i = j
    return tok


def parse(tokens):
    pos = 0

    def walk():
        nonlocal pos
        pos += 1
        out = []
        while tokens[pos] != ')':
            if tokens[pos] == '(':
                out.append(walk())
            else:
                out.append(tokens[pos][1])
                pos += 1
        pos += 1
        return out

    return walk()


def child(n, k):
    return next((c for c in n if isinstance(c, list) and c and c[0] == k), None)


def children(n, k):
    return [c for c in n if isinstance(c, list) and c and c[0] == k]


def transform(px, py, rot, mirror):
    # lib pins are Y-up, sheet is Y-down: flip Y first, then mirror, then rotate.
    x, y = px, -py
    if mirror == 'y':
        x = -x
    elif mirror == 'x':
        y = -y
    r = rot % 360
    if r == 90:
        x, y = y, -x
    elif r == 180:
        x, y = -x, -y
    elif r == 270:
        x, y = -y, x
    return x, y


def on_seg(p, a, b):
    # collinear + within bbox
    return (min(a[0], b[0]) - 1e-3 <= p[0] <= max(a[0], b[0]) + 1e-3 and
            min(a[1], b[1]) - 1e-3 <= p[1] <= max(a[1], b[1]) + 1e-3 and
            abs((b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])) < 1e-3)


def build_report(path):
    root = parse(tokenize(open(path).read()))

    libpins_raw = defaultdict(dict)  # lib_id -> {(unit, num): (name, x, y)} -- dedupes across body styles
    for sym in children(child(root, 'lib_symbols'), 'symbol'):
        lib_id = sym[1]
        for sub in children(sym, 'symbol'):
            m = re.match(re.escape(lib_id.split(':')[-1]) + r'_(\d+)_(\d+)$', sub[1])
            if not m:
                continue
            unit = int(m.group(1))
            for pin in children(sub, 'pin'):
                at = child(pin, 'at')
                num = child(pin, 'number')[1]
                key = (unit, num)
                if key not in libpins_raw[lib_id]:  # first style wins; styles are usually identical or one is empty
                    libpins_raw[lib_id][key] = (child(pin, 'name')[1], float(at[1]), float(at[2]))
    libpins = defaultdict(list)
    for lib_id, pins in libpins_raw.items():
        for (unit, num), (name, x, y) in pins.items():
            libpins[lib_id].append((unit, num, name, x, y))

    pinpts, powernets = [], []
    for s in children(root, 'symbol'):
        lib = child(s, 'lib_id')[1]
        at = child(s, 'at')
        sx, sy, rot = float(at[1]), float(at[2]), float(at[3])
        mir = child(s, 'mirror')
        mirror = mir[1] if mir else None
        unit = int(child(s, 'unit')[1]) if child(s, 'unit') else 1
        ref = next((p[2] for p in children(s, 'property') if p[1] == 'Reference'), '?')
        for (u, num, name, px, py) in libpins.get(lib, []):
            if u not in (0, unit):
                continue
            dx, dy = transform(px, py, rot, mirror)
            pt = (round(sx + dx, 3), round(sy + dy, 3))
            pinpts.append((ref, num, name, pt))
            if lib.startswith('power:'):
                powernets.append((lib.split(':')[1], pt))

    def seg(w):
        xys = children(child(w, 'pts'), 'xy')
        return ((round(float(xys[0][1]), 3), round(float(xys[0][2]), 3)),
                 (round(float(xys[1][1]), 3), round(float(xys[1][2]), 3)))

    wires = [seg(w) for w in children(root, 'wire')]
    # NOTE: bus trunks ((bus ...) segments) are deliberately NOT added here.
    # In KiCad a bus trunk is a routing-only graphic, not a real conductor --
    # treating it as a wire falsely shorts every bit riding that trunk together.
    # Real bus connectivity comes from matching label names (handled below).
    for be in children(root, 'bus_entry'):
        at = child(be, 'at')
        sz = child(be, 'size')
        x0, y0 = float(at[1]), float(at[2])
        wires.append(((round(x0, 3), round(y0, 3)),
                       (round(x0 + float(sz[1]), 3), round(y0 + float(sz[2]), 3))))
    ncs = {(round(float(child(n, 'at')[1]), 3), round(float(child(n, 'at')[2]), 3))
           for n in children(root, 'no_connect')}
    labels = []
    for kind in ('label', 'global_label', 'hierarchical_label'):
        for l in children(root, kind):
            at = child(l, 'at')
            labels.append((l[1], (round(float(at[1]), 3), round(float(at[2]), 3))))

    points = {p for w in wires for p in w} | {p[3] for p in pinpts} | {l[1] for l in labels}
    segs = []
    for a, b in wires:  # split at every touching point
        pts = sorted({a, b} | {p for p in points if p not in (a, b) and on_seg(p, a, b)})
        segs += list(zip(pts, pts[1:]))

    parent = {}

    def find(a):
        parent.setdefault(a, a)
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        parent[find(a)] = find(b)

    for a, b in segs:
        union(a, b)

    # Same-name local labels are the same net in KiCad even with zero wire
    # between them (this project's own convention). Merge groups that share
    # an identical label text -- this is what actually carries a bus/signal
    # across a sheet when there's no unbroken physical wire.
    by_label_name = defaultdict(list)
    for name, pt in labels:
        by_label_name[name].append(pt)
    for name, pts in by_label_name.items():
        for p in pts[1:]:
            union(pts[0], p)

    netname = defaultdict(set)
    for name, pt in labels:
        netname[find(pt)].add(name)
    for name, pt in powernets:
        netname[find(pt)].add(name)
    members = defaultdict(list)
    for ref, num, name, pt in pinpts:
        if not ref.startswith('#'):
            members[find(pt)].append(f"{ref}.{num}({name})")

    lines = []
    for ref, num, name, pt in sorted(pinpts, key=lambda p: (p[0], int(p[1]))):
        if ref.startswith('#'):
            continue
        r = find(pt)
        nn = '/'.join(sorted(netname[r])) or 'N$anon'
        others = sorted(m for m in members[r] if m != f"{ref}.{num}({name})")
        nc = ' [NC]' if pt in ncs else ''
        lines.append(f"{ref:5s} pin {num:>2s} {name:8s} net={nn:20s}{nc} -> {', '.join(others) or '(nothing)'}")
    return lines


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    report = build_report(sys.argv[1])
    pattern = sys.argv[2] if len(sys.argv) > 2 else None
    rx = re.compile(pattern) if pattern else None
    for line in report:
        if rx is None or rx.search(line):
            print(line)
