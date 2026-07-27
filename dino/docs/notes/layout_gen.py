#!/usr/bin/env python3
"""DINO breadboard placement analyser and page generator.

Placement was the last piece of bench setup still done by eye. This
derives it from the SAME netlist the contracts, the pinmap and the rig
firmware come from, so a placement page can never drift from the
schematic.

What it does:
  * reads the kicad-cli XML netlist (exported on demand, cached)
  * scores a placement: every net costs (highest board it touches minus
    lowest), which is exactly the number of board-to-board hops it needs
  * reports the bundles between each pair of boards, and any net forced
    to span a board (the expensive kind)
  * finds the cheapest BOARD ORDER by trying every permutation — this is
    what decided the ALU layout: moving the '382s to the middle turned
    eight crossing wires into two single hops
  * auto-places from scratch when you have no candidate: it orders the
    chips by connectivity, packs them into as many boards as the width
    requires, then optimises the board order. Board COUNT is an output.
  * emits a bench page (docs/notes/layouts/<module>.html)

Run:  python3 layout_gen.py alu             # score + page for a placement
      python3 layout_gen.py alu --auto      # ignore PLACEMENTS, derive one
      python3 layout_gen.py --list
Test: python3 test_layout_gen.py
"""
import html
import itertools
import os
import re
import subprocess
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT_SCH = os.path.normpath(os.path.join(
    HERE, "..", "..", "dino_v0_0_2", "dino_v0_0_2.kicad_sch"))
OUTDIR = os.path.join(HERE, "layouts")
NETLIST_CACHE = "/tmp/kicad_netlist_dino_v0_0_2.xml"

UI_SCALE = 1.5              # bench pages render at what CMD-+ 150% gives

# Slot numbering is PER MODULE, set with "slot_order" in PLACEMENTS:
#   "distance" (default) = minimise chip-to-slot wire length, families
#                          contiguous on the strip
#   "ribbon"             = number slots to follow the Mega's pin descent,
#                          so the rig bundle runs parallel with no
#                          crossings. Measured on the ALU: costs 2
#                          column-units over "distance", i.e. free.
SLOT_ORDER_DEFAULT = "distance"

BOARD_WIDTH = 63            # columns on a full-size strip
CHIP_GAP = 2                # empty columns between neighbours

# ---- placements ---------------------------------------------------------
# board index 0 = top of the stack. Columns are 1-based, matching the
# numbers silkscreened on the strip.
PLACEMENTS = {
    "alu": {
        # Derived by --auto and adopted 2026-07-24. The hand layout put
        # the shadows and the '382s on different boards, which dragged
        # TA0-7 + TB0-7 across a boundary — 16 wires. Keeping the whole
        # datapath together (W, TA, TB and every internal ALU net local)
        # and pushing only the F bus plus control across costs 17 hops
        # on 2 boards instead of 39 on 3, with nothing spanning.
        "boards": ["datapath — W, TA, TB and the ALU all stay here",
                   "flags & control — zero tree, mux, register, stamps"],
        # AS BUILT AND FROZEN 2026-07-26. The strip is wired; these are
        # the slot numbers in copper, so they are the truth and no
        # optimiser gets to touch them. An explicit "slots" map disables
        # slot ordering entirely for this module — the generator follows
        # the board, never the reverse. Freeze a module the moment its
        # strip is populated.
        # AS BUILT, READ OFF THE STRIP 2026-07-26 AND FROZEN.
        # Not derived, not ordered by any algorithm — Rico beeped
        # every slot to its chip pin and these are the results.
        # Nothing may renumber these. The Mega bends to them
        # (PIN_ASSIGN in kicad_contracts.py: pin = slot + 17).
        "slots": {
            "SA2": 36,
            "SA1": 35,
            "SA0": 34,
            "ALU_CIN": 33,
            "LE_TMP_B": 32,
            "LE_TMP_A": 31,
            "~{RESET}": 30,
            "~{CLK}": 29,
            "CLK": 28,
            "ALU_V": 27,
            "ALU_C": 26,
            "CRY": 25,
            "FLAG_Z": 24,
            "FLAG_V": 23,
            "FLAG_N": 22,
            "FLAG_C": 21,
            "Z": 20,
            "~{REG_B_LOAD}": 19,
            "~{REG_A_LOAD}": 18,
            "~{ALU_OUT}": 17,
            "W7": 16,
            "W6": 15,
            "W5": 14,
            "W4": 13,
            "W3": 12,
            "W2": 11,
            "W1": 10,
            "W0": 9,
            "F7": 8,
            "F6": 7,
            "F5": 6,
            "F4": 5,
            "F3": 4,
            "F2": 3,
            "F1": 2,
            "F0": 1,
        },
        "sheet": "alu.kicad_sch",
        "chips": {
            # ref:  (board, first column, pin count)
            "U47": (0, 1, 20),   "U45": (0, 13, 20),  "U46": (0, 25, 20),
            "U38": (0, 37, 20),  "U40": (0, 49, 20),
            "U52": (1, 1, 14),   "U53": (1, 10, 14),  "U48": (1, 19, 16),
            "U49": (1, 29, 20),  "U50": (1, 41, 14),
        },
        "roles": {
            "U38": "ALU low nibble", "U40": "ALU high nibble",
            "U45": "TMP_A shadow", "U46": "TMP_B shadow",
            "U47": "output latch", "U48": "flag mux",
            "U49": "flag register", "U50": "LE stamps · ALU_CIN",
            "U52": "zero NORs", "U53": "zero ANDs · SA1·SA0",
        },
    },
}


# ---- geometry -----------------------------------------------------------
def chip_cols(pins):
    """A DIP occupies half its pin count in breadboard columns."""
    return pins // 2


def board_count(chips):
    return max((b for b, _, _ in chips.values()), default=-1) + 1


def overlaps(chips):
    """Pairs of chips sharing a column on the same board."""
    bad = []
    items = sorted(chips.items(), key=lambda kv: (kv[1][0], kv[1][1]))
    for (ra, (ba, ca, pa)), (rb, (bb, cb, pb)) in zip(items, items[1:]):
        if ba == bb and cb < ca + chip_cols(pa):
            bad.append((ra, rb))
    return bad


def off_board(chips, width=BOARD_WIDTH):
    return sorted(r for r, (_, c, p) in chips.items()
                  if c + chip_cols(p) - 1 > width)


# ---- flipped strips -----------------------------------------------------
# The strips are mounted so the silkscreen numbers count DOWN left to
# right (column 1 at the right edge), which lines the columns up with the
# Mega's descending pin run. Placement columns ALWAYS mean the printed
# number; only the drawing and the reading order mirror.
def visual_start(col, pins, width=BOARD_WIDTH, descending=True):
    """Left-hand grid position for a chip whose printed columns start at
    `col`. Self-inverse, so it converts either way."""
    if not descending:
        return col
    return width - col - chip_cols(pins) + 2


def ruler_numbers(width=BOARD_WIDTH, descending=True):
    return list(range(width, 0, -1)) if descending else list(range(1, width + 1))


def bench_order(chips, board, descending=True):
    """Chips on `board` in the order you physically meet them, left to
    right, which is the order to wire them in."""
    on = [(c, r) for r, (b, c, _) in chips.items() if b == board]
    return [r for _, r in sorted(on, reverse=descending)]


