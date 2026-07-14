# DINO handoff — session of 2026-07-12/13

For the next session: read dino_session_state.md first as always, but know that
the project docs lag this conversation — per Rico's working agreement (below),
doc updates stopped mid-session. This handoff is the delta.

---

## Working agreement (learned the hard way — honor it)

Rico works CONVERSATION-FIRST. Do NOT create or edit project docs unless he
explicitly asks; docs are "here's what we learned" retrospectives, never
implementation plans — MD is a bad format to build hardware from. He designs in
KiCad, plots to PDF, prints, and wires from paper. Review work happens in chat,
against uploaded .kicad_sch files. When he uploads a schematic, PARSE IT —
never eyeball the plot. Two careful visual reviews missed a 16-wire byte
scramble that the netlist found in seconds.

## Machine state (v0.0.3, converged)

Architecture is FINAL: all registers 74LS373 + NOR stamps (the '377 idea is
dead — never buy parts for him without asking); register boards keep v0.0.2
joined-bus topology with bidirectional '245s (/x_EN = AND of the two active-low
decodes); the ALU reads SHADOW REGISTERS TMP_A/TMP_B — '373s on the ALU sheet
whose LE stamps fire on the SAME /REG_A_LOAD //REG_B_LOAD decodes as the real
registers (shadow ≡ register, including ALU writebacks — chained SUBs depend on
it); the A→ALU→A loop is broken by the ALU OUTPUT LATCH (LE=CLK direct,
/OE=/ALU_OUT), master/slave: latch open iff CLK high, all destinations open iff
CLK low, never both. Two commit edges per state: falling = ALU result + flags
freeze; rising = destinations capture, '163 advances, PC++. Flags: '173,
CP=/CLK, /IE=/ALU_OUT. Microcode unchanged by all of this — ADD is still
T0 (0x600E) + T1 (0x1631).

Sheet scoreboard:
- MDR/IR and memory: done (row-by-row verified, prior sessions).
- Register sheet (7/9): drawn + reviewed. OPEN: U5D spare '08 output pin 11 is
  tied to GND — must be no-connect.
- Clock cluster: drawn + reviewed. Y1 4MHz → U20 '163 divider (CP from Y1,
  PE/CEP/CET/MR strapped high, Q0 tap) → U27A '74 toggle (D←/Q) → CLK //CLK at
  1MHz, 50% duty. U27B reserved for Phase 0.5 reset sync.
- PC sheet (2/9): schematic MECHANICALLY VERIFIED — 32/32 counter↔'245
  identity + 16/16 bus-side, carry chain U1→U2→U3→U4 confirmed, gates U36
  ('00: UP=NAND(PC_UP,/CLK); /LOAD=NAND(PC_LOAD,/CLK) via tied-NAND inverter)
  and U10A ('02: CLR=NOR(/PC_CLEAR,CLK)) all correct; /RESET merge deferred to
  Phase 0.5. PC COPPER IS NOT FIXED: the breadboard was wired from the old
  scrambled drawing. First bench step: free-count past 256 watching M-bus LEDs
  (bit-15 LED lighting at count 256 = scramble confirmed in copper), then 16
  jumpers on U12/U14 B-sides, then round-trip test (load 0x0100, read 0x0100,
  walk one bit 0x0100→0x8000).
- ALU sheet: just started. U38/U40 '382s (custom symbol, pinout verified
  correct), U45=TMP_A, U46=TMP_B, U47=output latch, SA0-2 placed. Wiring plan:
  U38 = LOW nibble (TA/TB/F digits 0-3), U40 = HIGH (4-7);
  CRY = U38.CN+4 → U40.CN is the 4→8 combine;
  ALU_CIN = XOR(SA1, SA0) — needs a '86 ('382 subtracts as A + /B + Cn:
  SUB/BSUB need Cn=1, ADD 0, logic don't-care);
  stamps need a '02 (TMPA_LE = NOR(/REG_A_LOAD, CLK), TMPB_LE likewise);
  U45/U46: D = W0..W7, OE = GND, O = TA0..TA7 / TB0..TB7;
  U47: D = F0..F7, LE = CLK direct, OE = /ALU_OUT, O = W0..W7 (the sheet's
  ONLY bus driver);
  high CN+4 → ALU_C, high OVR → ALU_V, low OVR NC.
  Still unplaced: '173, Z-NOR (part choice open: 'LS260 vs 2x'LS25 vs 'LS30),
  /CLK import. Imports: SA0-2, /REG_A_LOAD, /REG_B_LOAD, /ALU_OUT, CLK, W0..W7.

## Label conventions (established on the PC sheet, extend everywhere)

