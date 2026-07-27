#!/usr/bin/env python3
"""DINO microcode ROM image generator.

Symbolic instruction table (dino_session_state.md "Instruction microwords")
-> U9.bin (word[7:0] = CW0-7) + U15.bin (word[15:8] = CW8-15), the diag
image pair, printed per-chip CRC16s, and the rig's expect header
(tests/dino_bringup/src/microcode_expect.h) so rig and ROM can never
disagree.

Address = {IR[7:0], T[3:0]} = opcode*16 + T. 4096 rows; A12 is grounded on
the board, so each 8K AT28C64B carries the image twice (mirrored halves).

Hard rules (session state, decision item 3 + HALT rule change 2026-07-14):
  - ALL 4096 rows programmed; unused rows = SAFE-FILL 0x1000 (END).
  - T0 of ALL 256 opcodes = universal fetch 0x600E.
  - HALT word = 0x8000, bit15 only, NO END bit.

Diag image (test spec "ROM images"): word = own 12-bit address in [11:0],
INVERTED top address nibble in [15:12] — catches stuck-high data lines.

Builder asserts implement the list in dino_design_notes.md ("Builder
assert list") — the POLICY layer of the four-layer defense.

Run: python3 microcode_gen.py            (writes roms/ + expect header)
Test: python3 test_microcode_gen.py
"""
import os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROMS = os.path.normpath(os.path.join(HERE, "..", "..", "roms"))
HDR = os.path.normpath(os.path.join(
    HERE, "..", "..", "tests", "dino_bringup", "src", "microcode_expect.h"))

# ---- control word bit map (session state, v0.0.3, COMPLETE) ------------
HALT_BIT = 1 << 15          # raw tap, active high
MUX_PC = 1 << 14            # PC_MAR_MUX: PC=1, MAR=0
PC_UP = 1 << 13             # raw tap
END = 1 << 12               # raw tap

SA = {"CLR": 0b000, "BSUB": 0b001, "SUB": 0b010, "ADD": 0b011,
      "XOR": 0b100, "OR": 0b101, "AND": 0b110, "SET": 0b111}  # [11:9]

MISC = {"NONE": 0b000, "PC_CLEAR": 0b001, "PC_LOAD": 0b010, "COND": 0b011,
        "MDR_OUT": 0b100, "REG_OUT_LOAD": 0b110}              # [8:6] U29

SRC = {"NONE": 0b000, "ROM": 0b001, "RAM": 0b010, "REG_A": 0b011,
       "REG_B": 0b100, "REG_C": 0b101, "ALU": 0b110, "SW": 0b111}  # [5:3] U28

DST = {"NONE": 0b000, "REG_A": 0b001, "REG_B": 0b010, "REG_C": 0b011,
       "MAR_LO": 0b100, "MAR_HI": 0b101, "IR": 0b110, "RAM": 0b111}  # [2:0] U30


def word(mux_pc=False, pc_up=False, end=False, halt=False,
         sa=None, misc="NONE", src="NONE", dst="NONE"):
    w = 0
    if halt: w |= HALT_BIT
    if mux_pc: w |= MUX_PC
    if pc_up: w |= PC_UP
    if end: w |= END
    if sa is not None: w |= SA[sa] << 9
    w |= MISC[misc] << 6
    w |= SRC[src] << 3
    w |= DST[dst]
    return w


FETCH = word(mux_pc=True, pc_up=True, src="ROM", dst="IR")   # 0x600E
FILL = word(end=True)                                        # 0x1000, END

# ---- opcode assignments -------------------------------------------------
# PROPOSED TABLE (2026-07-16). Only LDAI=0x11 is documented (addressing
# example in dino_session_state.md) — everything else is a fresh assignment:
# high nibble = family (0=ctl, 1=imm loads, 2=memory, 3=flow, 4=ALU, 5=io),
# HALT=0xFF so an ERASED program EEPROM (all 0xFF) halts instead of raving.
# Renumbering = edit here, rerun, reburn; the rig follows via the header.
OPCODES = {
    "NOP": 0x00,
    "LDAI": 0x11, "LDBI": 0x12, "LDCI": 0x13,
    "LDA": 0x21, "STA": 0x22,
    "JMP": 0x31, "JNZ": 0x32,
    "ADD": 0x41, "SUB": 0x42, "AND": 0x43, "OR": 0x44,
    "XOR": 0x45, "CLR": 0x46, "SET": 0x47, "BSUB": 0x48,
    "OUT": 0x51,
    "HALT": 0xFF,
}

