#!/usr/bin/env python3
"""Host test: contract-stamp position stickiness + power Value offsets.
Run: python3 test_kicad_stamp_position.py"""
import os, re, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import kicad_contracts as kc
import kicad_gen_sheet as kg

# ---- power symbol Value text: GND below the pin, up-family above ----
assert kg.power_value_dy("GND") > 0, "GND value must sit BELOW the pin"
assert kg.power_value_dy("+5V") < 0, "+5V value must sit ABOVE the pin"
assert abs(kg.power_value_dy("GND")) <= 5.1, "GND value drifted from the node"
assert abs(kg.power_value_dy("+5V")) <= 5.1, "+5V value drifted from the node"

# ---- stamp(): hand-moved block position must survive a restamp ----
def fake_project(tmp, child_body):
    root = os.path.join(tmp, "root.kicad_sch")
    child = os.path.join(tmp, "memory_t.kicad_sch")
    open(root, "w").write(
        '(kicad_sch\n'
        '\t(sheet\n\t\t(property "Sheetname" "Memory"\n\t\t)\n'
        '\t\t(property "Sheetfile" "memory_t.kicad_sch"\n\t\t)\n\t)\n)\n')
    open(child, "w").write(child_body)
    return root, child

CONTRACTS = {"/Memory/": {"IN": [("CLK", ["root"])], "OUT": [], "BIDIR": []}}

BLOCK_AT = re.compile(
    r'\(text "' + kc.MARK + r'[\s\S]*?\(at ([\d.]+) ([\d.]+)')

with tempfile.TemporaryDirectory() as tmp:
    # previously stamped block, hand-moved to (200, 42)
    old = ('(kicad_sch\n'
           '\t(wire\n\t\t(pts\n\t\t\t(xy 50 60) (xy 70 60)\n\t\t)\n\t)\n'
           '\t(text "' + kc.MARK + ' \\u2014 generated..."\n'
           '\t\t(exclude_from_sim no)\n'
           '\t\t(at 200 42 0)\n'
           '\t\t(effects\n\t\t\t(font\n\t\t\t\t(size 1.27 1.27)\n\t\t\t)\n'
           '\t\t\t(justify left bottom)\n\t\t)\n'
           '\t\t(uuid "x")\n\t)\n)\n')
    root, child = fake_project(tmp, old)
    kc.stamp(CONTRACTS, root)
    t = open(child).read()
    m = BLOCK_AT.search(t)
    assert m, "stamped block missing after restamp"
    assert (float(m.group(1)), float(m.group(2))) == (200.0, 42.0), \
        f"hand-moved position lost: got {m.group(1)},{m.group(2)}"
    assert t.count(kc.MARK) == 1, "old block not removed (duplicate stamp)"
    # restamp again: still exactly there, still exactly one
    kc.stamp(CONTRACTS, root)
    t = open(child).read()
    m = BLOCK_AT.search(t)
    assert (float(m.group(1)), float(m.group(2))) == (200.0, 42.0)
    assert t.count(kc.MARK) == 1

with tempfile.TemporaryDirectory() as tmp:
    # no previous block: heuristic placement below content, left margin
    fresh = ('(kicad_sch\n'
             '\t(wire\n\t\t(pts\n\t\t\t(xy 50 60) (xy 70 90)\n\t\t)\n\t)\n)\n')
    root, child = fake_project(tmp, fresh)
    kc.stamp(CONTRACTS, root)
    m = BLOCK_AT.search(open(child).read())
    assert m, "block not stamped on fresh sheet"
    assert float(m.group(1)) == 15.24 and float(m.group(2)) == 100.0, \
        f"heuristic placement changed: got {m.group(1)},{m.group(2)}"

print("OK test_kicad_stamp_position")