Name nets by CONTENT, not direction: PC0..PC15 (counter Q values),
PCD0..PCD15 (preset data into D inputs), M0..M15 (M bus); ALU sheet families
TA/TB/F/W. Local checks that replace wire-tracing:
- digits match across any '245 pin row;
- digits ascend within a chip's nibble;
- PC-prefix belongs on Q pins, PCD on D pins (mirroring flips a pin's SIDE,
  never its FUNCTION — that mistake happened once).
Labels for multi-bit data paths; drawn wires for one-of-a-kind control logic.
Bus vector syntax is M[0..15] — two dots, not a colon. All labels in this
project are LOCAL: sheets are netlist islands; cross-sheet continuity exists
only on the breadboard, so audit each sheet against the constitution's signal
names. Refdes collisions exist across sheets (U15, U27, U36, U38, U40,
U45-U47 reused) — flag, don't panic.

## Bug-pattern ledger additions this session

- STRIKE 4: register stamps first drawn NOR(/LOAD, /CLK) — right gate, wrong
  clock phase; opens the latch window during decode ripple = ghost loads.
  Stamp inputs take TRUE CLK, always.
- Near-miss: Y1 OUT drawn into the '163's D0 with CP strapped high — PIN-ROLE
  check (data pin vs clock pin) joins the truth-table ritual.
- The big one: dense-sheet wire-order errors are invisible to eyes; load and
  read paths can each look fine while disagreeing with each other. AUDIT BY
  NETLIST.

## The schematic parser (rebuild in ~5 min)