# ---- wire colours -------------------------------------------------------
# Rico's bench scheme, plus two additions for signals his six do not cover
# (status/flags and the select lines). First rule that matches wins, so the
# specific names sit above the generic suffix rules.
WIRE_COLORS = [
    (r"^\+5V$",                                   "red",    "supply"),
    (r"^GND$",                                     "black",  "ground"),
    (r"^(CLK|~\{CLK\}|RESET|~\{RESET\}|T\d)$",     "yellow", "clock & reset"),
    (r"^M\d+",                                     "blue",   "address"),
    (r"^(W|F|TA|TB|MDR|OB|IRB|AB|BB|CB)\d+$",       "green",  "data bus"),
    (r"^(FLAG_|ALU_C$|ALU_V$|Z$|CRY$|COND_TAKEN$|PC_LOAD_JMP$)",
                                                   "green",  "status / result"),
    (r".",                                         "white",  "control: LE, loads, enables, selects"),
]
COLOR_ORDER = ["red", "black", "green", "blue", "white", "yellow"]


def wire_color(net):
    short = net.rsplit("/", 1)[-1]
    for pat, colour, _why in WIRE_COLORS:
        if re.search(pat, short):
            return colour
    return "white"


def color_legend(nets_used):
    """Colours actually needed for this module, with a reason and a count."""
    seen = defaultdict(int)
    why = {}
    for n in nets_used:
        c = wire_color(n)
        seen[c] += 1
        if c not in why:
            short = n.rsplit("/", 1)[-1]
            why[c] = next((w for p, col, w in WIRE_COLORS
                           if col == c and re.search(p, short)), "other")
    return [(c, seen[c], why.get(c, "other"))
            for c in COLOR_ORDER if seen.get(c)]


# ---- the pseudo card edge -----------------------------------------------
# Every board reserves a block of columns at its LOW-numbered end as a
# connector field. Each net that has to leave the board is brought out to
# one slot there, once, so rig ribbons and inter-board bundles plug into a
# tidy edge instead of being poked in among the chips. The field is on the
# SAME end of every board, so a bundle between two boards runs straight
# down one side.
CONTRACTS_MD = os.path.join(HERE, "dino_sheet_contracts.md")
MOD_TOKEN = {"memory address regiser": "mar", "memory data register": "mdr",
             "microcode_decoder": "microcode", "control word module": "control_word",
             "alu module": "alu", "program counter": "pc",
             "register modules": "registers", "output": "io", "root": "root"}


def _expand(label):
    label = label.split("=")[-1]
    m = re.match(r"^(.*?)(\d+)-(\d+)$", label)
    return [label] if not m else [f"{m.group(1)}{i}"
                                  for i in range(int(m.group(2)), int(m.group(3)) + 1)]


def rig_signals(module):
    """Every net the rig touches for this module: the sheet's contract
    signals plus its hand-placed probes. Same sources the pinmap uses."""
    out, cur = set(), None
    try:
        for line in open(CONTRACTS_MD):
            h = re.match(r"^## (.+)$", line)
            if h:
                cur = MOD_TOKEN.get(h.group(1).strip().lower(), h.group(1).strip().lower())
                continue
            m = re.match(r"^- (IN|OUT|BIDIR)\s+(.+?)\s+(?:<->|<-|->)", line)
            if m and cur == module:
                for part in m.group(2).split(", "):
                    out.update(_expand(part.strip()))
    except FileNotFoundError:
        pass
    try:
        sys.path.insert(0, HERE)
        import kicad_contracts as kc
        for name, _pin in kc.PIN_PROBES.get(module, []):
            out.add(name)
    except Exception:
        pass
    return out


def _mean_col(name, nets, chips, board):
    cols = [chips[r][1] for r, _ in nets[name] if r in chips and chips[r][0] == board]
    return sum(cols) / len(cols) if cols else 0.0


def edge_slots(chips, nets, board, rig, mode="all"):
    """Nets that must reach the outside world from `board`, in the order
    they should occupy the connector field. Crossing nets come first and
    are ordered by NAME, so the same bundle lands in the same order on
    both boards and the ribbon between them runs straight; rig-only nets
    follow, ordered by the columns they serve so their fan-out does not
    cross itself."""
    cross, rigonly = [], []
    for name, nodes in nets.items():
        if is_power(name):
            continue
        boards = {chips[r][0] for r, _ in nodes if r in chips}
        if board not in boards:
            continue
        touched_by_rig = name.rsplit("/", 1)[-1] in rig
        if len(boards) > 1 and mode == "all":
            cross.append(name)
        elif touched_by_rig:
            rigonly.append(name)
    cross.sort(key=lambda n: n.rsplit("/", 1)[-1])
    rigonly.sort(key=lambda n: _mean_col(n, nets, chips, board))
    return cross + rigonly


def edge_width(chips, nets, rig, mode="all"):
    """Columns the connector field needs — the busiest board decides."""
    return max((len(edge_slots(chips, nets, b, rig, mode))
                for b in range(board_count(chips))), default=0)


# ---- cost ---------------------------------------------------------------
def is_power(net):
    tail = net.rsplit("/", 1)[-1]
    return tail in ("+5V", "GND", "VCC", "VDD", "VSS") or tail.startswith("unconnected-")


def net_cost(nodes, chips):
    """Board-to-board hops this net needs. Refs not in `chips` (rig wires,
    other sheets) are ignored — they enter from outside the stack."""
    boards = {chips[r][0] for r, _ in nodes if r in chips}
    return (max(boards) - min(boards)) if boards else 0


def analyse(chips, nets):
    """Board hops AND intra-board wire length.

    `cost` is board-to-board hops, the expensive thing. `cols` is the
    total column distance every net spans WITHIN a board — invisible to
    the original cost model, which meant the placer had no gradient at
    all for chip order on a board and just kept whatever the greedy seed
    produced. Scoring uses hops first and columns as the tie-break, so a
    cross-board wire is still always worse than a long local one."""
    local, crossing, spanning = [], [], []
    bundles = defaultdict(list)
    cost, cols = 0, 0
    for name, nodes in nets.items():
        if is_power(name):
            continue
        per_board = defaultdict(list)
        for r, _ in nodes:
            if r in chips:
                per_board[chips[r][0]].append(chips[r][1])
        for _b, cc in per_board.items():
            cols += max(cc) - min(cc)
        boards = sorted(per_board)
        if len(boards) <= 1:
            if boards:
                local.append(name)
            continue
        c = boards[-1] - boards[0]
        cost += c
        crossing.append((name, boards))
        # "spanning" means the net SKIPS a board, so some jumper has to
        # run past one. A net that lands on every board between its ends
        # (a driver in the middle feeding both ways) is relayed at each
        # stop and never needs a long wire.
        if any(b not in boards for b in range(boards[0], boards[-1] + 1)):
            spanning.append(name)
        for a, b in zip(boards, boards[1:]):
            bundles[(a, b)].append(name)
    return {"cost": cost, "cols": cols, "local": sorted(local),
            "crossing": sorted(crossing), "spanning": sorted(spanning),
            "bundles": {k: sorted(v) for k, v in bundles.items()}}


def apply_order(chips, order):
    """order[i] = which OLD board index sits at NEW position i."""
    where = {old: new for new, old in enumerate(order)}
    return {r: (where[b], c, p) for r, (b, c, p) in chips.items()}


def best_order(chips, nets, n_boards=None):
    n = n_boards if n_boards is not None else board_count(chips)
    best, best_cost = list(range(n)), analyse(chips, nets)["cost"]
    for perm in itertools.permutations(range(n)):
        c = analyse(apply_order(chips, list(perm)), nets)["cost"]
        if c < best_cost:
            best, best_cost = list(perm), c
    return best, best_cost


