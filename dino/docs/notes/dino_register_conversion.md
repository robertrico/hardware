# DINO register conversion: last '121 site + shadow-register ALU (FINAL)

Machine: DINO v0.0.2 → v0.0.3
Status: CONVERGED 2026-07-13 (Rico + assistant, conversational session).
This version supersedes everything above it in this file's history: the '377
plan (rescinded — unratified, none in stock), the rewired-register "spatial"
plan (rejected — tore up verified topology, added cross-board operand wires),
and the staged 8008-temp "temporal" plan (rejected — spent both free [8:6]
codes, 3-state ALU ops). Final architecture: SHADOW REGISTERS (Rico's
synthesis).

## The architecture in one paragraph

Register boards keep their v0.0.2 topology: joined D=Q local bus, ONE
bidirectional '245 per register (DIR steered), OE gated by /REG_x_OUT. The
ALU never taps the register buses. Instead, two shadow '373s (TMP_A, TMP_B)
sit on the ALU sheet with D pins on the W bus, latch-enabled by THE SAME
signals as A and B — every dst=A state loads A and TMP_A with the same value
on the same edge, so TMP_x ≡ REG_x by construction (from first load onward;
both random before it). The F382s read the shadows point-to-point. ALU ops
stay ONE execute state; microcode is untouched; misc field codes 101/111
stay free. The '121s and all pulse logic still die — stamps replace them.

## 1. Kill list (sheet 7, reg_logic.kicad_sch) — unchanged, dies whole

    U58, U64 ('121s), R25, R26, C20, C21
    U62A-D, U63A-D ('00 pulse combiners/distribution)
    U65A/B/E/F ('04 inverters — '138s now provide active-low directly)
    U57A/B, U66C/D ('02 EN NORs — replaced by '08 ANDs, see §2)
    Nets: PULSE_REQ (bit 12 = END), /REG_x_LE (replaced by local stamps),
    /x_EN as NOR outputs (recreated as AND outputs), active-high originals.

    VERIFY before package delete: U57/U66 spare units elsewhere in hierarchy.
    Freed '02 restuffs as stamps.

## 2. Register boards (sheet 8) — MINIMAL DIFF from the drawn sheet

Per register (A shown; B, C identical):

    U31 '373:  D=Q join on A Bus  KEPT AS DRAWN
               OE = /REG_A_OUT    kept (now sourced direct from U28 '138)
               LE = LE_A = NOR(/REG_A_LOAD, CLK)   ← the only latch change

    U41 '245:  DIR = /REG_A_OUT   kept as drawn (steered: 0 = reg→W bus,
                                  1 = W bus→A Bus for loads)
               /CE = /A_EN = AND(/REG_A_LOAD, /REG_A_OUT)
                                  ← Rico's truth table, one '08 gate:
                                  enabled when loading OR outputting,
                                  Hi-Z otherwise. (OR of asserted
                                  active-lows = AND in H/L terms.)

New parts on sheet 8: one 74LS08 (3 gates: /A_EN /B_EN /C_EN, 1 spare),
one 74LS02 (4 stamps: LE_A, LE_B, LE_C, LE_OUT). Place stamps adjacent to
their '373s; CLK routing short, no stubs.

Load walk (dst=A): '245 enabled+inbound drives A Bus with W value; '373 OE
off (no fight); stamp opens second half; edge captures. Output walk (src=
REG_A): OE on, '245 enabled+outbound, Q → W bus. Idle: '245 Hi-Z, OE off,
A Bus floats — fine, nothing reads it (the ALU reads shadows).

OUT register — unchanged from the earlier decision (Rico): OE grounded
(Out Bus always drives the outside world), so OUT keeps its dedicated
OUT_D net fed by U44 one-way (DIR strap A→B, /CE = /OUT_REG_LOAD, Hi-Z
outside the load state). LE_OUT = NOR(/OUT_REG_LOAD, CLK). No EN gate.

## 3. ALU sheet additions (see alu_74f382_design.md for the full sheet)

    TMP_A '373 (shadow of A):  D = W bus (direct — inputs are listeners,
               no buffer; IR precedent), OE = GND, Q = F382 A ports
               (point-to-point, one driver one listener, no tri-state),
               LE = NOR(/REG_A_LOAD, CLK) — own stamp, SAME inputs as
               LE_A on the register board.
    TMP_B '373 (shadow of B):  same with /REG_B_LOAD; Q = F382 B ports.
    Output latch '373:  D = F[7:0], LE = CLK direct, /OE = /ALU_OUT,
               Q = W bus. The ALU sheet's only bus driver.
    Flags '173: CP = /CLK, /IE = /ALU_OUT — capture on the mid-state
               falling edge (C/V from F382 pins go stale in the second
               half once TMP_A starts tracking).

SHADOW INVARIANT (constitution material): TMP_x loads on EVERY dst=x state,
INCLUDING ALU writebacks — A and TMP_A capture the same frozen W on the same
edge, so chained arithmetic (SUB;JNZ;SUB in the countdown) always uses
current values. A shadow that skipped ALU writebacks would go stale and
break instruction chains — do not "optimize" this.

FEEDBACK SAFETY: during an ALU writeback's second half, TMP_A is transparent
and feeds the F382 — the loop is broken by the OUTPUT LATCH (frozen, LE=CLK
low), not by the shadows. Master/slave invariant: output latch transparent
iff CLK high; every destination latch (registers AND shadows) transparent
iff CLK low; never both.

## 4. What stays true from earlier analysis

    - Microcode: UNTOUCHED. ADD = T0 (0x600E) + T1 (0x1631). All hex stands.
    - Two commit edges per state: falling = ALU result + flags freeze;
      closing rising = destinations capture, '163 advances, PC++.
    - ALU settle deadline = first half: '163 + EEPROM tACC + F382 + latch
      ≈ 220ns vs 500ns half at 1MHz.
    - Trade accepted: no direct ADD B,C (shadows mirror A/B only);
      any-pair math = MOV-through idiom. Accumulator-machine standard.
    - Builder assert (design_notes): /MDR_OUT with src != NONE = ERROR.

## 5. Contract tests

    Register board (unchanged wiring logic, new gates):
    T1 stamp capture   dst=A held, CLK high: deaf; CLK low: tracks; edge:
                       captured. Reference diagram live.
    T2 ghost load      /REG_A_LOAD=1, bus wiggling, 100 edges: A unchanged.
    T3 EN gate         /A_EN low iff loading or outputting; Hi-Z idle
                       (pull test both ways). Truth-table at bench first.
    ALU board:
    T4 latch halves    /ALU_OUT=0: CLK high → W follows operands; CLK low
                       → W frozen.
    T5 shadow invariant  after LDAI then ADD then LDA: probe TMP_A vs A —
                       equal after every dst=A edge, including writeback.
    T6 loop safety     single-step ADD, B=1: A increments by EXACTLY 1 per
                       state. THE test.
    T7 flags edge      flags move only on falling edges of src=ALU states.

## 6. Ledger

    Owes: CLK to 4 stamps + '08 (sheet 8), 2 shadow stamps + latch LE +
    /CLK to '173 (ALU sheet). 0.1uF each new package. U57/U66 unit check.
    From stock: 3× '373 (shadows + output latch), '173, '08 (or buy — one
    package). Both [8:6] free codes PRESERVED.
    Sheet 8 diff is small: LE nets renamed to stamp outputs, /x_EN re-derived
    on the '08, everything else as drawn. Sheet 7 deleted whole.
