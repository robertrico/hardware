# DINO register refactor: '121 elimination plan

Machine: DINO (Discrete Integrated Numeric Operator), v0.0.2 → v0.0.3
Scope: remove all 74LS121 monostables, convert all register loads to clock-phase-gated latch enables on 74LS373s, then validate one register end to end.

STATUS 2026-07-13: Phase 1 (MDR/IR) and Phase 2 memory site COMPLETE and
verified in KiCad (as-built details in dino_session_state.md — some gate
implementations differ from the plan below; the discipline does not).
Phase 2 PC site spec'd (dino_pc_193_integration.md). Phase 3 register
template SUPERSEDED by the converged design in
dino_register_conversion.md — summary patched into section 5 below.
Section 0's discipline is unchanged and now has one addendum (section 2b):
the falling edge earned a job.

---

## 0. The clock discipline (read first, everything follows from it)

One system clock, CLK. The 74LS163 sequencer advances on the RISING edge of CLK. Therefore:

- A T-state spans rising edge to rising edge.
- CLK is HIGH for the first half of every T-state, LOW for the second half.
- First half = settle time. The control word for this state has decoded, the source register's /OE is asserted, data propagates onto the bus. No register listens during this half.
- Second half = capture window. The destination register's latch goes transparent and tracks the now-stable bus.
- The next rising edge does two things simultaneously: closes the latch (capture) and advances the '163 (next state).

One edge per state. The latch-closing edge and the state-advancing edge are the same physical edge. There is no separate pulse, no RC, no monostable. That is the entire replacement for the '121.

## 1. The gating equation