# ---- auto placement -----------------------------------------------------
def _weights(pins, nets):
    w = defaultdict(int)
    for name, nodes in nets.items():
        if is_power(name):
            continue
        refs = sorted({r for r, _ in nodes if r in pins})
        for a, b in itertools.combinations(refs, 2):
            w[(a, b)] += 1
            w[(b, a)] += 1
    return w


def _pack(order, pins, width, reserve=0):
    """Walk the chip order left to right, starting a new board whenever
    the next chip would not fit. Board count falls out of this. `reserve`
    keeps that many low-numbered columns free on every board for the
    connector field."""
    chips, board, col = {}, 0, reserve + 1
    for ref in order:
        need = chip_cols(pins[ref])
        if col + need - 1 > width:
            board, col = board + 1, reserve + 1
        chips[ref] = (board, col, pins[ref])
        col += need + CHIP_GAP
    return chips


def auto_place(pins, nets, width=BOARD_WIDTH, reserve=0):
    """Derive a placement from connectivity alone. Greedy seed (always
    append whichever unplaced chip is most strongly tied to what is
    already down), then hill-climb on swaps against the real cost, then
    pick the cheapest board order."""
    if not pins:
        return {}
    w = _weights(pins, nets)
    remaining = set(pins)
    start = max(sorted(remaining),
                key=lambda r: sum(w[(r, o)] for o in remaining if o != r))
    order = [start]
    remaining.discard(start)
    while remaining:
        nxt = max(sorted(remaining),
                  key=lambda r: (sum(w[(r, o)] for o in order),
                                 -sorted(remaining).index(r)))
        order.append(nxt)
        remaining.discard(nxt)

    def score(o):
        a = analyse(_pack(o, pins, width, reserve), nets)
        return (a["cost"], a["cols"])       # hops first, wire length breaks ties

    cur = score(order)
    improved = True
    while improved:
        improved = False
        for i in range(len(order)):
            for j in range(i + 1, len(order)):
                trial = list(order)
                trial[i], trial[j] = trial[j], trial[i]
                s = score(trial)
                if s < cur:
                    order, cur, improved = trial, s, True
    chips = _pack(order, pins, width, reserve)
    perm, _ = best_order(chips, nets)
    return apply_order(chips, perm)


def breakout_plan(chips, nets, rig, width=BOARD_WIDTH, module_hint=None):
    """The cheapest pseudo card edge: a strip of its own.

    Reserving columns on the logic boards is a bad trade — the field
    pushes chips apart, more boards means more nets cross, and the
    cross-board wiring grows faster than the tidiness is worth (measured
    on the ALU: 2 boards/17 hops becomes 4 boards/59 with a full field).
    Giving the field its own strip costs no logic columns at all. Each
    rig signal runs once from its chip to a numbered slot; the Mega's
    ribbon then plugs into the strip in one straight row, and nothing
    reaches in among the chips.

    Returns [(slot, net, board, chip refs on that board)] in the order
    the slots sit on the strip — grouped by board, then by the column
    they serve, so the fan-in never crosses itself."""
    cand = []
    for name, nodes in nets.items():
        if is_power(name):
            continue
        boards = sorted({chips[r][0] for r, _ in nodes if r in chips})
        if not boards:
            continue
        wanted = name.rsplit("/", 1)[-1] in rig
        if not wanted and len(boards) < 2:
            continue                      # private to one board, leave it there
        refs = sorted({r for r, _ in nodes if r in chips})
        # order: by the first board it serves, then by the column on it,
        # so the fan-in to the strip never crosses itself
        # Slot order follows the BUILD order: signals are grouped on the
        # strip exactly as they are grouped in the wiring guide, so each
        # family plugs into one contiguous block and the Mega ribbon lands
        # in functional order too.
        cand.append((net_family(name), name.rsplit("/", 1)[-1],
                     name, boards, refs, wanted,
                     _mean_col(name, nets, chips, boards[0])))
    # Families stay CONTIGUOUS on the strip — that is what makes a group
    # plug into one block — but the blocks are ordered by where their
    # chips physically sit, so a signal is never sent to the far end of
    # the strip just because of what it is called. Build order (logical)
    # and slot order (physical) are allowed to differ; each group prints
    # its own slot range.
    frozen = (PLACEMENTS.get(module_hint, {}) or {}).get("slots")
    if frozen:
        # As-built map: assign exactly these numbers, no reordering. Nets
        # the map does not mention keep going (they get the free slots
        # above the highest frozen one) so a schematic addition cannot
        # silently renumber what is already in copper.
        keyed, spare = [], max(frozen.values())
        for row in cand:
            short = row[2].rsplit("/", 1)[-1]
            if short in frozen:
                keyed.append((frozen[short], row))
            else:
                spare += 1
                keyed.append((spare, row))
        keyed.sort(key=lambda t: t[0])
        return [(slot, name, boards, refs, wanted)
                for slot, (_f, _sh, name, boards, refs, wanted, _m) in keyed]

    order = SLOT_ORDER_DEFAULT
    if module_hint:
        order = PLACEMENTS.get(module_hint, {}).get("slot_order",
                                                    SLOT_ORDER_DEFAULT)
    if order == "ribbon":
        # RIBBON ALIGNMENT (Rico's call): number the slots so the Mega's
        # descending pin run maps straight onto descending slots — D53 gets
        # the highest slot, D52 the next, down to D22. The rig ribbon then
        # runs dead parallel with no crossings, which is the bundle that is
        # actually painful to wire. Nets with no rig pin (pure board-to-board
        # links) take the low slots, ordered by the columns they serve.
        pm = rig_pins(module_hint) if module_hint else {}

        def _mega_num(name):
            short = name.rsplit("/", 1)[-1]
            for key, pin in pm.items():
                if short in key.split("="):
                    m = re.search(r"(\d+)", pin)
                    return int(m.group(1)) if m else 0
            return None

        keyed = []
        for row in cand:
            mn = _mega_num(row[2])
            keyed.append(((1, mn) if mn is not None else (0, row[6]), row))
        keyed.sort(key=lambda t: t[0])
        return [(i + 1, name, boards, refs, wanted)
                for i, (_k, (_f, _sh, name, boards, refs, wanted, _m))
                in enumerate(keyed)]

    # Within a block, put nets nearest the low columns first. Then choose
    # the block ORDER by brute force over every permutation, scoring the
    # real chip-to-slot distance. Ordering blocks by mean column is only a
    # heuristic and left 20% on the table; there are few enough families
    # to just solve it. (Unconstrained slotting is a touch shorter still,
    # but it scatters each family across the strip and throws away the
    # one-block-per-group property that makes this wireable.)
    groups = defaultdict(list)
    for row in cand:
        groups[row[0]].append(row)
    for g in groups.values():
        g.sort(key=lambda t: (t[6], t[1]))

    def _slot_cost(order):
        t, i = 0.0, 1
        for fam in order:
            for _f, _sh, name, boards, _r, _w, _m in groups[fam]:
                for b in boards:
                    t += abs(_mean_col(name, nets, chips, b) - i)
                i += 1
        return t

    names = sorted(groups)
    if len(names) <= 8:
        names = min(itertools.permutations(names), key=_slot_cost)
    else:                                  # too many to enumerate: heuristic
        names.sort(key=lambda f: sum(r[6] for r in groups[f]) / len(groups[f]))
    cand = [row for fam in names for row in groups[fam]]
    return [(i + 1, name, boards, refs, wanted)
            for i, (_f, _n, name, boards, refs, wanted, _m) in enumerate(cand)]


