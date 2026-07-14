# DINO ALU hardware: 2x 74F382 design notes

Machine: DINO v0.0.3, new sheet (alu.kicad_sch placeholder exists on the root sheet)
Status: architecture CONVERGED 2026-07-13 — shadow-register operands (Rico's
design). Not yet drawn. Companions: dino_121_elimination_plan.md (clock
discipline), dino_register_conversion.md (register boards + shadow
invariant), dino_design_notes.md (operand architecture decision record).

---

## 0. Architecture summary

Two 74F382 4-bit ALU slices cascade to 8 bits. Operands come from two SHADOW
REGISTERS on this sheet — TMP_A and TMP_B, '373s whose D pins listen on the
W bus and whose latch enables fire on the same decodes as REG_A and REG_B.
Every dst=A state loads A and TMP_A identically; TMP_x ≡ REG_x by
construction. The F382s read the shadows point-to-point (Q → ports, one
driver, one listener, no buffers). The register boards are untouched and the
ALU adds no cross-board operand wiring: everything rides the W bus backbone.

An ALU instruction is one execute state: select the function, output latch
freezes the result at the mid-state falling edge, destination (and its
shadow) capture on the closing edge. No staging states, no control codes
spent on the shadows.

History (see design_notes for full rationale): dedicated always-driven taps
rejected (required tearing up verified register topology + 16 cross-board
wires); 8008-style microcode-addressable temps rejected (2 staging states +
both free [8:6] codes). Shadows take the best of both.

## 1. The function table ([11:9], constitution-final)

DATASHEET READING TRAP: the '382 select table prints columns S0, S1, S2
left-to-right - LSB FIRST. Read carefully. Also old notation: A(+)B circled
is XOR; "A + B" in the logic rows is OR; "A Plus B" spelled out is ADD; AB is AND.

Corrected mapping, written S2:S1:S0 as the control word holds it:

    [11:9]  S2 S1 S0   op              instruction
     000     L  L  L   Clear           CLR   A = 0x00   (free)
     001     L  L  H   B minus A       BSUB  A = B - A  (free)
     010     L  H  L   A minus B       SUB   A = A - B
     011     L  H  H   A plus B        ADD   A = A + B
     100     H  L  L   A XOR B         XOR
     101     H  L  H   A OR B          OR
     110     H  H  L   A AND B         AND
     111     H  H  H   Preset          SET   A = 0xFF   (free)

("A" and "B" here mean TMP_A and TMP_B — identical to REG_A/REG_B by the
shadow invariant.)