For every register R with an active-low load select /R_LOAD (decoded from the control word load field by the '138):

    LE_R = NOR(/R_LOAD, CLK)

AS-BUILT NOTE: implemented as literal 74LS02 NOR gates (LE_IR = U22A set the
precedent), not the OR+inverter pair originally penciled here. Same truth
table, one gate instead of two. Output drives the '373 pin 11 (LE) directly:
LE on the '373 is ACTIVE HIGH, transparent while high, capture on falling
edge of LE (verified against the TI 'LS373 logic diagram).

Truth table:

    /R_LOAD  CLK  | LE_R | latch
       1      x   |  0   | holding (not selected)
       0      1   |  0   | holding (selected, bus settling)
       0      0   |  1   | transparent (selected, bus stable)
       0      0→1 |  1→0 | CAPTURE on this edge

## 2. Reference timing diagram (hand-copy this until it is reflex)

Two T-states. Tn selects MDR as destination. Tn+1 does not.

    state     |------- Tn -------|------ Tn+1 ------|

    CLK        ____              ____
              |    |            |    |
              |    |____________|    |______________

    /MDR_LOAD --\                  /----------------
                 \________________/
               ^ falls after '163+'138 tpd (~35ns)
                                  ^ rises after same tpd: this lag IS the hold margin

    LE_MDR                 _________
              ____________|         |_______________
                          ^ CLK fell + NOR tpd      
                                    ^ CAPTURE: falls on the rising edge

    W bus     ~settle~[=== source data valid ===]~~~
                      ^ source /OE + bus prop        

    MDR Q     [====== old value ======][== captured ==]

Checkpoints when drawing your own:
- LE_MDR is high ONLY during the second half of the selected state. Nowhere else, ever.
- The capture edge and the '163 clock edge are the same vertical line.
- /MDR_LOAD cannot change until that edge propagates through '163 then '138. That delay (~14ns + ~20ns on LS parts, datasheet typicals, verify against your actual parts) is what guarantees the '373's ~20ns hold requirement. The bus physically cannot move before hold is satisfied.
- Setup is trivially met: the latch was transparent and tracking for an entire half-period before the edge.

## 2b. The two-halves mental model (the thinking shift)

The old design had an "interphase pulse": between doing-things, a '121 fired to commit them. The new design has no interphase anything. The pulse IS the edge. Every T-state is one clock period with two halves and one committing edge:

    FIRST HALF (CLK high)   = the source's time.
      The entering edge already advanced the '163 (and PC, if PC_UP).
      Microcode decodes, source /OE asserts, data propagates and settles.
      Destination LE is held LOW by the NOR gate. Destination is deaf.

    SECOND HALF (CLK low)   = the destination's time.
      NOR raises LE, destination goes transparent, tracks the
      already-stable bus. Electrically nothing else moves.

    CLOSING RISING EDGE     = commitment. Three simultaneous jobs:
      LE falls  -> destination captures.
      '163 advances -> next state.
      PC increments (if this word set PC_UP) -> ready for next fetch.

Read every microword as three questions: who drives (first half), who
captures (second half), does it END (the edge).

ADDENDUM 2026-07-13 (shadow-register ALU, see alu doc): the MID-STATE
FALLING EDGE is now also a commitment edge, for the ALU domain only. In an
src=ALU state, the ALU output latch (LE=CLK) freezes the result and the
flags '173 (CP=/CLK) captures C/Z/V — both at the falling edge, computed
from OLD operands. Master/slave invariant: the output latch is transparent
iff CLK is HIGH; every destination latch (registers AND the ALU's shadow
registers) is transparent iff CLK is LOW; never both. Two commit edges per
state: falling = ALU + flags freeze; closing rising = destinations capture.

### Worked example: the old T0/T1 fetch collapsing to one state

Old: T0 = opcode to MDR (pulse), T1 = MDR to IR, PC++ (pulse).
New T0 = ROM out, IR load, PC++:

First half: PC -> M bus -> ROM tACC -> MDR D pins -> STRAIGHT THROUGH the
transparent latch -> W bus -> IR D pins. One combinational path, ~212ns,
settles inside the half-period. IR deaf the whole time.

Second half: LE_IR rises, IR tracks the stable opcode.

Closing edge: IR captures, '163 advances, PC++ points at the operand.

Old T1 had exactly one job: get data past the wall that old T0's pulse
built by slamming MDR's latch shut. Transparent MDR removes the wall;
edge-loading removes the pulses; T1 is revealed as an artifact of the
'121 architecture, not a real step. Every "X to MDR, then MDR to Y"
pair in the old table collapses the same way whenever X is memory.

### Transparent MDR rules (write these next to the table)

ADOPTED AND BUILT (the snoop-MDR on the verified MDR/IR sheet).

1. MDR transparent ONLY when memory is the sole W-bus driver. Encoded in
   the source field: ROM_OUT / RAM_OUT are the only codes that raise MDR
   LE + OE. Structurally impossible to fight.
2. LE_MDR derives from the same gated discipline as every register.
   Decode ripple wiggles a bus nobody samples; it cannot corrupt.
3. Writes unaffected: W bus -> MDR -> memory (STA direction) uses MDR
   as a normal capturing register.

Payoff realized: LDAI 4 states -> 2, STA 7 -> 4, all fetches one state per byte.

## 3. Phase 1: MDR/IR sheet — COMPLETE

Executed and verified row-by-row in KiCad. The plan's delete list held
(U22 '121, R6, C17, the four pulse NANDs, U52A, the pulse nets). As-built
gate choices differ from the pencil plan — LE_MDR is a 3-input NAND
composition (snoop design), LE_IR = NOR(/IR_LOAD, CLK) on U22A, /MDR_EN =
NOR(LE_MDR, MDR_OUT_HI). Full as-built record: dino_session_state.md,
"Sheet status." The RESET-forces-IR-load path was dropped as planned:
reset lands the '163 on T0 and a normal fetch fills IR.

Layout rule (stands machine-wide): every stamp gate lives physically
adjacent to its '373. CLK routing to stamps gets '163-grade care: short,
no stubs. Skew between "counter advances" and "latch closes" is the only
timing coupling in the design.

## 4. Phase 2: remaining '121-era sites — memory COMPLETE, PC spec'd

Memory sheet: done. U40 '121 deleted; /WE = NAND(WRITE_DIR, /CLK) — the
same clock discipline with the polarity the pin wants: write strobe
asserted only during the second half of the write state, address and data
stable long before and after.

PC sheet: not a literal '121 but the same sin (async pins). Full spec in
dino_pc_193_integration.md: UP edge-formed by NAND(PC_UP, /CLK), CLR and
/LOAD phase-gated to the second half, reset merged.

## 5. Phase 3: register boards + ALU — SUPERSEDED, see dino_register_conversion.md

The original template here (every register: '373 + stamp, /OE direct from
source decode) survives in spirit but the converged design (2026-07-13)
differs in two ways worth reading in full in the conversion doc:

1. REGISTER BOARDS KEEP v0.0.2 TOPOLOGY: joined D=Q local bus, ONE
   bidirectional '245 per register (DIR = /REG_x_OUT steered), OE =
   /REG_x_OUT, /x_EN = AND(/REG_x_LOAD, /REG_x_OUT) on one '08. LE = the
   NOR stamp, per this plan. Sheet 8 is a minimal diff; sheet 7 deletes
   whole ('121s U58/U64 + all pulse logic — the last monostables in the
   machine).
2. THE ALU READS SHADOW REGISTERS, not the register buses: TMP_A/TMP_B
   '373s on the ALU sheet listen on the W bus and latch-enable on the SAME
   decodes as A and B (TMP_x ≡ REG_x by construction, including ALU
   writebacks). The writeback feedback loop is broken by the ALU output
   latch (LE=CLK, master/slave — see section 2b addendum), not by
   register technology. The '377 idea is dead.

Freed control word bit: PULSE_REQ (bit 12) became END: inverted into the
'163 synchronous /MR, resetting to T0 on the closing edge of any state
that asserts it. Funds variable-length instructions. (Control-sheet wiring
still owed — debt ledger.)

## 6. Phase 4: single-register validation (the milestone)

Definition of "one register works":
1. Control word selects a known source onto the W bus (DIP switches through a '244 make a fine test source if no other register exists yet).
2. Load field selects the register under test.
3. Single-step the clock (debounced pushbutton or the 555 slowed to ~1Hz).
4. After the edge: '373 outputs show the bus value.
5. Advance through states where the register is NOT selected, with the bus deliberately changed: outputs must hold. No ghost loads.
6. DSLogic on: CLK, /R_LOAD, LE_R, one bus bit, one Q bit. The capture should look exactly like the reference diagram in section 2. Any deviation is a wiring error, not a timing error, at single-step speeds.

Extended test list (EN gate, shadows, output latch, flags edge):
dino_register_conversion.md §5 and alu doc §7.

Pass = architecture validated. Every subsequent register is wiring. Path from there: remaining registers → microcode already written → LDAI/STA → JMP → JNZ → countdown demo.

## 7. Timing budget (for the notebook, LS typicals, verify against installed parts)

    '163 CLK→Q            ~14ns
    '138 select→output    ~20ns
    stamp NOR (LE)        ~10ns
    '373 LE→Q (transp.)   ~18ns
    '373 setup before LE↓ ~5ns
    '373 hold after LE↓   ~20ns  ← covered by '163+'138 lag (~34ns) before /LOAD can change
    Source '373 /OE→Q     ~28ns
    '245 enable/prop      ~12/25ns

Worst path in a state: '163 + '138 + source /OE + bus + destination setup ≈ 90-100ns, all inside the first half-period. ALU states: result must settle by the FALLING edge — '163 + EEPROM tACC + F382 + output latch ≈ 220ns vs a 500ns half at 1MHz (alu doc §6). The design is not timing-limited until well past where the 555 can take it.

---

Order of operations (updated): Phase 1 done, Phase 2 memory done + PC spec'd,
Phase 3 = conversion doc (sheet 7 delete, sheet 8 minimal diff, ALU sheet
draw), Phase 4 prove one register, then microcode. The '121s died first
because everything downstream assumes the clock discipline in section 0.