def rig_pins(module):
    """{signal: Mega pin} from the generated pinmap — the same table the
    firmware resolves at runtime, so the strip's rig column cannot drift
    from what `pins <module>` prints."""
    hdr = os.path.normpath(os.path.join(HERE, "..", "..", "tests",
                                        "dino_bringup", "src", "pinmap_gen.h"))
    try:
        src = open(hdr).read()
    except FileNotFoundError:
        return {}
    strings = dict(re.findall(r'static const char (pm_s\d+)\[\] PROGMEM = "(.*)";', src))
    m = re.search(r'static const sigpin_t sig_%s\[\] PROGMEM = \{(.*?)\};' % module,
                  src, re.S)
    if not m:
        return {}
    out = {}
    for e in re.finditer(r'\{(pm_s\d+), (pm_s\d+), .(.).\}', m.group(1)):
        out[strings[e.group(1)]] = strings[e.group(2)].split("/")[-1]
    return out


def strip_position(chips, nets, rig, module=None):
    """Which gap in the stack the breakout strip should occupy.

    Treat the strip as one more board and try every slot in the stack;
    the winner is the one with the lowest total run length, counting one
    unit per board the signal has to travel to reach the strip. With
    cross-board links relaying THROUGH the strip, the middle of the
    traffic always wins — sitting on an end leaves the far board two
    hops away from every one of its signals."""
    nb = board_count(chips)
    rows = breakout_plan(chips, nets, rig, module_hint=module)
    best, best_cost = 0, None
    for pos in range(nb + 1):               # 0 = above board 1, nb = below last
        cost = 0
        for _slot, _name, boards, _refs, _wanted in rows:
            for b in boards:
                # boards at index >= pos are pushed down one by the strip
                cost += abs((b + (1 if b >= pos else 0)) - pos)
        if best_cost is None or cost < best_cost:
            best, best_cost = pos, cost
    return best, best_cost


def strip_routes(chips, nets, rig, module=None):
    """Per-slot wiring: what lands in each column, from which chip pin on
    which board, plus the Mega pin if the rig taps it."""
    pinmap = rig_pins(module) if module else {}
    out = []
    for slot, name, boards, _refs, wanted in breakout_plan(chips, nets, rig, module_hint=module):
        short = name.rsplit("/", 1)[-1]
        per = {}
        for r, p in sorted(nets[name]):
            if r in chips:
                per.setdefault(chips[r][0], []).append(f"{r}.{p}")
        mega = ""
        for key, pin in pinmap.items():
            if short in key.split("="):
                mega = pin
                break
        out.append({"slot": slot, "net": short, "boards": per,
                    "mega": mega, "link": len(boards) > 1, "rig": wanted})
    return out


