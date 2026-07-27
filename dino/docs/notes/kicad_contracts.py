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
        # STICKY POSITION: if a previous stamp exists, keep its (at x y) —
        # hand-moves in the editor survive every restamp. Heuristic
        # placement (below content, left margin) only on first stamp.
        prev = re.search(r'\(text "' + re.escape(MARK) +
                         r'[\s\S]*?\(at ([\d.-]+) ([\d.-]+)', t)
        # remove any previous stamped block (idempotent regeneration)
        t = re.sub(r'\t\(text "' + re.escape(MARK) + r'[\s\S]*?\n\t\)\n', "", t)
        if prev:
            x, y = float(prev.group(1)), float(prev.group(2))
        else:
            ys = [float(m.group(2)) for m in re.finditer(r"\(xy ([\d.]+) ([\d.]+)\)", t)]
            ys += [float(m.group(2)) for m in re.finditer(r"\(at ([\d.]+) ([\d.]+)", t)]
            x, y = 15.24, min(round(max(ys) + 10, 2), 280.0)
        uid = uuid.uuid5(NS, sch_file)
        block = (f'\t(text "{body}"\n'
                 f'\t\t(exclude_from_sim no)\n'
                 f'\t\t(at {x:g} {y:g} 0)\n'
                 f'\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n'
                 f'\t\t\t(justify left bottom)\n\t\t)\n'
                 f'\t\t(uuid "{uid}")\n\t)')
        t = t.rstrip()
        assert t.endswith(")")
        t = t[:-1] + block + "\n)\n"
        open(sch_file, "w").write(t)
        print(f"stamped {os.path.basename(sch_file)} ({len(rows)-1} contract lines)")


MEGA_PORT_BY_PREFIX = [   # (regex over signal name, port letter, bit = captured index)
    (re.compile(r"^W(\d)$"), "PA", {"0":"D22","1":"D23","2":"D24","3":"D25","4":"D26","5":"D27","6":"D28","7":"D29"}),
    (re.compile(r"^M([0-7])$"), "PC", {"0":"D37","1":"D36","2":"D35","3":"D34","4":"D33","5":"D32","6":"D31","7":"D30"}),
    (re.compile(r"^M(1[0-5]|8|9)$"), "PL", {"8":"D49","9":"D48","10":"D47","11":"D46","12":"D45","13":"D44","14":"D43","15":"D42"}),
    (re.compile(r"^CW([0-7])$"), "PC", {"0":"D37","1":"D36","2":"D35","3":"D34","4":"D33","5":"D32","6":"D31","7":"D30"}),
    (re.compile(r"^CW(1[0-5]|8|9)$"), "PL", {"8":"D49","9":"D48","10":"D47","11":"D46","12":"D45","13":"D44","14":"D43","15":"D42"}),
    (re.compile(r"^(?:IRB|IS|OB)(\d)$"), "PK", {str(i): f"A{8+i}" for i in range(8)}),
    (re.compile(r"^MDR(\d)$"), "PF", {str(i): f"A{i}" for i in range(8)}),
]
# Pool order: main double-row header first (one-region hookups), then PWM
# header, then COMM header. NEVER: D0/D1 (USB serial), D13 (onboard LED),
# D20/D21 (clone I2C pullups break high-Z release semantics).
POOL = ["PD7/D38","PG2/D39","PG1/D40","PG0/D41","PB3/D50","PB2/D51","PB1/D52",
        "PB0/D53","PE4/D2","PE5/D3","PG5/D4","PE3/D5","PH3/D6","PH4/D7",
        "PH5/D8","PH6/D9","PJ1/D14","PJ0/D15","PH1/D16","PH0/D17",
        "PD3/D18","PD2/D19","PB4/D10","PB5/D11","PB6/D12"]