Casualties from the old paper table: DISABLED (the '382 has no disabled
state; S=000 computes zero - "ALU quiet" is the output latch's job), PASS
(no such '382 function; src=REG_A covers it), COND (relocated to [8:6]=011).

WIRING: control word bit 11 -> S2, bit 10 -> S1, bit 9 -> S0, both slices in
parallel. A swapped select line maps every op to a DIFFERENT VALID OP - the
nastiest miswire class. See section 7 test 1 for the disambiguator.

## 2. Shadow registers TMP_A, TMP_B (the operand source)

    TMP_A 74LS373
      D0-D7   = W bus, direct (inputs are listeners — no buffer needed;
                IR does exactly this on the verified MDR/IR sheet)
      Q0-Q7   = F382 A ports (low slice bits 0-3, high slice 4-7),
                point-to-point wires, OE = GND
      LE      = NOR(/REG_A_LOAD, CLK) — own stamp gate on this sheet,
                same input NETS as the register board's LE_A stamp
    TMP_B: identical, /REG_B_LOAD, F382 B ports.

SHADOW INVARIANT: TMP_x captures on EVERY dst=x state including ALU
writebacks (A and TMP_A latch the same frozen W on the same edge). Chained
arithmetic depends on this — a shadow that skipped writebacks would feed
the next SUB stale operands. Both registers are garbage before the first
load, same as v0.0.2 semantics; microcode loads before it computes.

Trade accepted: the ALU computes on A,B only. Any-pair ops (ADD B,C) are a
MOV-through idiom in microcode. Accumulator-machine standard.

## 3. Cascading two slices

- Low slice: bits 0-3 of TMP_A, TMP_B, F. High slice: bits 4-7.
- Low slice Cn+4 (ripple carry out) -> high slice Cn.
- High slice Cn+4 -> C input of the flags '173 (section 5).
- High slice OVR = signed overflow (V flag) - free; route it somewhere
  probeable now, unreachable after layout.
- Low slice Cn = carry-in for the whole 8-bit ALU (section 4).
- F-family speed: ~15ns full 8-bit result. The EEPROMs own the ceiling.
- F inputs are TTL-compatible with LS drivers; keep F-to-latch traces short.

## 4. Carry-in (Cn) - op-dependent, not optional

The '382 computes subtraction as A + /B + Cn. Therefore:
    SUB (010) and BSUB (001) REQUIRE Cn = 1; ADD (011) wants Cn = 0;
    logic ops ignore Cn.

    Cn = XOR(S1, S0) = XOR(bit10, bit9)

Check: 001 -> 1 ok. 010 -> 1 ok. 011 -> 0 ok. Logic rows: don't-care.
Hardware: one XOR — 4x NAND spares or a new '86 (spares useful for flags).
Wire to LOW slice Cn only; high slice Cn comes from the cascade.
FUTURE parking: ADC/SBC = mux stored C into Cn. Only if multi-byte speed
ever matters.

## 5. Flags register ('173, falling-edge capture)

    C <- high slice Cn+4;  Z <- NOR8 of F382 F pins;  V <- OVR (free bit)

    74LS173: CP = /CLK (rising of /CLK = mid-state falling edge of CLK),
    /IE = /ALU_OUT, output OEs grounded (flags feed dedicated COND logic).

WHY THE FALLING EDGE: in the second half of an ALU state TMP_A goes
transparent (it shadows dst=A) and the F382 recomputes ~40ns later — C/V go
stale. At the falling edge the F pins still reflect old operands (the value
being committed). Setup: F settled ~200ns into the first half. Hold: ~40ns
before F can move vs ~10ns required.

CAPTURE RULE: flags capture ONLY when src=ALU, ON the falling edge. With no
DISABLED code the S pins always compute something; ungated capture would
clobber Z between SUB and JNZ. Constitution header: "ALU ops (src=ALU
states) update Z and C (and V if wired) at the falling edge; nothing else
touches flags."

Z-detect gate choice still open: 'LS260+gate, 2x 'LS25+AND, or 'LS30 games.
Pick by spares; record here: ____________

## 6. Output latch (the ALU sheet's only bus driver)

'382 F outputs have no tri-state; a buffer was always required. It is a
74LS373 — buffer + the master latch that breaks the writeback loop:

    D = F[7:0];  LE = CLK, DIRECT (zero gates);  Q = W bus
    /OE = /ALU_OUT ([5:3]=110, U28 — verify designator/pin on control
          sheet and record: ____________)

Transparent the whole first half (tracks F while shadows are stable),
freezes at the falling edge, holds through the second half while the
destination AND its shadow track the frozen value.

MASTER/SLAVE INVARIANT: output latch transparent iff CLK HIGH; every
destination latch (registers and shadows) transparent iff CLK LOW; never
both. During ADD's second half, TMP_A tracks the frozen W, the F382
recomputes from new TMP_A, and hits this closed latch. The loop always
contains one closed door. In non-ALU states the latch captures whatever
[11:9] computes behind a disabled /OE - ripple nobody samples.

MICROCODE IMPACT: none. ADD = T0 (0x600E) + T1 (0x1631). Timing rule: ALU
result must settle by the FALLING edge — '163 (~14) + EEPROM (~150) + F382
(~15) + latch (~18) ≈ 200ns vs 500ns half-period at 1MHz.

## 7. Bring-up test plan (jumper-driven, no microcode EEPROM required)

Fixture: force TMP_A/TMP_B via the W-bus switch rig + manual stamp inputs
(or DIP switches on the shadow D nets), LEDs on W bus, S pins jumpered.
For tests 1-5, hold CLK HIGH so the output latch is transparent.

1. DIRECTION ANCHORS FIRST: S=000 -> W reads 0x00; S=111 -> 0xFF. Catches
   swapped or stuck select lines before any arithmetic is trusted.
2. ADD: 0x05+0x03 -> 0x08. Then 0xFF+0x01 -> 0x00 with C set (cascade and
   carry capture in one shot).
3. SUB: 0x05-0x03 -> 0x02; RECORD observed carry polarity on subtract
   (/borrow expected) and define JC semantics in the constitution: ________
4. BSUB: same operands -> 0xFE.
5. XOR/OR/AND: one vector each, e.g. A=0xAA B=0x0F -> 0xA5 / 0xAF / 0x0A.
6. Z FLAG: a zero result sets Z; nonzero clears; Z must NOT change when
   src != ALU (capture gate working).
7. LATCH HALVES: /ALU_OUT=0. CLK high: wiggle operands -> W follows.
   CLK low: wiggle -> W FROZEN. Master/slave on two probes.
8. SHADOW INVARIANT: wire to the real register boards; run LDAI, ADD, LDA
   sequences single-stepped; probe TMP_A vs REG_A after every edge — always
   equal after any dst=A state, INCLUDING the ADD writeback.
9. FEEDBACK SAFETY: single-step ADD with B=1 — A increments by EXACTLY 1
   per state. A jump >1 means a transparent path survived.
10. FLAGS EDGE: flags move only on falling edges of src=ALU states.

## 8. Open questions (decide before drawing the sheet)

1. RESOLVED (drawn, netlist-audited 2026-07-13): Z-detect is NOT '260/'25/'30
   — no '260 in stock. Built from De Morgan identity using ONLY 2-input
   gates already on the sheet: NOT(x1|x2|x3|x4) = NOR(x1,x2) AND NOR(x3,x4).
   U52 (quad '02): F01=NOR(F0,F1), F23=NOR(F2,F3), F45=NOR(F4,F5),
   F67=NOR(F6,F7) — all 4 gates used. U53 (quad '08): F0123=AND(F01,F23),
   F4567=AND(F45,F67), Z=AND(F0123,F4567) — 3 of 4 gates used, 1 spare.
2. RESOLVED: flags storage is '273, NOT '173 — no '173 in stock. '273 has
   no load-enable pins (unlike '173's M/N), so a 74LS157 (quad 2:1 mux, U48)
   sits ahead of the D inputs: I0=new flag value, I1=Q fed back to itself,
   S=/ALU_OUT direct (active-low S selects I0 during a real commit — no
   inverter needed, get the I0/I1 assignment backwards and flags freeze on
   every IDLE cycle instead of every ALU cycle). CP=/CLK (unchanged reasoning
   from below), Mr=/RESET (74LS273 has async active-low clear — a genuine
   upgrade over '173, costs nothing). V flag wired (FLAG_V, ALU_V from high
   slice OVR) — yes, wired now, per the original "free if wired now" note.
3. SUB borrow polarity -> JC/JNC semantics (section 7 test 3) — still open,
   needs bench observation, unchanged.
4. Output latch part SETTLED ('373); /ALU_OUT designator = U47's /OE,
   confirmed on the drawn sheet.
5. RESOLVED: Cn is NOT built from XOR/'86 — turns out you don't need XOR at
   all. Required truth table only constrains 3 of 4 (SA1,SA0) pairs (CLR is
   don't-care, Cn doesn't touch a clear op), and NAND(SA1,SA0) satisfies all
   three (BSUB=1, SUB=1, ADD=0) — XOR and NAND only differ at (0,0), which is
   exactly the don't-care slot. Built from a spare AND gate (U53, 4th gate,
   pins 12/13->11, was dead/grounded) feeding a spare NOR-as-inverter (U50,
   4th gate, pins 11/12 tied together ->13) — zero new chips. Net:
   ALU_CIN = NOR(AND(SA1,SA0), AND(SA1,SA0)) = NAND(SA1,SA0).
6. Do BSUB/CLR/SET earn opcodes in v0.0.3, or stay documented-but-unassigned?
   Still open — not touched this session; the control word's [11:9] field
   wires straight to SA[2:0] either way, so this is a microcode-assignment
   decision, not a hardware one.

Full pin-level wiring for all of the above: see dino_session_state.md,
"ALU sheet (COMPLETE)".

---

Sequencing: register boards get stamps + '08 (small diff, conversion doc §2),
then this sheet gets drawn — 2x F382, TMP_A, TMP_B, output latch, flags '173,
Cn XOR, Z-NOR — and the machine can ADD TWO NUMBERS AND SHOW THEM, one bench
session from the countdown demo.