def auto_place_with_edge(pins, nets, rig, width=BOARD_WIDTH, mode="all"):
    """Place with a connector field reserved on every board.

    Sizing this by fixpoint DIVERGES: a wider field pushes chips onto more
    boards, more boards means more nets cross, and more crossings need a
    wider field. So instead sweep the reserve and keep the cheapest
    FEASIBLE configuration — feasible meaning every board's field actually
    fits in the columns set aside for it. Fewest boards wins, hops break
    the tie. Returns (chips, reserve) or (None, None) if no width works."""
    best = None
    for reserve in range(0, width // 2 + 2):
        chips = auto_place(pins, nets, width, reserve)
        if off_board(chips, width) or overlaps(chips):
            continue
        need = edge_width(chips, nets, rig, mode)
        if need > reserve:
            continue                      # field would run into the chips
        score = (board_count(chips), analyse(chips, nets)["cost"], reserve)
        if best is None or score < best[0]:
            best = (score, chips, reserve)
    return (best[1], best[2]) if best else (None, None)


# ---- functional grouping ------------------------------------------------
# How a board actually gets built: one signal FAMILY at a time. You run the
# select bus, then the flags, then the latch enables — each is one idea, and
# each is testable on its own. Order is the build order.
FAMILIES = [
    (r"^(CLK$|~\{CLK\}|RESET$|~\{RESET\}|T\d$)", "Clock & reset"),
    (r"^(SA\d|CW\d+=SA|ALU_CIN$)",            "ALU select + carry-in"),
    (r"^(FLAG_|ALU_C$|ALU_V$|Z$|CRY$)",        "Flags & status"),
    (r"^(LE_|.*_LE$)",                         "Latch enables"),
    (r"_(LOAD|OUT|EN)\}?$",                    "Strobes: loads & output enables"),
    (r"^TA\d",                                 "TMP_A operand bus"),
    (r"^TB\d",                                 "TMP_B operand bus"),
    (r"^W\d",                                  "W bus"),
    (r"^F\d",                                  "F result bus"),
    (r"^M\d",                                  "Address bus"),
    (r"^MDR\d",                                "MDR bus"),
    (r"^IRB\d",                                "IR buffer bus"),
]


def net_family(name):
    short = name.rsplit("/", 1)[-1]
    for pat, fam in FAMILIES:
        if re.search(pat, short):
            return fam
    return "Other nets"


def family_steps(chips, nets, rig, module=None, descending=True):
    """One step per signal family, in build order. Each step lists its
    nets with every point they touch — that is the unit you actually
    wire and then meter, rather than 196 separate wires."""
    order = [f for _p, f in FAMILIES] + ["Other nets"]
    routes = {r["net"]: r for r in strip_routes(chips, nets, rig, module)}
    fams = defaultdict(list)
    for name, nodes in nets.items():
        if is_power(name):
            continue
        pts = sorted(((r, p) for r, p in nodes if r in chips),
                     key=lambda rp: _phys(rp[0], rp[1], chips, descending))
        if not pts:
            continue
        short = name.rsplit("/", 1)[-1]
        rt = routes.get(short)
        slot = rt["slot"] if rt else None
        # The strip sits BETWEEN the boards, so it is the junction — a net
        # crossing boards must not be daisy-chained board to board and then
        # doubled back up to its slot. Chain each board's own points, then
        # hop to the slot from each side. Same wire COUNT, but every wire
        # crosses one gap instead of one wire crossing the whole stack.
        per_board = defaultdict(list)
        for r, p in pts:
            per_board[chips[r][0]].append(f"{r}.{p}")
        legs = [per_board[b] for b in sorted(per_board)]
        if slot and len(legs) > 1:
            # crossing net: the slot is the junction between the boards
            chain = f" → slot {slot} → ".join(" → ".join(l) for l in legs)
        elif slot:
            # board-local net the rig taps: chain it, then one run out
            chain = " → ".join(legs[0]) + f" → slot {slot}"
        else:
            chain = " → ".join(" → ".join(l) for l in legs)
        fams[net_family(name)].append({
            "net": short,
            "colour": wire_color(name),
            "points": [f"{r}.{p}" for r, p in pts],
            "legs": legs,
            "chain": chain,
            "slot": slot,
            "mega": (rt or {}).get("mega", ""),
        })
    out = []
    for fam in order:
        if fam not in fams:
            continue
        rows = sorted(fams[fam], key=lambda d: d["net"])
        slots = [d["slot"] for d in rows if d["slot"]]
        out.append({"family": fam, "nets": rows,
                    "colour": rows[0]["colour"],
                    "slots": (min(slots), max(slots)) if slots else None,
                    "wires": sum(
                        sum(max(len(l) - 1, 0) for l in d["legs"])
                        + (len(d["legs"]) if d["slot"] else
                           max(len(d["legs"]) - 1, 0))
                        for d in rows)})
    return out


# ---- step-by-step build -------------------------------------------------
def _phys(ref, pin, chips, descending=True):
    """Sort key that follows the BENCH, not the alphabet: the chip's
    physical position first, then pin number. Without this a chain
    orders U38.11 before U38.8 and hops chips by ref name."""
    b, col, pins = chips[ref]
    order = -col if descending else col
    return (b, order, int(pin) if str(pin).isdigit() else 0)


def wiring_steps(chips, nets, rig, module=None, width=BOARD_WIDTH,
                 by_chip=False, descending=True):
    """The build, ordered so no wire ever has to go UNDER one already laid.

    Rats-nest control is mostly sequencing: rails hug the board, intra-board
    hops are short and low, chip-to-strip runs cross the gap once, and the
    rig ribbon goes on last so it can be unplugged without disturbing
    anything. Each wire carries the colour its signal class dictates."""
    steps = []
    nb = board_count(chips)
    pinmap = rig_pins(module) if module else {}

    # 1. rails
    rail = []
    for netname, colour in (("+5V", "red"), ("GND", "black")):
        for r, p in sorted(nets.get(netname, [])):
            if r in chips:
                rail.append((f"{r}.{p}", f"{colour} rail", netname, colour,
                             chips[r][0]))
    steps.append({
        "title": "Rails first — every chip, both rails",
        "why": "Nothing else works without them and they hug the board, so "
               "they must go down before any signal wire crosses over. Meter "
               "each VCC leg before a single signal goes in.",
        "wires": rail})

    # 2. intra-board nets, per board, left to right
    for b in range(nb):
        w = []
        local = []
        for name, nodes in nets.items():
            if is_power(name):
                continue
            boards = {chips[r][0] for r, _ in nodes if r in chips}
            if boards != {b}:
                continue
            pts = sorted(((r, p) for r, p in nodes if r in chips),
                         key=lambda rp: _phys(rp[0], rp[1], chips, descending))
            if len(pts) < 2:
                continue
            local.append((_phys(pts[0][0], pts[0][1], chips, descending),
                          name, pts))
        local.sort()                     # work across the board once
        for _key, name, pts in local:
            colour = wire_color(name)
            for (ra, pa), (rz, pz) in zip(pts, pts[1:]):
                w.append((f"{ra}.{pa}", f"{rz}.{pz}",
                          name.rsplit("/", 1)[-1], colour, b))
        if w:
            steps.append({
                "title": f"Board {b + 1} — internal nets",
                "why": "Short hops between neighbouring chips. Daisy-chain "
                       "multi-point nets pin to pin rather than fanning them "
                       "from one hole; it keeps the runs flat and short.",
                "wires": w})

    # 3. chip -> strip
    routes = strip_routes(chips, nets, rig, module)
    for b in range(nb):
        w = []
        for rt in routes:
            for pt in rt["boards"].get(b, []):
                w.append((pt, f"slot {rt['slot']}", rt["net"],
                          wire_color(rt["net"]), b))
        if w:
            steps.append({
                "title": f"Board {b + 1} → breakout strip",
                "why": "One wire per signal, crossing the gap once. Work in "
                       "slot order so the bundle stays combed and no two "
                       "wires trade places.",
                "wires": w})

    if by_chip:
        # Regroup: every wire belongs to the FIRST chip (in bench order)
        # that touches it, so you finish and meter one chip completely
        # before moving on. Rails stay first, the rig ribbon stays last.
        rank, seq = {}, []
        for b in range(nb):
            for ref in bench_order(chips, b, descending):
                rank[ref] = len(rank)
                seq.append((b, ref))
        pool = [wire for st in steps[1:] for wire in st["wires"]]

        def owner(wire):
            refs = [e.split(".")[0] for e in (wire[0], wire[1])
                    if e.split(".")[0] in rank]
            return min(refs, key=lambda r: rank[r]) if refs else None

        grouped = defaultdict(list)
        for wire in pool:
            o = owner(wire)
            if o:
                grouped[o].append(wire)
        steps = steps[:1]
        for b, ref in seq:
            if not grouped.get(ref):
                continue
            steps.append({
                "title": f"{ref} (board {b + 1}) — every wire it owns",
                "why": "Finish and meter this chip before the next one. A "
                       "wire is listed under the first chip that touches it, "
                       "so nothing is done twice.",
                "wires": grouped[ref]})

    # 4. the rig
    w = []
    for rt in routes:
        if rt["mega"]:
            w.append((f"slot {rt['slot']}", f"Mega {rt['mega']}", rt["net"],
                      wire_color(rt["net"]), None))
    if w:
        steps.append({
            "title": "Rig ribbon → strip",
            "why": "Last, so it lies on top of everything and can be pulled "
                   "off without disturbing the module. Series resistor in "
                   "every rig-driven line.",
            "wires": w})
    return steps


# ---- netlist ------------------------------------------------------------
def _kicad_cli():
    for c in ("/Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli", "kicad-cli"):
        if c == "kicad-cli" or os.path.exists(c):
            return c
    return "kicad-cli"


def load_nets(force=False):
    """{net name: [(ref, pin), ...]} from the kicad-cli XML export."""
    if force or not os.path.exists(NETLIST_CACHE):
        subprocess.run([_kicad_cli(), "sch", "export", "netlist",
                        "--format", "kicadxml", "-o", NETLIST_CACHE, ROOT_SCH],
                       check=True, capture_output=True)
    xml = open(NETLIST_CACHE).read()
    nets = {}
    for m in re.finditer(r'<net code="\d+" name="([^"]*)"[^>]*>(.*?)</net>', xml, re.S):
        nets[m.group(1)] = re.findall(r'ref="([^"]+)"\s+pin="([^"]+)"', m.group(2))
    return nets


def pins_of(nets, refs):
    """Highest pin number seen per ref — the DIP's pin count."""
    n = defaultdict(int)
    for nodes in nets.values():
        for r, p in nodes:
            if r in refs and p.isdigit():
                n[r] = max(n[r], int(p))
    return dict(n)


# ---- page ---------------------------------------------------------------
CSS = """
:root{--paper:#F2EEE6;--ink:#15171C;--soft:#5A5E68;--board:#E2DCD1;
--edge:#CFC7B8;--chip:#23252B;--chiptx:#E8E4DB;--copper:#A96D33;
--hop:#2F7A72;--span:#BC5836;--rule:rgba(21,23,28,.14);--panel:#FBF9F5;
--railp:#B5342A;--railn:#2A5490}
@media (prefers-color-scheme:dark){:root{--paper:#14161A;--ink:#E9E6DF;
--soft:#9AA0AC;--board:#262A31;--edge:#363C45;--chip:#0C0D10;
--chiptx:#D8D4CB;--copper:#D2955A;--hop:#57B3A7;--span:#E0805E;
--rule:rgba(233,230,223,.16);--panel:#1A1D22;--railp:#D9564A;--railn:#5B8AD0}}
:root[data-theme=dark]{--paper:#14161A;--ink:#E9E6DF;--soft:#9AA0AC;
--board:#262A31;--edge:#363C45;--chip:#0C0D10;--chiptx:#D8D4CB;
--copper:#D2955A;--hop:#57B3A7;--span:#E0805E;--rule:rgba(233,230,223,.16);
--panel:#1A1D22;--railp:#D9564A;--railn:#5B8AD0}
:root[data-theme=light]{--paper:#F2EEE6;--ink:#15171C;--soft:#5A5E68;
--board:#E2DCD1;--edge:#CFC7B8;--chip:#23252B;--chiptx:#E8E4DB;
--copper:#A96D33;--hop:#2F7A72;--span:#BC5836;--rule:rgba(21,23,28,.14);
--panel:#FBF9F5;--railp:#B5342A;--railn:#2A5490}
body{background:var(--paper);color:var(--ink);margin:0;padding:40px 24px 80px;
font:400 16px/1.6 ui-sans-serif,system-ui,"Helvetica Neue",Arial,sans-serif}
.wrap{max-width:1040px;margin:0 auto;display:flex;flex-direction:column;gap:38px}
h1{font-size:30px;line-height:1.15;margin:0;letter-spacing:-.02em;text-wrap:balance}
h2{font-size:19px;margin:0 0 12px;letter-spacing:-.01em}
p{margin:0;max-width:66ch}
.lede{color:var(--soft);font-size:17px;margin-top:12px}
.eyebrow{font:600 11px/1 ui-monospace,Menlo,monospace;letter-spacing:.16em;
text-transform:uppercase;color:var(--copper);margin:0 0 10px}
header{border-bottom:2px solid var(--ink);padding-bottom:20px}
section{display:flex;flex-direction:column;gap:14px}
.board{background:var(--board);border:1px solid var(--edge);border-radius:3px;
padding:12px 14px 8px;overflow-x:auto}
.inner{min-width:760px}
.rail{height:5px;border-radius:2px;opacity:.5}
.rail.p{background:var(--railp);margin-bottom:9px}
.rail.n{background:var(--railn);margin-top:9px}
.grid{display:grid;gap:0;align-items:stretch}
.chip{grid-row:1;min-height:52px;display:flex;flex-direction:column;justify-content:center;background:var(--chip);color:var(--chiptx);border-radius:2px;
padding:9px 6px;text-align:center;min-width:0;
font:600 12px/1.25 ui-monospace,Menlo,monospace}
.chip .ref{display:block;font-size:13px;letter-spacing:.04em}
.chip .role{display:block;font-weight:400;font-size:10px;color:var(--copper);margin-top:3px}
.chip .cols{display:block;font-weight:400;font-size:10px;opacity:.6}
.edge{grid-row:1;border:1px dashed var(--copper);border-radius:2px;
padding:9px 4px;text-align:center;color:var(--copper);
font:600 10px/1.2 ui-monospace,Menlo,monospace}
.slots{display:flex;flex-wrap:wrap;gap:4px;padding:6px 0 0 18px}
.slot{font:400 11px/1 ui-monospace,Menlo,monospace;background:var(--panel);
border:1px solid var(--rule);border-radius:2px;padding:3px 6px;color:var(--soft)}
.slot b{color:var(--copper);font-weight:600}
.step{border-left:3px solid var(--rule);padding:0 0 0 18px;display:flex;
flex-direction:column;gap:8px}
.step h3{margin:0;font-size:17px;letter-spacing:-.01em}
.wires{display:flex;flex-wrap:wrap;gap:5px}
.wire{display:inline-flex;align-items:center;gap:6px;background:var(--panel);
border:1px solid var(--rule);border-radius:3px;padding:3px 8px;
font:400 12px/1.35 ui-monospace,Menlo,monospace}
.dot{width:10px;height:10px;border-radius:50%;flex:none;
border:1px solid rgba(128,128,128,.55)}
.legend{display:flex;flex-wrap:wrap;gap:14px}
.legend div{display:inline-flex;align-items:center;gap:7px;font-size:14px}
.cnt{color:var(--soft);font-variant-numeric:tabular-nums}
.ruler{display:grid;font:400 9px/1 ui-monospace,Menlo,monospace;
color:var(--soft);margin-top:6px;font-variant-numeric:tabular-nums}
.ruler span{text-align:center}
.ruler span.t{border-top:1px solid var(--rule);padding-top:3px}
.stage{display:flex;flex-direction:column;gap:8px}
.sname{font:600 11px/1 ui-monospace,Menlo,monospace;letter-spacing:.16em;
text-transform:uppercase}
.note{color:var(--soft);font-size:13.5px}
.bundles{display:flex;flex-direction:column;gap:6px;padding:4px 0 4px 18px}
.b{display:flex;align-items:baseline;gap:10px;font:400 13px/1.45 ui-monospace,Menlo,monospace}
.b .n{font-weight:600;min-width:58px;font-variant-numeric:tabular-nums}
.b.hop{color:var(--hop)}.b.span{color:var(--span)}
.tablewrap{overflow-x:auto}
table{border-collapse:collapse;width:100%;min-width:600px;font-size:14px}
th,td{text-align:left;padding:8px 12px 8px 0;border-bottom:1px solid var(--rule)}
th{font:600 10.5px/1 ui-monospace,Menlo,monospace;letter-spacing:.12em;
text-transform:uppercase;color:var(--soft)}
td.m{font-family:ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums}
td.r{font-weight:600;font-family:ui-monospace,Menlo,monospace}
.callout{background:var(--panel);border-left:3px solid var(--copper);
padding:14px 18px;border-radius:0 3px 3px 0}
.callout p+p{margin-top:9px}
.stat{display:flex;gap:28px;flex-wrap:wrap}
.stat div{display:flex;flex-direction:column;gap:2px}
.stat b{font:600 26px/1 ui-monospace,Menlo,monospace;font-variant-numeric:tabular-nums}
.stat span{font:600 10.5px/1 ui-monospace,Menlo,monospace;letter-spacing:.12em;
text-transform:uppercase;color:var(--soft)}
code{font-family:ui-monospace,Menlo,monospace;font-size:.9em;
background:var(--panel);padding:1px 5px;border-radius:3px}
"""


def _scaled_css():
    """Every px in the stylesheet times UI_SCALE, so the page opens at the
    size you would otherwise reach for CMD-+ to get. em-based tracking and
    the fr-based grids scale with it for free."""
    return re.sub(r"(\d+(?:\.\d+)?)px",
                  lambda m: f"{float(m.group(1)) * UI_SCALE:g}px", CSS)


def _ruler(width, descending=True):
    out = []
    for c in ruler_numbers(width, descending):
        if c == 1 or c % 5 == 0:
            out.append(f'<span class="t">{c}</span>')
        else:
            out.append("<span></span>")
    return f'<div class="ruler" style="grid-template-columns:repeat({width},1fr)">' \
           + "".join(out) + "</div>"


def _short(net):
    return html.escape(net.rsplit("/", 1)[-1])


def render(module, chips, nets, spec, width=BOARD_WIDTH):
    r = analyse(chips, nets)
    descending = spec.get("descending", True)
    nb = board_count(chips)
    names = spec.get("boards") or [f"board {i + 1}" for i in range(nb)]
    roles = spec.get("roles", {})
    perm, pcost = best_order(chips, nets)
    parts = [f"<title>DINO {module} — breadboard placement</title>",
             f"<style>{_scaled_css()}</style>", '<div class="wrap">',
             '<header><p class="eyebrow">DINO v0.0.3 · generated by '
             'docs/notes/layout_gen.py</p>',
             f"<h1>Breadboard placement — {html.escape(module)}</h1>",
             '<p class="lede">Chip positions, and every net that has to leave '
             'its board, derived from the schematic netlist. Regenerate after '
             'any schematic change; never edit this page.</p>',
             ('<p class="note" style="margin-top:.5em">Strips are mounted '
              'flipped: the silkscreen numbers count DOWN left to right, and '
              'these drawings match what you see. Column numbers below are '
              'always the printed ones.</p>' if descending else ''),
             '<div class="stat" style="margin-top:1.1em">',
             f'<div><b>{len(chips)}</b><span>chips</span></div>',
             f'<div><b>{nb}</b><span>boards</span></div>',
             f'<div><b>{len(r["local"])}</b><span>nets stay home</span></div>',
             f'<div><b>{r["cost"]}</b><span>board hops</span></div>',
             f'<div><b>{len(r["spanning"])}</b><span>spanning nets</span></div>',
             "</div></header>", "<section><h2>The stack, top to bottom</h2>"]

    rigset = spec.get("rig") or rig_signals(module)
    spos, _ = strip_position(chips, nets, rigset, module)
    routes = strip_routes(chips, nets, rigset, module)

    def _strip_block(nslots):
        cells = "".join(
            f'<div class="edge" style="grid-column:{i+1}">{i+1}</div>'
            for i in range(min(nslots, 63)))
        return ('<div class="stage"><div class="sname" style="color:var(--copper)">'
                f'breakout strip — {nslots} slots, no chips</div>'
                '<div class="board"><div class="inner">'
                f'<div class="grid" style="grid-template-columns:repeat({max(nslots,1)},1fr)">'
                + cells + '</div></div></div>'
                '<p class="note" style="padding-left:2px">Sits between the '
                'boards it serves: every link relays here, so both ends are '
                'one hop away. Slot order runs left to right.</p></div>')

    for b in range(nb):
        if b == spos:
            parts.append(_strip_block(len(routes)))
        on = sorted(((c, ref, p) for ref, (bb, c, p) in chips.items() if bb == b))
        parts.append('<div class="stage"><div class="sname">'
                     f'board {b + 1} — {html.escape(names[b])}</div>')
        parts.append('<div class="board"><div class="inner">'
                     '<div class="rail p"></div>'
                     f'<div class="grid" style="grid-template-columns:repeat({width},1fr)">')
        for col, ref, pins in on:
            span = chip_cols(pins)
            vcol = visual_start(col, pins, width, descending)
            role = html.escape(roles.get(ref, f"{pins}-pin"))
            parts.append(
                f'<div class="chip" style="grid-column:{vcol} / span {span}">'
                f'<span class="ref">{html.escape(ref)}</span>'
                f'<span class="role">{role}</span>'
                f'<span class="cols">{col}–{col + span - 1}</span></div>')
        parts.append('</div><div class="rail n"></div>'
                     + _ruler(width, descending) + "</div></div></div>")
        parts.append('<p class="note" style="padding-left:2px">Wire left to '
                     'right: ' + " · ".join(html.escape(x)
                                            for x in bench_order(chips, b, descending))
                     + "</p>")
        if b + 1 < nb:
            parts.append('<div class="bundles">')
            names_ = r["bundles"].get((b, b + 1), [])
            if names_:
                parts.append(f'<div class="b hop"><span class="n">'
                             f'{len(names_)} net{"s" if len(names_) != 1 else ""}</span>'
                             f'<span>{", ".join(_short(n) for n in names_)}</span></div>')
            else:
                parts.append('<div class="b"><span class="n">—</span>'
                             '<span>nothing crosses here</span></div>')
            parts.append("</div>")
    if spos >= nb:
        parts.append(_strip_block(len(routes)))
    parts.append("</section>")

    if routes:
        parts.append('<section><h2>Signal routing — every wire that leaves a chip</h2>'
                     '<p class="note">One row per strip slot. Run the chip-side '
                     'wires first, then plug the rig ribbon into the Mega column. '
                     '<b>link</b> means the slot also joins the two boards, so it '
                     'replaces a direct board-to-board jumper.</p>'
                     '<div class="tablewrap"><table><thead><tr>'
                     '<th>Slot</th><th>Signal</th><th>Board 1</th>'
                     '<th>Board 2</th><th>Mega</th><th>Kind</th>'
                     "</tr></thead><tbody>")
        for rt in routes:
            b1 = ", ".join(rt["boards"].get(0, [])) or "—"
            b2 = ", ".join(rt["boards"].get(1, [])) or "—"
            kind = "rig+link" if (rt["rig"] and rt["link"]) else (
                "link" if rt["link"] else "rig")
            parts.append(f'<tr><td class="m">{rt["slot"]}</td>'
                         f'<td class="r">{html.escape(rt["net"])}</td>'
                         f'<td class="m">{html.escape(b1)}</td>'
                         f'<td class="m">{html.escape(b2)}</td>'
                         f'<td class="m">{html.escape(rt["mega"] or "—")}</td>'
                         f"<td>{kind}</td></tr>")
        parts.append("</tbody></table></div></section>")

    used = [n for n in nets if any(r_ in chips for r_, _ in nets[n])]
    parts.append('<section><h2>Wire colours</h2><div class="legend">')
    for colour, count, why in color_legend(used):
        parts.append(f'<div><span class="dot" style="background:{colour}">'
                     f'</span>{html.escape(colour)} — {html.escape(why)}'
                     f' <span class="cnt">({count})</span></div>')
    parts.append("</div></section>")

    fams = family_steps(chips, nets, rigset, module, descending)
    total = sum(f["wires"] for f in fams)
    parts.append(f'<section><h2>Build by function — {total} wires</h2>'
                 '<p class="note">One family at a time: run it, meter it, '
                 'move on. Rails go in first and the rig ribbon last; '
                 'everything between is grouped by what the signals DO, '
                 'because that is the unit you can reason about.</p>'
                 '<div class="step"><h3>0. Rails '
                 '<span class="cnt">· red +5V, black GND, every chip</span>'
                 '</h3><p class="note">Meter every VCC leg before a single '
                 'signal goes in.</p></div>')
    for i, f in enumerate(fams, 1):
        parts.append(f'<div class="step"><h3><span class="dot" '
                     f'style="background:{f["colour"]}"></span> {i}. '
                     f'{html.escape(f["family"])} '
                     f'<span class="cnt">· {len(f["nets"])} nets, '
                     f'{f["wires"]} wires'
                     + (f' · strip slots {f["slots"][0]}–{f["slots"][1]}'
                        if f["slots"] else "")
                     + '</span></h3><div class="wires">')
        for d in f["nets"]:
            chain = d["chain"]
            tail = ""
            mega = f' <span class="cnt">[{d["mega"]}]</span>' if d["mega"] else ""
            parts.append(f'<span class="wire"><span class="dot" '
                         f'style="background:{d["colour"]}"></span>'
                         f'<b>{html.escape(d["net"])}</b> '
                         f'{html.escape(chain + tail)}{mega}</span>')
        parts.append("</div></div>")
    parts.append('<div class="step"><h3>Last. Rig ribbon → strip</h3>'
                 '<p class="note">Goes on top so it lifts off without '
                 'disturbing the module. Series resistor in every '
                 'rig-driven line; Mega pin shown in brackets above.</p>'
                 "</div></section>")

    if r["spanning"]:
        parts.append('<section><h2>Nets that span a board</h2>'
                     '<div class="callout"><p>These cannot be a single jumper '
                     'between neighbours — route them around the edge of the '
                     'stack, not across a board.</p><p>'
                     + ", ".join(f"<code>{_short(n)}</code>" for n in r["spanning"])
                     + "</p></div></section>")

    strip = breakout_plan(chips, nets, spec.get("rig") or rig_signals(module),
                          width, module)
    if strip:
        nlink = sum(1 for r in strip if len(r[2]) > 1)
        parts.append('<section><h2>Breakout strip — the pseudo card edge</h2>'
                     '<div class="callout"><p>A strip of its own, not columns '
                     'stolen from the logic boards. Every signal that has to '
                     'leave a board runs once from its chip to a numbered slot; '
                     'the rig ribbon then plugs into the strip in one straight '
                     'row and nothing reaches in among the chips. '
                     f'{nlink} of the {len(strip)} slots also relay a '
                     'cross-board net, so the strip doubles as the backplane.'
                     '</p></div><div class="slots">')
        for slot, name, boards, refs, wanted in strip:
            tag = "rig+link" if (wanted and len(boards) > 1) else (
                "link" if len(boards) > 1 else "rig")
            parts.append(f'<span class="slot"><b>{slot}</b> '
                         f'{html.escape(_short(name))} · {tag} · '
                         f'{html.escape(",".join(refs))}</span>')
        parts.append("</div></section>")
    parts.append('<section><h2>Chips</h2><div class="tablewrap"><table>'
                 "<thead><tr><th>Ref</th><th>Role</th><th>Board</th>"
                 "<th>Cols</th><th>Pins</th></tr></thead><tbody>")
    for ref in sorted(chips, key=lambda k: (chips[k][0], chips[k][1])):
        b, c, p = chips[ref]
        parts.append(f'<tr><td class="r">{html.escape(ref)}</td>'
                     f"<td>{html.escape(roles.get(ref, '—'))}</td>"
                     f'<td class="m">{b + 1}</td>'
                     f'<td class="m">{c}–{c + chip_cols(p) - 1}</td>'
                     f'<td class="m">{p}</td></tr>')
    parts.append("</tbody></table></div></section>")

    verdict = ("This board order is already the cheapest of the "
               f"{_fact(nb)} possible orders."
               if list(perm) == list(range(nb)) else
               f"A cheaper order exists: put the boards in the sequence "
               f"{' → '.join(str(p + 1) for p in perm)}, which costs "
               f"{pcost} hops instead of {r['cost']}.")
    parts.append('<section><h2>Board order</h2><div class="callout"><p>'
                 + html.escape(verdict) +
                 "</p><p>Cost counts one hop per net per board boundary it "
                 "crosses, so a net living on one board is free and a net "
                 "spanning two boards costs two.</p></div></section>")
    parts.append("</div>")
    return "\n".join(parts)


def _fact(n):
    f = 1
    for i in range(2, n + 1):
        f *= i
    return f


# ---- cli ----------------------------------------------------------------
SLOTHDR = os.path.normpath(os.path.join(
    HERE, "..", "..", "tests", "dino_bringup", "src", "slotmap_gen.h"))


def emit_slotmap(all_slots, path):
    """Breakout-strip slot numbers, per module, as a PROGMEM table the rig
    links in — so `pins <mod>` prints the same slot the layout page does
    and the two can never disagree. Same contract pinmap_gen.h holds."""
    lines = ["/* GENERATED by docs/notes/layout_gen.py — do not edit.",
             "   Regenerate: python3 docs/notes/layout_gen.py <module> */",
             "#ifndef SLOTMAP_GEN_H", "#define SLOTMAP_GEN_H",
             "#include <stdint.h>", "#include <avr/pgmspace.h>", "",
             "typedef struct { const char *signal; uint8_t slot; } slotsig_t;",
             "typedef struct { const char *module; const slotsig_t *sig;",
             "                 uint8_t n; } slotmap_t;", ""]
    interned, strdefs, blocks, mods = {}, [], [], []

    def sym(t):
        if t not in interned:
            interned[t] = f"sl_s{len(interned)}"
            strdefs.append(f'static const char {interned[t]}[] PROGMEM = "{t}";')
        return interned[t]

    for module in sorted(all_slots):
        rows = sorted(all_slots[module].items())
        if not rows:
            continue
        arr = ",\n    ".join(f"{{{sym(sig)}, {slot}}}" for sig, slot in rows)
        blocks.append(f"static const slotsig_t slot_{module}[] PROGMEM = "
                      f"{{\n    {arr}\n}};")
        mods.append((module, len(rows)))
    arr = ",\n    ".join(f"{{{sym(m)}, slot_{m}, {n}}}" for m, n in mods)
    lines += strdefs + [""] + blocks + [
        "", f"static const slotmap_t SLOTMAPS[] PROGMEM = {{\n    {arr}\n}};",
        f"#define SLOTMAP_COUNT {len(mods)}", "", "#endif", ""]
    open(path, "w").write("\n".join(lines))


def main(argv):
    if "--list" in argv or not argv:
        for m, p in PLACEMENTS.items():
            print(f"{m}: {len(p['chips'])} chips, {board_count(p['chips'])} boards")
        return 0
    module = argv[0]
    spec = PLACEMENTS.get(module, {})
    nets = load_nets(force="--force-export" in argv)
    width = spec.get("width", BOARD_WIDTH)

    if "--auto" in argv:
        refs = set(spec.get("chips", {}))
        if not refs:
            print(f"no chip list for {module}: add one to PLACEMENTS first")
            return 1
        chips = auto_place(pins_of(nets, refs), nets, width)
        print(f"auto-placed {len(chips)} chips onto {board_count(chips)} board(s)")
    else:
        chips = spec.get("chips")
        if not chips:
            print(f"unknown module {module!r} — try --list")
            return 1

    bad = overlaps(chips) or off_board(chips, width)
    if bad:
        print(f"PLACEMENT INVALID: {bad}")
        return 1

    r = analyse(chips, nets)
    perm, pcost = best_order(chips, nets)
    print(f"{module}: {len(chips)} chips on {board_count(chips)} board(s)")
    print(f"  {len(r['local'])} nets stay on one board")
    print(f"  {r['cost']} board hops, {len(r['spanning'])} spanning net(s)")
    for (a, b), ns in sorted(r["bundles"].items()):
        print(f"  board {a + 1} <-> {b + 1}: {len(ns):2d}  "
              f"{', '.join(_short(n) for n in ns[:6])}"
              f"{' ...' if len(ns) > 6 else ''}")
    if r["spanning"]:
        print(f"  SPANNING: {', '.join(_short(n) for n in r['spanning'])}")
    if list(perm) != list(range(board_count(chips))):
        print(f"  cheaper order available: {[p + 1 for p in perm]} -> {pcost} hops")

    strip = breakout_plan(chips, nets, rig_signals(module), width, module)
    if strip:
        nlink = sum(1 for r in strip if len(r[2]) > 1)
        print(f"  breakout strip: {len(strip)} slots ({nlink} also relay a link)")

    # slot table for the firmware: every signal the rig touches that has
    # a strip slot, keyed by the pinmap's own signal spelling
    pm = rig_pins(module)
    slots = {}
    for rt in strip_routes(chips, nets, rig_signals(module), module):
        for key in pm:
            if rt["net"] in key.split("="):
                slots[key] = rt["slot"]
    existing = {}
    if os.path.exists(SLOTHDR):
        txt = open(SLOTHDR).read()
        st = dict(re.findall(r'static const char (sl_s\d+)\[\] PROGMEM = "(.*)";', txt))
        for m in re.finditer(r'static const slotsig_t slot_(\w+)\[\] PROGMEM = \{(.*?)\};', txt, re.S):
            existing[m.group(1)] = {
                st[a]: int(b) for a, b in
                re.findall(r'\{(sl_s\d+), (\d+)\}', m.group(2))}
    existing[module] = slots
    emit_slotmap(existing, SLOTHDR)
    print(f"  wrote {len(slots)} slot numbers -> {SLOTHDR}")

    os.makedirs(OUTDIR, exist_ok=True)
    out = os.path.join(OUTDIR, f"{module}.html")
    with open(out, "w") as f:
        f.write(render(module, chips, nets, spec, width))
    print(f"  wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