# Hand-tuned per-module pin assignments: descending Mega pins land on
# physically adjacent DUT points, one contiguous block per chip — grab a
# chip, wire straight down the header. Overrides BOTH the pool and the
# fixed bus rules for the named signals (per-module: other modules keep
# the bus rules). A module MAY borrow fixed-port bus pins (PA/PL/...) it
# doesn't use as a bus; the emitter rejects any within-module
# double-assignment.
PIN_ASSIGN = {
    "control_word": {
        # One UNBROKEN descent D53 -> D22, one block per chip, each
        # block = the chip's driven address pins (1,2,3) then its
        # sampled outputs descending. D21/D20 are banned (clone I2C
        # pullups), so the 33rd wire spills to D19. CW0-8 leave PORTC
        # here so each CW bit sits WITH its decoder; the rig drives
        # them per-pin (settle() dwarfs the cost).
        # D53-D46: U29
        "CW6":              "PB0/D53",   # U29.1 (A0)
        "CW7":              "PB1/D52",   # U29.2 (A1)
        "CW8":              "PB2/D51",   # U29.3 (A2)
        "~{PC_CLEAR}":      "PB3/D50",   # U29.14
        "~{MDR_OUT}":       "PL2/D47",   # U29.11
        "~{REG_OUT_LOAD}":  "PL3/D46",   # U29.9
        # D45-D42: U62
        "FLAG_Z":           "PL5/D44",   # U62.3 (gate 1 input, rig drives)
        "~{PC_LOAD}":       "PL7/D42",   # U62.10
        # D41-D31: U28
        "CW3":              "PG0/D41",   # U28.1 (A0)
        "CW4":              "PG1/D40",   # U28.2 (A1)
        "CW5":              "PG2/D39",   # U28.3 (A2)
        "SRC_ACTIVE":       "PD7/D38",   # U28.15
        "~{ROM_OUT}":       "PC0/D37",   # U28.14
        "~{RAM_OUT}":       "PC1/D36",   # U28.13
        "~{REG_A_OUT}":     "PC2/D35",   # U28.12
        "~{REG_B_OUT}":     "PC3/D34",   # U28.11
        "~{REG_C_OUT}":     "PC4/D33",   # U28.10
        "~{ALU_OUT}":       "PC5/D32",   # U28.9
        "~{SW_OUT}":        "PC6/D31",   # U28.7
        # D30-D22: U30
        "CW0":              "PC7/D30",   # U30.1 (A0)
        "CW1":              "PA7/D29",   # U30.2 (A1)
        "CW2":              "PA6/D28",   # U30.3 (A2)
        "~{REG_A_LOAD}":    "PA5/D27",   # U30.14
        "~{REG_B_LOAD}":    "PA4/D26",   # U30.13
        "~{REG_C_LOAD}":    "PA3/D25",   # U30.12
        "~{MAR_LO_LOAD}":   "PA2/D24",   # U30.11
        "~{MAR_HI_LOAD}":   "PA1/D23",   # U30.10
        "~{IR_LOAD}":       "PA0/D22",   # U30.9
        # D19: the spill
        "~{RAM_LOAD}":      "PD2/D19",   # U30.7
    },
    "mdr": {
        # Control run: ONE unbroken descent D53 -> D40, one contiguous
        # block per gate chip, holes in each chip's own pin order. The
        # three byte buses ride their fixed-port runs (each itself
        # unbroken): W0-7 = PA = D22-D29, MDR0-7 = PF = A0-A7,
        # IRB0-7 = PK = A8-A15.
        # D53-D49: U22 '02, pins 1..5 (D53 = LE_IR probe U22.1,
        # D50 = ~{MDR_EN} probe U22.4)
        "CLK":              "PB1/D52",   # U22.2
        "~{IR_LOAD}":       "PB2/D51",   # U22.3
        "SRC_ACTIVE":       "PL0/D49",   # U22.5
        # D48-D47: U37 '04
        "WRITE_DIR":        "PL1/D48",   # U37.4 (contract OUT)
        "~{MDR_OUT}":       "PL2/D47",   # U37.5
        # D46-D40: U39 '00, pins 1,2,4,6,8,9,10 ascending
        # (D43 = LE_MDR probe U39.6, D42 = BUS_DIR probe U39.8)
        "~{ROM_OUT}":       "PL3/D46",   # U39.1
        "~{RAM_OUT}":       "PL4/D45",   # U39.2
        "~{RAM_LOAD}":      "PL5/D44",   # U39.4 (same net as U37.3)
        "~{ALU_OUT}":       "PG0/D41",   # U39.9
        "~{SW_OUT}":        "PG1/D40",   # U39.10
    },
    "alu": {
        # DERIVED FROM THE BOARD (2026-07-26). Strip slots were read off
        # the wired board; the Mega follows with pin = slot + 17, which
        # keeps the existing ribbon (D53 -> slot 36 down to D26 -> slot 9).
        "CW9=SA2"           : "PB0/D53",   # slot 36
        "CW10=SA1"          : "PB1/D52",   # slot 35
        "CW11=SA0"          : "PB2/D51",   # slot 34
        "~{RESET}"          : "PL2/D47",   # slot 30
        "~{CLK}"            : "PL3/D46",   # slot 29
        "CLK"               : "PL4/D45",   # slot 28
        "FLAG_Z"            : "PG0/D41",   # slot 24
        "~{REG_B_LOAD}"     : "PC1/D36",   # slot 19
        "~{REG_A_LOAD}"     : "PC2/D35",   # slot 18
        "~{ALU_OUT}"        : "PC3/D34",   # slot 17
        "W7"                : "PC4/D33",   # slot 16
        "W6"                : "PC5/D32",   # slot 15
        "W5"                : "PC6/D31",   # slot 14
        "W4"                : "PC7/D30",   # slot 13
        "W3"                : "PA7/D29",   # slot 12
        "W2"                : "PA6/D28",   # slot 11
        "W1"                : "PA5/D27",   # slot 10
        "W0"                : "PA4/D26",   # slot 9
    },
    "memory": {
        # BENCH-DRIVEN LAYOUT (Rico, 2026-07-23): both byte buses ride
        # ONE unbroken 24-pin run, D53 -> D30, MDR first then M, each
        # bus ascending — a ribbon per bus, no controls interleaved.
        # Signals follow on D29 -> D22 (+ the D19 spill), U51 in chip
        # pin order. NOTE this abandons the fixed-port bus rule for this
        # module: neither bus is byte-aligned any more, so mod_memory.c
        # drives/samples both PER PIN (address is static per access —
        # settle() dominates, see the module header).
        "MDR0": "PB0/D53", "MDR1": "PB1/D52",
        "MDR2": "PB2/D51", "MDR3": "PB3/D50",
        "MDR4": "PL0/D49", "MDR5": "PL1/D48",
        "MDR6": "PL2/D47", "MDR7": "PL3/D46",
        "M0":  "PL4/D45", "M1":  "PL5/D44", "M2":  "PL6/D43",
        "M3":  "PL7/D42", "M4":  "PG0/D41", "M5":  "PG1/D40",
        "M6":  "PG2/D39", "M7":  "PD7/D38", "M8":  "PC0/D37",
        "M9":  "PC1/D36", "M10": "PC2/D35", "M11": "PC3/D34",
        "M12": "PC4/D33", "M13": "PC5/D32", "M14": "PC6/D31",
        "M15=ROM_EN": "PC7/D30",          # ROM ~CE rides M15
        # D29-D22: U51 '00 in pin order, then the two chip selects
        # (D28/D26/D25/D23 are the four probes — all U51 outputs)
        "WRITE_DIR":  "PA7/D29",          # U51.1 (daisies to .2 and .5)
        "~{CLK}":     "PA5/D27",          # U51.4
        "~{RAM_OUT}": "PA2/D24",          # U51.9 (also U26.22)
        "~{ROM_OUT}": "PA0/D22",          # U24.22 + U19.19
        "~{RAM_EN}":  "PD2/D19",          # U26.20 (spill; D21/D20 banned)
    },
    "mar": {
        # Controls: two short descents, every wire on U60 (the '02) —
        # D53-D50 = U60 pins 1..4, D41-D38 = U60 pins 5,10,11,13.
        # Buses ride fixed ports: W = PA = D22-D29, M0-7 = PC =
        # D37-D30, M8-15 = PL = D49-D42 (CW14 loses PL6 to M14 by the
        # emitter's bus-priority rule and is hand-placed here).
        # (D53 = LE_MAR_LO probe U60.1, D50 = LE_MAR_HI probe U60.4)
        "~{MAR_LO_LOAD}":     "PB1/D52",   # U60.2
        "CLK":                "PB2/D51",   # U60.3
        "~{MAR_HI_LOAD}":     "PG0/D41",   # U60.5
        "~{RAM_EN}":          "PG1/D40",   # U60.10
        "CW14=PC_MAR_MUX":    "PG2/D39",   # U60.11 (rig drives the tap)
        "~{PC_MAR_MUX}":      "PD7/D38",   # U60.13
    },
    "registers": {
        # One unbroken descent D53 -> D39, two chip blocks, holes in
        # chip pin order. Buses ride their fixed ports (MDR = PF =
        # A0-A7, OB = PK = A8-A15), each an unbroken run itself.
        # D53-D45: U57 '02 (all four LE stamps), pins 1..13
        # (D53/D50/D47/D45 = the LE probes, U57 pins 1/4/10/13)
        "~{REG_A_LOAD}":    "PB1/D52",   # U57.2
        "CLK":              "PB2/D51",   # U57.3 (any of the 4 CLK legs)
        "~{REG_B_LOAD}":    "PL0/D49",   # U57.5
        "~{REG_C_LOAD}":    "PL1/D48",   # U57.8
        "~{REG_OUT_LOAD}":  "PL3/D46",   # U57.11
        # D44-D39: U5 '08 (the '245 CE gates), pins 2,3,5,6,8,10
        # (D43/D41/D40 = the EN probes, U5 pins 3/6/8)
        "~{REG_A_OUT}":     "PL5/D44",   # U5.2
        "~{REG_B_OUT}":     "PL7/D42",   # U5.5
        "~{REG_C_OUT}":     "PG2/D39",   # U5.10
    },
}
# Rig-internal probes: nets the rig samples for diagnosis that are NOT
# sheet contracts (they never leave the DUT board). Emitted into the
# module's bundle as ordinary sampled rows, so `pins <mod>` prints EVERY
# wire of the hookup and mod_*.c binds them by name like anything else.
PIN_PROBES = {
    "control_word": [
        ("~{PC_LOAD_JMP}", "PL0/D49"),   # U29.13 -> U62 gate 2 input
        ("~{COND}",        "PL1/D48"),   # U29.12 -> U62 gate 1 input
        ("COND_TAKEN",     "PL4/D45"),   # U62.1  (gate 1 output)
        ("PC_LOAD_JMP",    "PL6/D43"),   # U62.4  (gate 2 output)
    ],
    "mdr": [
        ("LE_IR",     "PB0/D53"),        # U22.1  -> U34.11 (IR latch LE)
        ("~{MDR_EN}", "PB3/D50"),        # U22.4  -> U25.19 (bridge CE)
        ("LE_MDR",    "PL6/D43"),        # U39.6  -> U18.11 (MDR latch LE)
        ("BUS_DIR",   "PL7/D42"),        # U39.8  -> U25.1  (bridge DIR)
    ],
    "alu": [
        ("ALU_CIN"     , "PB3/D50"),   # slot 33
        ("LE_TMP_B"    , "PL0/D49"),   # slot 32
        ("LE_TMP_A"    , "PL1/D48"),   # slot 31
        ("ALU_V"       , "PL5/D44"),   # slot 27
        ("ALU_C"       , "PL6/D43"),   # slot 26
        ("CRY"         , "PL7/D42"),   # slot 25
        ("FLAG_V"      , "PG1/D40"),   # slot 23
        ("FLAG_N"      , "PG2/D39"),   # slot 22
        ("FLAG_C"      , "PD7/D38"),   # slot 21
        ("Z"           , "PC0/D37"),   # slot 20
    ],
    "memory": [
        ("~{WRITE_DIR}",    "PA6/D28"),  # U51.3  -> U21.1  ('245 DIR)
        ("~{RAM_WRITE_EN}", "PA4/D26"),  # U51.6  -> U26.27 (RAM ~WE)
        ("RAM_MDR_DIS",     "PA3/D25"),  # U51.8  -> U51.12/13
        ("~{RAM_MDR_EN}",   "PA1/D23"),  # U51.11 -> U21.19 ('245 CE)
    ],
    "mar": [
        ("LE_MAR_LO", "PB0/D53"),        # U60.1 -> U55.11
        ("LE_MAR_HI", "PB3/D50"),        # U60.4 -> U58.11
    ],
    "registers": [
        ("~{REG_A_LE}",   "PB0/D53"),    # U57.1  -> U31.11 (active HIGH)
        ("~{REG_B_LE}",   "PB3/D50"),    # U57.4  -> U32.11
        ("~{REG_C_LE}",   "PL2/D47"),    # U57.10 -> U33.11
        ("~{REG_OUT_LE}", "PL4/D45"),    # U57.13 -> U35.11
        ("~{A_EN}",       "PL6/D43"),    # U5.3   -> U41.19 ('245 CE)
        ("~{B_EN}",       "PG0/D41"),    # U5.6   -> U42.19
        ("~{C_EN}",       "PG1/D40"),    # U5.8   -> U43.19
    ],
}