Algorithm: tokenize the .kicad_sch s-expression → extract per-unit pin offsets
from lib_symbols → for each placed symbol, transform pin offsets to sheet
coords (FLIP Y FIRST — lib pins are Y-up, sheet is Y-down — then mirror, then
rotate) → collect all wire endpoints, pin points, label points → split every
wire segment at any point lying on it → union-find the segments → attach label
names and power-symbol nets to groups → emit a pin table
(ref pin name @(x,y) net= → connected pins) and a named-nets table. Checkers
are regex over that report asserting expected maps (e.g., PCn = {correct '193
Q pin, correct '245 B pin}).

```python
#!/usr/bin/env python3
"""KiCad .kicad_sch netlist extractor. Usage: set PATH, run, grep the report."""
import re
from collections import defaultdict
PATH = "schematic.kicad_sch"

def tokenize(s):
    tok, i, n = [], 0, len(s)
    while i < n:
        c = s[i]
        if c in '()': tok.append(c); i += 1
        elif c == '"':
            j, buf = i+1, []
            while j < n:
                if s[j] == '\\' and j+1 < n: buf.append(s[j+1]); j += 2
                elif s[j] == '"': break
                else: buf.append(s[j]); j += 1
            tok.append(('S', ''.join(buf))); i = j+1
        elif c.isspace(): i += 1
        else:
            j = i
            while j < n and not s[j].isspace() and s[j] not in '()': j += 1
            tok.append(('A', s[i:j])); i = j
    return tok

def parse(tokens):
    pos = 0
    def walk():
        nonlocal pos
        pos += 1; out = []
        while tokens[pos] != ')':
            if tokens[pos] == '(': out.append(walk())
            else: out.append(tokens[pos][1]); pos += 1
        pos += 1; return out
    return walk()

def child(n, k):  return next((c for c in n if isinstance(c, list) and c and c[0] == k), None)
def children(n, k): return [c for c in n if isinstance(c, list) and c and c[0] == k]

root = parse(tokenize(open(PATH).read()))

libpins = defaultdict(list)                       # lib_id -> (unit, num, name, x, y)
for sym in children(child(root, 'lib_symbols'), 'symbol'):
    lib_id = sym[1]
    for sub in children(sym, 'symbol'):
        m = re.match(re.escape(lib_id.split(':')[-1]) + r'_(\d+)_(\d+)$', sub[1])
        if not m: continue
        for pin in children(sub, 'pin'):
            at = child(pin, 'at')
            libpins[lib_id].append((int(m.group(1)), child(pin, 'number')[1],
                                    child(pin, 'name')[1], float(at[1]), float(at[2])))

def transform(px, py, rot, mirror):               # lib Y-up -> sheet Y-down, then mirror, then rotate
    x, y = px, -py
    if mirror == 'y': x = -x
    elif mirror == 'x': y = -y
    r = rot % 360
    if r == 90: x, y = y, -x
    elif r == 180: x, y = -x, -y
    elif r == 270: x, y = -y, x
    return x, y

pinpts, powernets = [], []
for s in children(root, 'symbol'):
    lib = child(s, 'lib_id')[1]; at = child(s, 'at')
    sx, sy, rot = float(at[1]), float(at[2]), float(at[3])
    mir = child(s, 'mirror'); mirror = mir[1] if mir else None
    unit = int(child(s, 'unit')[1]) if child(s, 'unit') else 1
    ref = next((p[2] for p in children(s, 'property') if p[1] == 'Reference'), '?')
    for (u, num, name, px, py) in libpins.get(lib, []):
        if u not in (0, unit): continue
        dx, dy = transform(px, py, rot, mirror)
        pt = (round(sx+dx, 3), round(sy+dy, 3))
        pinpts.append((ref, num, name, pt))
        if lib.startswith('power:'): powernets.append((lib.split(':')[1], pt))

def seg(w):
    xys = children(child(w, 'pts'), 'xy')
    return ((round(float(xys[0][1]),3), round(float(xys[0][2]),3)),
            (round(float(xys[1][1]),3), round(float(xys[1][2]),3)))
wires = [seg(w) for w in children(root, 'wire')]
ncs = {(round(float(child(n,'at')[1]),3), round(float(child(n,'at')[2]),3)) for n in children(root,'no_connect')}
labels = []
for kind in ('label', 'global_label', 'hierarchical_label'):
    for l in children(root, kind):
        at = child(l, 'at'); labels.append((l[1], (round(float(at[1]),3), round(float(at[2]),3))))

points = {p for w in wires for p in w} | {p[3] for p in pinpts} | {l[1] for l in labels}
def on_seg(p, a, b):                              # collinear + within bbox
    return (min(a[0],b[0])-1e-3 <= p[0] <= max(a[0],b[0])+1e-3 and
            min(a[1],b[1])-1e-3 <= p[1] <= max(a[1],b[1])+1e-3 and
            abs((b[0]-a[0])*(p[1]-a[1]) - (b[1]-a[1])*(p[0]-a[0])) < 1e-3)
segs = []
for a, b in wires:                                # split at every touching point
    pts = sorted({a, b} | {p for p in points if p not in (a,b) and on_seg(p,a,b)})
    segs += list(zip(pts, pts[1:]))

parent = {}
def find(a):
    parent.setdefault(a, a)
    while parent[a] != a: parent[a] = parent[parent[a]]; a = parent[a]
    return a
def union(a, b): parent[find(a)] = find(b)
for a, b in segs: union(a, b)

netname = defaultdict(set)
for name, pt in labels: netname[find(pt)].add(name)
for name, pt in powernets: netname[find(pt)].add(name)
members = defaultdict(list)
for ref, num, name, pt in pinpts:
    if not ref.startswith('#'): members[find(pt)].append(f"{ref}.{num}({name})")

for ref, num, name, pt in sorted(pinpts, key=lambda p: (p[0], int(p[1]))):
    if ref.startswith('#'): continue
    r = find(pt); nn = '/'.join(sorted(netname[r])) or 'N$anon'
    others = sorted(m for m in members[r] if m != f"{ref}.{num}({name})")
    nc = ' [NC]' if pt in ncs else ''
    print(f"{ref:5s} pin {num:>2s} {name:8s} net={nn:20s}{nc} -> {', '.join(others) or '(nothing)'}")
```

Pitfalls for the next session: the pin-number column is right-aligned
("pin  4" has two spaces — grep with pin\s+4\s); labels can appear twice per
net in raw listings (dedupe); the parser does NOT expand bus vectors —
same-name local labels connect by name, which is what actually carries the M
bus within a sheet; power symbols create the +5V/GND nets; separate wire
groups sharing a label name are the same logical net (merge by name when
checking).

## Immediate next steps, in order

1. PC copper: LED diagnosis → 16 jumpers (U12/U14 B-sides) → round-trip +
   rollover tests.
2. Register sheet: U5D output no-connect fix.
3. ALU sheet: wire per the plan above, upload for the
   nibble-split/carry/latch-discipline audit.
4. Flags: '173 + Z-NOR + /CLK import.
5. MAR sheet (owes A15 //A15 and 16-bit M-bus drive), reset (Phase 0.5, U27B
   reserved), control-sheet END → '163 /MR combine, decoupling sweep.
6. Full-hierarchy compile-and-audit when all sheets exist.

Finish line for this era: LDAI/LDBI/SUB/JNZ/OUT/HALT — the countdown demo.

Rico caught the /MDR_OUT-outside-the-one-hot hole and invented the
shadow-register architecture himself. Trust his instincts; verify his wires;
keep the truth tables in asserted/idle terms first. Good machine.