# operand-fetch prefix shared by every MAR-consuming instruction:
# T1 -> MAR_LO, T2 -> MAR_HI (both fetch a byte, PC++)
_MARFILL = [word(mux_pc=True, pc_up=True, src="ROM", dst="MAR_LO"),   # 0x600C
            word(mux_pc=True, pc_up=True, src="ROM", dst="MAR_HI")]   # 0x600D


def _alu(op):
    return [word(end=True, sa=op, src="ALU", dst="REG_A")]


# instruction -> (byte length, [T1, T2, ...]); T0 is implicit FETCH
INSTRUCTIONS = {
    "NOP": (1, [word(end=True)]),
    "LDAI": (2, [word(mux_pc=True, pc_up=True, end=True, src="ROM", dst="REG_A")]),
    "LDBI": (2, [word(mux_pc=True, pc_up=True, end=True, src="ROM", dst="REG_B")]),
    "LDCI": (2, [word(mux_pc=True, pc_up=True, end=True, src="ROM", dst="REG_C")]),
    "LDA": (3, _MARFILL + [word(end=True, src="RAM", dst="REG_A")]),
    "STA": (3, _MARFILL + [word(end=True, src="REG_A", dst="RAM")]),
    "JMP": (3, _MARFILL + [word(end=True, misc="PC_LOAD")]),
    "JNZ": (3, _MARFILL + [word(end=True, misc="COND")]),
    "ADD": (1, _alu("ADD")), "SUB": (1, _alu("SUB")),
    "AND": (1, _alu("AND")), "OR": (1, _alu("OR")),
    "XOR": (1, _alu("XOR")), "CLR": (1, _alu("CLR")),
    "SET": (1, _alu("SET")), "BSUB": (1, _alu("BSUB")),
    "OUT": (1, [word(end=True, misc="REG_OUT_LOAD", src="REG_A")]),
    "HALT": (1, [word(halt=True)]),
}


# ---- builder asserts (POLICY layer, dino_design_notes.md list) ----------
class BuildError(Exception):
    pass


def _fields(w):
    return ((w >> 6) & 7, (w >> 3) & 7, w & 7)   # misc, src, dst


def check_word(addr, w):
    """Per-word legality. addr names the row in errors."""
    misc, src, dst = _fields(w)
    where = f"row {addr:#05x} word {w:#06x}"
    # src device == dst device (RAM corrupts; register case is the warning)
    if src == SRC["RAM"] and dst == DST["RAM"]:
        raise BuildError(f"{where}: src=RAM dst=RAM")
    for r in ("REG_A", "REG_B", "REG_C"):
        if src == SRC[r] and dst == DST[r]:
            print(f"WARNING {where}: src=dst={r} (probable MOV typo)")
    # /MDR_OUT replay + any U28 source = two W-bus drivers
    if misc == MISC["MDR_OUT"] and src != SRC["NONE"]:
        raise BuildError(f"{where}: /MDR_OUT with src!=NONE (W-bus fight)")
    # PC_UP + PC_LOAD same word: defined-but-fragile on '193 internals
    if (w & PC_UP) and misc == MISC["PC_LOAD"]:
        raise BuildError(f"{where}: PC_UP with /PC_LOAD")
    # IR changes only at fetch
    if dst == DST["IR"] and (addr & 0xF) != 0:
        raise BuildError(f"{where}: IR_LOAD outside T0")
    # T0 row of every opcode is the universal fetch
    if (addr & 0xF) == 0 and w != FETCH:
        raise BuildError(f"{where}: T0 row is not the fetch word {FETCH:#06x}")


def check_table(words):
    """Whole-image legality: per-word checks + per-opcode block shape."""
    assert len(words) == 4096
    for a, w in enumerate(words):
        check_word(a, w)
    for op in range(256):
        block = words[op * 16:op * 16 + 16]
        # an instruction must END (or HALT-freeze) before running off its
        # last defined state into safe-fill. Safe-fill is itself END, so
        # scan T1..last-non-fill row: that word must carry END or HALT.
        states = [w for w in block[1:] if w != FILL]
        if states and not (states[-1] & (END | HALT_BIT)):
            raise BuildError(f"opcode {op:#04x}: last state "
                             f"{states[-1]:#06x} has no END/HALT")