def bus_pin(signal):
    """Fixed-port pin for a bus bit, trying every alias component
    ('M15=ROM_EN' matches via 'M15'). Returns (pin, priority) where priority
    is the MEGA_PORT_BY_PREFIX index — lower wins a within-module pin clash
    (M before CW: the rig reads the M bus as whole ports)."""
    for pri, (rx, port, dmap) in enumerate(MEGA_PORT_BY_PREFIX):
        for comp in signal.split("="):
            m = rx.match(comp)
            if m:
                n = m.group(1)
                bit = int(n) & 7
                return f"{port}{bit}/{dmap[n]}", pri
    return None


def mod_token(sheetpath):
    s = short(sheetpath).lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    # match the firmware's module names
    return {"memory_address_regiser": "mar", "memory_data_register": "mdr",
            "microcode_decoder": "microcode", "control_word_module": "control_word",
            "alu_module": "alu", "program_counter": "pc",
            "register_modules": "registers", "output": "io"}.get(s, s)


def emit_pinmap(contracts, out_path):
    lines = ["/* GENERATED by kicad_contracts.py --pinmap — do not edit */",
             "#ifndef PINMAP_GEN_H", "#define PINMAP_GEN_H",
             "#include <stdint.h>",
             "#include <avr/pgmspace.h>", "",
             "/* All tables live in flash (PROGMEM). Read entries with memcpy_P;",
             "   the embedded char pointers are flash addresses (pgm_read_byte). */",
             "typedef struct { const char *signal; const char *megapin; char dir; } sigpin_t;",
             "typedef struct { const char *module; const sigpin_t *sig; uint8_t n; } modmap_t;", ""]
    interned, strdefs = {}, []

    def sym(s):
        if s not in interned:
            interned[s] = f"pm_s{len(interned)}"
            strdefs.append(f'static const char {interned[s]}[] PROGMEM = "{s}";')
        return interned[s]

    mods, mod_blocks = [], []
    for sheet in sorted(contracts):
        tok = mod_token(sheet)
        assign = PIN_ASSIGN.get(tok, {})
        probes = PIN_PROBES.get(tok, [])
        held = set(assign.values()) | {p for _s, p in probes}
        fixed_pins = {f"{port}{int(n) & 7}/{dpin}"
                      for _rx, port, dmap in MEGA_PORT_BY_PREFIX
                      for n, dpin in dmap.items()}
        unknown = held - set(POOL) - fixed_pins
        if unknown:
            raise SystemExit(f"PIN_ASSIGN/PIN_PROBES for {tok}: unknown pin: {unknown}")
        if len(held) < len(assign) + len(probes):
            raise SystemExit(f"PIN_ASSIGN/PIN_PROBES for {tok}: duplicate pin")
        cands, pool = [], [p for p in POOL if p not in held]
        for kind, d in (("IN", 'O'), ("OUT", 'I'), ("BIDIR", 'B')):
            # rig direction is the DUT's inverse: DUT IN => rig Output
            for label, _others in sorted(contracts[sheet][kind]):
                for signal in expand(label):
                    cands.append((signal, bus_pin(signal), d))
        # Resolve within-module bus-pin clashes (e.g. CW14=PC_MAR_MUX vs M14
        # both wanting PL6): the lowest-priority-index signal keeps the port
        # pin, the loser falls to the pool. Emit alias joins in full so the
        # hookup table shows both names.
        best = {}
        for i, (_s, bp, _d) in enumerate(cands):
            if bp and (bp[0] not in best or bp[1] < cands[best[bp[0]]][1][1]):
                best[bp[0]] = i
        rows = []
        assigned_seen = set()
        for i, (signal, bp, d) in enumerate(cands):
            if signal in assign:            # hand-tune beats the bus rule
                pin = assign[signal]
                assigned_seen.add(signal)
            elif bp and best[bp[0]] == i:
                pin = bp[0]
            else:
                pin = pool.pop(0)
            rows.append((signal, pin, d))
        leftover = set(assign) - assigned_seen
        if leftover:
            raise SystemExit(f"PIN_ASSIGN for {tok}: no such contract signal: {leftover}")
        contract_names = {s for s, _p, _d in rows}
        for pname, ppin in probes:
            if pname in contract_names:
                raise SystemExit(f"PIN_PROBES for {tok}: name collides with contract: {pname}")
            rows.append((pname, ppin, 'I'))
        pins_used = [p for _s, p, _d in rows]
        dupes = {p for p in pins_used if pins_used.count(p) > 1}
        if dupes:
            raise SystemExit(f"pinmap for {tok}: pin used twice: {dupes}")
        # Wiring order: Mega header sweep — D53 down to D2, then A15 down
        # to A0. `pins <mod>` prints in table order, so this IS the order
        # you jumper in.
        def wire_key(row):
            pin = row[1].split("/")[1]
            return (0 if pin[0] == "D" else 1, -int(pin[1:]))
        rows.sort(key=wire_key)
        arr = ",\n    ".join(f"{{{sym(s)}, {sym(p)}, '{d}'}}" for s, p, d in rows)
        mod_blocks.append(f"static const sigpin_t sig_{tok}[] PROGMEM = {{\n    {arr}\n}};")
        mods.append((tok, len(rows)))
    arr = ",\n    ".join(f'{{{sym(t)}, sig_{t}, {n}}}' for t, n in mods)
    lines += strdefs + [""] + mod_blocks
    lines += ["", f"static const modmap_t MODMAPS[] PROGMEM = {{\n    {arr}\n}};",
              f"#define MODMAP_COUNT {len(mods)}", "", "#endif"]
    open(out_path, "w").write("\n".join(lines) + "\n")
    print(f"[pinmap written to {out_path}]")


def expand(label):
    """Expand a compressed numeric range ('W0-7' -> W0..W7). Defensive only:
    build_contracts() emits uncompressed per-bit labels. Alias joins like
    'CW14=PC_MAR_MUX' pass through whole — emit_pinmap() keeps the full join
    as the signal name and pins it by whichever component is a bus bit."""
    m = re.match(r"^(.*?)(\d+)-(\d+)$", label)
    if not m:
        return [label]
    base, a, b = m.group(1), int(m.group(2)), int(m.group(3))
    return [f"{base}{i}" for i in range(a, b + 1)]


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
    if "--pinmap" in sys.argv:
        out = os.path.normpath(os.path.join(here, "..", "..", "tests",
                                            "dino_bringup", "src", "pinmap_gen.h"))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        emit_pinmap(contracts, out)
