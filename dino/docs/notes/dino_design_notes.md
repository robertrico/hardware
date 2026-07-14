# DINO design notes: deferred decisions and settled philosophy

Running notes for decisions that are settled in principle but not yet (or not ever)
implemented in hardware. Companion to the constitution and the three build docs.

---

## ALU operand architecture (FINAL 2026-07-13): shadow registers

Three candidates were worked through in conversation; recording all three so
this never gets re-litigated from scratch.

REJECTED — dedicated taps ("spatial"): ground register OEs so A Bus/B Bus are
always driven, ALU taps them point-to-point. Sound, but tears up the verified
v0.0.2 register topology (D pins move to the W bus, '245s become one-way) and
strings ~16 operand wires across boards. Died on: rewiring cost + mental-model
mismatch.

REJECTED — microcode-addressable temps ("temporal", pure 8008): TMP_A/TMP_B
loaded by explicit microcode via the two free [8:6] codes. Registers keep
v0.0.2 wiring; feedback hazard vanishes; any-pair ALU ops. Died on: 2 staging
states per ALU op AND spending both free misc codes — the last expansion room
in that field.

ADOPTED — SHADOW REGISTERS (Rico's synthesis): TMP_A/TMP_B '373s on the ALU
sheet, D pins listening on the W bus, latch enables fired by the SAME
/REG_A_LOAD//REG_B_LOAD decodes as the real registers. Every dst=A state
loads A and TMP_A with the same value on the same edge: TMP_x ≡ REG_x by
construction. Zero control codes, zero staging states, zero register-board
rewiring, no cross-board operand wires (everything rides the W bus backbone).

INVARIANT (do not "optimize"): shadows capture on EVERY dst=x state INCLUDING
ALU writebacks. A shadow that skipped writebacks goes stale and breaks chained
arithmetic (countdown loop: SUB;JNZ;SUB must see current A). Both real and
shadow are garbage before first load — same as v0.0.2 semantics.

Feedback safety: during an ALU writeback's second half TMP_A is transparent
and feeds the F382 — the loop is broken by the ALU OUTPUT LATCH (LE=CLK,
master/slave), not by the shadows. The output latch was required anyway as
the '382s' bus buffer.

Trade accepted: ALU computes on A,B only; ADD B,C = MOV-through idiom.
Revisit trigger: if register pressure makes MOV-through painful (monitor/
toolchain era), the temporal design's staging codes are the upgrade path —
and by then a third parallel EEPROM (control word +8 bits, same addresses)
is a reasonable ask.

## Illegal microword defense (settled 2026-07-12, revisit at monitor/toolchain era)

The two-field encoding leaves one expressible-but-illegal class: src and dst naming
the same device. Register self-copy (src=REG_x, dst=REG_x) is benign - a wasteful
NOP, A=A (the '245 turns around, the latch recaptures its own value; shadows
recapture identically). RAM self-copy (src=RAM_OUT, dst=RAM_LOAD) is a REAL
corruption: /WE dominates /OE on SRAM, the chip stops driving mid-state, and the
write commits whatever the abandoned bus floats to. Garbage written to [MAR].

SECOND expressible-but-illegal class (caught 2026-07-12, Rico's contention
review of the '245 fleet): the six W-bus source enables (/ROM_OUT, /RAM_OUT,
/REG_A/B/C_OUT, /ALU_OUT) all come from U28 - one-hot by silicon, two W-bus
drivers UNREPRESENTABLE within the src field. But /MDR_OUT (replay) lives on
U29, the misc-field '138. A word asserting [8:6]=100 (/MDR_OUT) together with
any [5:3] != NONE puts TWO drivers on the W bus. The silicon cannot exclude
it; the builder must (assert below). Same defense philosophy: the only
source of such a word is EEPROM contents.

Considered and REJECTED: hardware interlock (e.g. OR-ing a detected illegal state
into HALT). Reasons:
- The detector would watch decode lines whose ripple the whole design is built to
  ignore; a level-family signal feeding the clock stop mixes the edge/level
  categories and creates a new false-halt failure mode.
- The only source of an illegal word is EEPROM contents; the builder already
  refuses to emit one. Hardware would defend against corrupted burns only, and
  burn verification (programmer readback) covers that directly.
- A flipped bit in a LEGAL row (ADD becomes OR) is undetectable by any interlock
  anyway - the defense has to live upstream of the silicon regardless.

ADOPTED: four layers, zero gates, each defense where it is cheapest:
1. STRUCTURE  - field encoding: bus fights unrepresentable.
2. POLICY     - C microcode builder asserts (list below).
3. RECOVERY   - safe-fill: every unwritten microcode row = NOP+END (0x1000),
                so any runaway lands on a fetch within one state.
4. VERIFICATION - Arduino contract tests per sheet; EEPROM burn readback/verify
                every burn.

Revisit trigger: when the toolchain era arrives (assembler, monitor, self-hosted
EEPROM writes), the POLICY layer moves partly into those tools - the monitor's
EEPROM-write path should enforce the same asserts as the offline builder, or
self-hosted microcode updates lose layer 2.

## Builder assert list (grows as the constitution grows)

- src device == dst device -> ERROR (RAM case corrupts; register case pointless)
- src == REG_x AND dst == same REG_x -> WARNING (probable MOV typo)
- [8:6] == /MDR_OUT AND [5:3] != NONE -> ERROR (two W-bus drivers: replay
  path enables MDR's OE from U29, outside the U28 one-hot guarantee)
- PC_UP AND PC_LOAD same word -> ERROR (defined-but-fragile on '193 internals)
- opcode block with no END before T15 -> ERROR (instruction runs into safe-fill)
- total PC_UP count per instruction != instruction byte length -> WARNING
  (catches operand-skip / double-fetch bugs at build time)
- any word asserting IR_LOAD outside T0 -> ERROR (IR changes only at fetch)
- T0 row of every opcode != universal fetch word 0x600E -> ERROR

## Deferred hardware, parking spaces reserved

- ADC/SBC: mux stored C flag into ALU Cn (replaces XOR-derived constant).
  Requires nothing else. Only if multi-byte arithmetic speed ever matters.
- MAR upgrade '373s -> '163s: buys MAR++ for indirect addressing era. Sheet
  layout should leave room. Would want a misc-field code or a third-EEPROM
  control bit for the count strobe.
- Indirect addressing: pointer-walk microcode with byte buffer (REG_C clobber,
  documented) or hidden temp '373. Hazard walk already done - see conversation
  notes 2026-07-11: last byte read must be first byte committed.
- IN port: '244/'541 from outside world onto W bus, source code [5:3]=111 (the
  reserved slot). Prerequisite for the monitor. When wired, its enable joins
  the U28 one-hot family - structurally safe, no new assert needed.
- COND qualifier gate: [8:6]=011 decode gates PC_LOAD (and optionally END) on
  selected flag. Flag-select encoding not yet designed - decide when JNZ is
  wired whether Z-only suffices for v0.0.3 (it does for the countdown demo).
- Third parallel EEPROM: +8 control word bits on the same address lines —
  the standing relief valve if [8:6] ever fills (monitor strobes, MAR++,
  flag-select).