def _check_lengths():
    for name, (nbytes, states) in INSTRUCTIONS.items():
        ups = sum(1 for w in [FETCH] + states if w & PC_UP)
        if ups != nbytes:
            print(f"WARNING {name}: PC_UP count {ups} != byte length {nbytes}")


# ---- images -------------------------------------------------------------
def build_real():
    words = [FILL] * 4096
    for op in range(256):
        words[op * 16] = FETCH
    for name, (_, states) in INSTRUCTIONS.items():
        base = OPCODES[name] * 16
        for t, w in enumerate(states, start=1):
            words[base + t] = w
    _check_lengths()
    check_table(words)
    return words


def build_diag():
    return [a | ((~(a >> 8) & 0xF) << 12) for a in range(4096)]


def crc16(data):
    """CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF. Mirrors src/crc16.c."""
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021 if crc & 0x8000 else crc << 1) & 0xFFFF
    return crc


def split(words):
    lo = bytes(w & 0xFF for w in words)      # U9  = CW0-7
    hi = bytes(w >> 8 for w in words)        # U15 = CW8-15
    return lo, hi


def _mirror(half):                            # A12 grounded: 2x the image
    return half + half


def emit_header(real, crcs, path):
    lines = [
        "/* GENERATED by microcode_gen.py — do not hand-edit.",
        "   Regenerate: python3 docs/notes/microcode_gen.py */",
        "#ifndef MICROCODE_EXPECT_H",
        "#define MICROCODE_EXPECT_H",
        "#ifdef __AVR__",
        "#include <avr/pgmspace.h>",
        "#else",
        "#define PROGMEM",
        "#endif",
        "#include <stdint.h>",
        "",
        "/* image-detect signatures: row 0 of each burn */",
        f"#define MC_REAL_ROW0 0x{real[0]:04X}",
        f"#define MC_DIAG_ROW0 0x{build_diag()[0]:04X}",
        "",
        "/* CRC-16/CCITT-FALSE over the 4096 addressable bytes per chip */",
    ]
    for name, val in crcs.items():
        lines.append(f"#define {name} 0x{val:04X}")
    lines += [
        "",
        "/* diag word is a pure function of its row (test spec, ROM images):",
        "   addr[11:0] in the data, INVERTED addr[11:8] in [15:12] */",
        "#define MC_DIAG_WORD(a) ((uint16_t)(((a) & 0x0FFF) | "
        "((uint16_t)(~((a) >> 8) & 0xF) << 12)))",
        "",
        "/* the shipped real image, row-addressable for bench diagnostics */",
        "static const uint16_t MC_REAL_WORDS[4096] PROGMEM = {",
    ]
    for i in range(0, 4096, 8):
        row = ", ".join(f"0x{w:04X}" for w in real[i:i + 8])
        lines.append(f"    {row},")
    lines += ["};", "", "#endif", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))


def main():
    real, diag = build_real(), build_diag()
    os.makedirs(ROMS, exist_ok=True)
    crcs = {}
    for tag, words in (("REAL", real), ("DIAG", diag)):
        lo, hi = split(words)
        for chip, half in (("U9", lo), ("U15", hi)):
            fn = f"{chip}.bin" if tag == "REAL" else f"{chip}_diag.bin"
            with open(os.path.join(ROMS, fn), "wb") as f:
                f.write(_mirror(half))
            crcs[f"MC_CRC_{chip}_{tag}"] = crc16(half)
    emit_header(real, crcs, HDR)
    print(f"wrote 4x 8192B bins -> {ROMS}")
    print(f"wrote expect header -> {HDR}")
    print("burn order: DIAG pair first (addr/split tests), REAL pair second")
    print("  U9  = word[7:0]  = CW0-7   (low byte)")
    print("  U15 = word[15:8] = CW8-15  (high byte)")
    for name, val in crcs.items():
        print(f"  {name} = 0x{val:04X}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
