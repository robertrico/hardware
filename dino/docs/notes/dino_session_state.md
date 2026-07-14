# DINO session state: decisions not captured elsewhere (updated 2026-07-13, session close)

SESSION CLOSED OUT 2026-07-13. Committed (local only, not pushed) as
"DINO v0.0.3: complete ALU/control-word, add MAR+reset sheets, wire reset
circuit". Everything below is verified against the committed files via a
fresh full netlist sweep, not memory — safe to start the next session
straight from the TODO list at the bottom. NEXT SESSION STARTS ON: MAR
sheet (item 1). Reset circuit and control word are DONE, not TODO items
anymore — don't re-litigate them, they're netlist-clean.

Companion to: 121_elimination_plan, pc_193_integration, alu_74f382_design,
clock_refactor, design_notes, register_conversion (the last two of which
are now archived in Done/, along with the 0_0_1 wiring summary and the
prior handoff doc — see docs/notes/Done/). This file holds what lives
only in conversation. THIS FILE IS AUTHORITATIVE over any conflicting
detail in the companion docs above — several settled today (flags chip,
Cn build, Z-detect build) superseded open questions those docs still show
as blank. The alu doc's §8 has been annotated RESOLVED with pointers back
here; the others (clock/pc/register/121, still in docs/notes/, not Done/)
are untouched historical record and still accurate for what they cover.

## Control word bit map (COMPLETE, all 16 bits assigned and wired, v0.0.3)

    15  HALT            direct bus tap (not decoded)
    14  PC_MAR_MUX      direct bus tap. PC=1, MAR=0
    13  PC_UP           direct bus tap
    12  END             direct bus tap -> inverter -> '163 /MR combine (Phase 0.5)

    IMPORTANT DISTINCTION (clarified 2026-07-13 late): bits [15:12] and
    [11:9] are RAW BUS TAPS off the ROM word, NOT '138-decoded outputs.
    A '138 output is active-low by hardware necessity (one-hot decoder);
    a raw bus tap's polarity is just whatever Rico programs into that ROM
    bit — his free choice, nothing forces it either way. All four of
    HALT/PC_MAR_MUX/PC_UP/END are ACTIVE HIGH, plain (no bar), matching
    the consuming logic on their respective sheets as-is — this was
    briefly tried as active-low (bar) and reverted; see correction below.

    [11:9] ALU (SA2:SA1:SA0) — direct bus taps, no decode:
    SA2=CW9, SA1=CW10, SA0=CW11 (confirmed by real wire, not just label text)
    000 CLR   001 BSUB   010 SUB   011 ADD
    100 XOR   101 OR     110 AND   111 SET

    [8:6] U29 '138 (CW8:CW7:CW6 address)
    000 NONE  001 /PC_CLEAR  010 /PC_LOAD  011 /COND
    100 /MDR_OUT  101 NC  110 /REG_OUT_LOAD  111 NC

    [5:3] U28 '138 (CW5:CW4:CW3 address) — W-bus source
    000 NONE  001 /ROM_OUT  010 /RAM_OUT  011 /REG_A_OUT
    100 /REG_B_OUT  101 /REG_C_OUT  110 /ALU_OUT  111 NC

    [2:0] U30 '138 (CW2:CW1:CW0 address) — W-bus destination
    000 NONE  001 /REG_A_LOAD  010 /REG_B_LOAD  011 /REG_C_LOAD
    100 /MAR_LO_LOAD  101 /MAR_HI_LOAD  110 /IR_LOAD  111 /RAM_LOAD
    (dst=A also loads TMP_A; dst=B also loads TMP_B — shadows, not codes.)

    All three '138s share E1=E2=GND (always enabled), E3=+5V. Each has an
    O0="NONE" code and (U28/U29 only) an unused "NC" code, tied together
    across all three decoders as a shared don't-care sink — deliberate.

## Microcode addressing

    EEPROM address = {IR[7:0], T[3:0]} = opcode*16 + T. Four hex digits 0x0OOT.
    e.g. LDAI=0x11: rows 0x0110-0x011F. Space 0x0000-0x0FFF, A12 unused.
    Two AT28C64B in parallel: U9 = word[15:8], U15 = word[7:0], same address.
    U17 (T-state buffer) -> A0-A3, ascending T0->A0..T3->A3, VERIFIED correct.
    U16 (IR buffer) -> A4-A11, ascending IRB0->A4..IRB7->A11, VERIFIED correct
    (this was drawn MIRROR-REVERSED earlier today — IRB0 landed on A11 instead
    of A4 — caught by netlist audit, fixed. See "Bugs found+fixed" below.)

## Instruction microwords (drafted, symbolic — unchanged)

    T0 universal (ALL 256 opcodes): MUX=PC PC++ src=ROM dst=IR = 0x600E
    NOP:  T1: END                                   = 0x1000 (also safe-fill)
    LDAI: T1: MUX=PC PC++ src=ROM dst=A END
    LDBI/LDCI: same, dst=B/C
    STA:  T1: dst=MAR_LO  T2: dst=MAR_HI (both MUX=PC PC++ src=ROM)
          T3: MUX=MAR src=REG_A dst=RAM END
    LDA:  T3: MUX=MAR src=RAM dst=A END (T1/T2 as STA)
    JMP:  T3: MUX=MAR, [8:6]=PC_LOAD, END (T1/T2 as STA)
    ADD:  T1: ALU=ADD src=ALU dst=A END             = 0x1631
    ALU family = 0x1631 with [11:9] swapped: SUB 0x1431, AND 0x1C31,
    OR 0x1A31, XOR 0x1831, CLR 0x1031, SET 0x1E31, BSUB 0x1231
    OUT:  T1: src=REG_A, [8:6]=OUT_REG_LOAD, END
    HALT: T1: bit15, END
    Endianness: operands LO then HI (little-endian, 8008-lineage).
    PC++ count per instruction == byte length (T0 counts the opcode).

## Memory map (also on memory sheet title block)

    ROM 0x0000-0x7FFF (A15=0, /CE=A15 direct)
    RAM 0x8000-0xFFFF (A15=1, /CE=INV(A15), inverter lives on MAR sheet)
    Reset: PC=0x0000 -> ROM. STA below 0x8000 = silent no-op (assembler warns).
    RAM_EN / ROM_EN: defined on the MAR sheet (being drawn now, not yet in
    the file) — this is the A15 address-range decode feeding memory sheet's
    /RAM_EN, /ROM_OUT-adjacent enables.

## Sheet status (2026-07-13 evening)

    COMPLETE, netlist-audited clean (every pin driven or intentionally idle):
    - ALU sheet: 2x F382 (nibble split), TMP_A/TMP_B shadow latches, output
      latch, flags register, Z-detect, ALU_CIN — all built and wired. Full
      pin-level detail below. One harmless spare gate left (U50, gate C).
    - Control word sheet: all 16 CW bits assigned — see bit map above.
    - Root sheet (dino_v0_0_2.kicad_sch): clock chain (Y1 4.096MHz -> U20
      '163 divider -> U27A '74 toggle -> CLK//~CLK at 1.024MHz) + T-state
      generator (U6 second '163, free-running -> U7/U8 dual '138 one-hot
      decoder -> TO0-TO15) both confirmed correct. U27B and 2 of U23's
      inverter gates are the intentionally-idle reserves (U27B = reset sync,
      reserved and NOW SPOKEN FOR — see Reset section below).
    - Program Counter: '193 carry chain + gating previously verified;
      C16 decoupling leg and U1 DOWN-pin-floating gaps found and fixed
      this session.
    - MDR, Memory, Registers A/B: netlist-clean, no changes needed this
      session beyond the earlier sessions' work.
    - Microcode sheet: IRB mirror-reversal bug found and fixed (see below).
    - Reset circuit (reset.kicad_sch, now merged onto the root sheet — see
      below): RC+button+74HC14 front end, U27B synchronizer, fan-out to
      flags/T-state-counter/PC-clear. Netlist-verified clean, zero
      floating pins. DONE, not a TODO anymore.

    IN PROGRESS (this is where tomorrow starts):
    - MAR sheet (mar.kicad_sch): stub components now PLACED but NOT wired
      — U54 (a '245, DIR/A0-7/B0-7/CE), U55 (a '373), U58 (another '373),
      U59 (a second '245). Matches the intended shape (MAR_LO/HI latches
      + 2x '245 for M-bus drive) but every pin is still floating. Still
      owes: A15/~A15 decode -> RAM_EN/ROM_EN, the NOR stamps off
      /MAR_LO_LOAD//MAR_HI_LOAD for U55/U58's LE pins, and the CE/OE/DIR
      wiring on U54/U59.
    - input_output.kicad_sch: PARTIAL PROGRESS this session — the R18/
      R21-24 floating-leg gaps are FIXED. Still open: LED anodes D1-D8
      (pin 2) floating, SW1 pins 10-16 floating, SWITCH-GATE1 GND/VCC
      floating, C48 pin 1 floating.

    STILL OPEN:
    - Full-hierarchy compile-and-audit once MAR has real content (10 of
      11 sheets are netlist-clean as of session close; MAR is the only
      one with placed-but-unwired stubs).

## ALU sheet — full as-built wiring (COMPLETE)

    U38 (low nibble F382): A/B=TA/TB0-3, S=SA0-2, F=F0-3, CN=ALU_CIN,
      CN+4=CRY (-> U40.CN), OVR=NC (low-nibble overflow unused).
    U40 (high nibble F382): A/B=TA/TB4-7, S=SA0-2, F=F4-7, CN=CRY (from
      U38), CN+4=ALU_C, OVR=ALU_V.
    U45 (TMP_A, '373): OE=GND, LE=LE_TMP_A=NOR(/REG_A_LOAD,CLK), D=W0-7,
      O=TA0-7.
    U46 (TMP_B, '373): OE=GND, LE=LE_TMP_B=NOR(/REG_B_LOAD,CLK), D=W0-7,
      O=TB0-7.
    U47 (output latch, '373): LE=CLK direct, OE=/ALU_OUT, D=F0-7, O=W0-7 —
      the sheet's only bus driver.
    U48 ('157 quad mux, flags load-enable emulation — '273 has no enable
      pin so this is the substitute): S=/ALU_OUT (direct, active-low S
      picks I0 during a real commit, no inverter), E=GND permanent (E is
      a strobe not tri-state OE — driven high it forces ALL Y LOW, never
      let it float). Per bit: I0a=ALU_C/I1a=FLAG_C feedback, I0b=Z/I1b=
      FLAG_Z feedback, I0c=ALU_V/I1c=FLAG_V feedback, I0d=F7(sign)/I1d=
      FLAG_N feedback. Za-Zd -> U49 D0-D3.
    U49 (flags register, '273 — NOT '173, none in stock): Mr=/RESET
      (async active-low clear, a free upgrade '173 didn't have), Cp=/CLK
      (triggers on CLK's falling edge, matching the ALU result commit),
      D0-3=U48 mux outputs, D4-7=GND (unused, tied not floating), Q0-3=
      FLAG_C/FLAG_Z/FLAG_V/FLAG_N, Q4-7=NC.
    U52 (quad '02) + U53 (quad '08): Z-detect via De Morgan tree (see
      alu_74f382_design.md §8 item 1 for the identity) — F01/F23/F45/F67
      NORs, F0123/F4567/Z ANDs. U53's 4th gate (pins 12/13->11) + U50's
      4th gate (pins 11/12 tied ->13) build ALU_CIN = NAND(SA1,SA0)
      instead — see below.
    ALU_CIN: NOT XOR. NAND(SA1,SA0) satisfies BSUB=1/SUB=1/ADD=0 with CLR
      as the (0,0) don't-care — XOR and NAND only differ there. Built
      from 2 already-placed spare gates, zero new chips: U53 4th AND gate
      (SA1,SA0 -> AND) feeds U50's 4th NOR gate wired as an inverter
      (both inputs tied to the AND's output) -> ALU_CIN.

## Bugs found and fixed this session (netlist-audit driven)

    Built docs/notes/kicad_netlist.py this session (tokenizes .kicad_sch,
    resolves pin->net connectivity including bus/bus_entry and same-name
    local-label merging — the actual KiCad connectivity model). Use it for
    any future audit: `python3 kicad_netlist.py <file> [grep-pattern]`.
    Parser bugs hit and fixed along the way: (1) multi-body-style symbols
    (De Morgan alternates) double-counting pins — fixed by dedupe-by-
    (unit,pin-number) instead of guessing which style number is "real";
    (2) bus trunks were being treated as real conductors, which is WRONG —
    in KiCad a bus trunk is a routing-only graphic; real connectivity comes
    from matching label text on the individual member wires/bus_entry
    stubs, which the parser now implements as an explicit union-by-label-
    name pass.

    Real design bugs found via the audit (all fixed):
    1. Root sheet T-state counter labels were backwards/off-by-one
       (Q0->T4...Q3->T1 instead of Q0->T0...Q3->T3). Fixed to ascending.
    2. Microcode U16 (IRB->ROM address buffer) was mirror-reversed
       (IRB0->A11 instead of A4). Fixed to ascending — this one was a
       real functional bug, would have decoded every opcode bit-reversed.
    3. Control word U28/U30 briefly shared identical duplicate CW-bit
       labels (a bus_entry touching-point overlap from the sheet
       overhaul) — Rico fixed by separating the touching bus connectors;
       re-audited clean, CW0-8 now uniquely assigned across U30/U28/U29.
    4. `~{OUT_REG_LOAD}` (control_word) vs `~{REG_OUT_LOAD}` (registers_a_b)
       — word-order-swapped naming mismatch, same signal meant two ways.
       Fixed (registers_a_b's spelling won).
    5. Deprecated 7 orphaned .kicad_sch files (unreferenced by the root
       sheet's Sheetfile list) into dino_v0_0_2/deprecated/: data,
       instruction_register, ir, reg_logic, registers, registers_c_out,
       ring_counter.

    6. `PC_MAR_MUX` (control_word) vs `~{PC_MUX}` (program_counter) —
       naming mismatch, FIXED: program_counter now spells it PC_MAR_MUX,
       exact match confirmed both sheets.
    7. `PC_UP` — CORRECTING MY OWN EARLIER CALL: I had flagged renaming
       this to active-low (~{PC_UP}) as a live logic bug, since program_
       counter's U36 gate (NAND(PC_UP,~CLK)) assumes active-high. Rico's
       correction: bits [15:12] aren't '138-decoded (see bit map note
       above), so PC_UP's polarity was never fixed by hardware — it's a
       raw ROM bit, free choice, and it was simply reverted to active-high
       (matching what U36 already expects). No gate rework needed, ever.
       My mistake was assuming the same active-low convention that DOES
       apply to '138 outputs also applied here — it doesn't. Both sheets
       now plain "PC_UP", exact match confirmed.

## Reset circuit (COMPLETE this session — wired, netlist-verified clean, committed)

    Math: Y1 4.096MHz / 4 (U20 divider tap + U27A toggle) = 1.024MHz system
    clock, matches "~1MHz" everywhere else in the docs.

    Architecture: async assert, sync release. Don't feed a raw RC/button
    signal to every clear pin directly — skew across the fanout (different
    chips seeing release at slightly different times) is exactly the class
    of bug the bug-pattern ledger already warns about. Assert immediately
    (fast reaction to power-up/button), release only in lockstep with CLK.

    Uses U27B — the second half of the clock '74, RESERVED for exactly this
    since the clock cluster was drawn. CORRECTED 2026-07-13 late (original
    note had D and the async pin backwards — re-derived carefully below):
        Front-end signal --> async PRESET (~S, pin10) of U27B — NOT ~R.
          Forces Q=1 (RESET asserted) the instant power-up/button holds
          the front end low. ~R (pin13) ties inactive, +5V, unused.
        U27B.D  = GND (0) — the value Q settles to (RESET deasserted) once
          ~S releases and the next clock edge lands. NOT +5V — Q's REST
          state is 0 (not-reset), so D must be 0, not 1.
        U27B.CP = CLK
        U27B.Q  = RESET (active high), U27B.~Q = ~{RESET} (active low)
    One synchronizer stage is plenty at 1MHz for a hobby build — metastability
    risk here is negligible, this isn't a concern until frequencies orders
    of magnitude higher.

    Front end (RC + Schmitt buffering + momentary button) — PART CONFIRMED
    2026-07-13 late: 74HC14N in stock. '14 is INVERTING, so it takes 2 of
    its 6 gates in series (Schmitt-clean + invert, then plain invert-back)
    to get a net NON-inverting, hysteresis-cleaned version of the RC node
    — needed because the RC node's natural polarity (LOW at power-up, HIGH
    once charged) already matches what ~S needs directly, so don't invert
    it an odd number of times or the polarity comes out backwards:
        +5V --[R ~10k]--+--> [2 gates of the '14, net non-inverting] --> ~S
                         |
                       [C ~10uF]
                         |
                        GND
        button in parallel with C, shorting it on press
    RC ~100ms: covers crystal startup + rail settling, still feels instant
    on a manual press. Button bounce is absorbed by the RC itself (bounce
    just re-discharges the cap; only the final clean release matters).
    HC/LS family mix is fine: HC output swings rail-to-rail, comfortably
    satisfies LS input thresholds (VIH>=2V/VIL<=0.8V) driving U27B's ~S.
    CAUTION (CMOS-specific, doesn't apply to the LS spares used elsewhere
    this session): the '14's 4 unused gates' inputs MUST be tied to a
    defined level (GND or +5V) — a floating CMOS input can sit at an
    indeterminate mid-rail voltage, partially conducting both halves of
    the totem-pole, unlike a floating LS input which just reads as a weak
    high. Don't leave them open.

    What /RESET (and RESET) drive — ALL DONE, verified clean:
    - Flags register (U49, ALU sheet): Mr=~{RESET}. Done.
    - T-state counter (U6, root sheet): ~MR=~{RESET} (from U27B.~Q
      direct — nothing else drives this pin, no merge needed). Done.
    - Program Counter (U1-U4, '193s): NOT a direct tie — RESET merges
      with the existing microcode-driven PC_CLEAR via 2 of U10's spare
      NOR gates (OR-from-NOR: gate2=NOR(PC_CLEAR,RESET), gate3=inverter
      on gate2's output) into PC_CLEAR_OR_RESET, feeding all four CLEAR
      pins. This was almost a bug — a direct tie would have bus-fought
      with U10's existing gate1 output on the same net. Caught before
      wiring. Done.
    - Registers A/B/C, MDR/IR, output register (all '373-based, no clear
      pin exists): DECIDED not worth hardware-clearing — same mux-based
      trick as the flags fix would cost real hardware, and first
      LDAI/LDBI/instruction fetch overwrites them before they're ever
      read. Open to revisiting if Rico wants deterministic power-up state
      for debugging — his call, flagged not decided-forever.

    The standalone reset.kicad_sch sheet from earlier in the session was
    deleted from the hierarchy and rebuilt directly on the root sheet
    instead (R1/C1/SW2/U56/C62, all confirmed above) — the leftover file
    is deprecated (moved to dino_v0_0_2/deprecated/), not deleted from
    disk, matching the existing archival pattern for orphaned sheets.

## Orphan-signal sweep (cross-sheet: used somewhere, driven nowhere)

    Real orphans found this session (checked by pin electrical-type, not
    just label text, across all 9 active sheets):
    - SA0/SA1/SA2 (alu.kicad_sch consumes, control_word.kicad_sch didn't
      source): FIXED — now direct bus taps CW11/CW10/CW9, confirmed by
      real wire (not just matching label text).
    - PC_UP, PC_MAR_MUX: both fixed, both now exact-string-matched across
      control_word and program_counter (see bugs list above).
    - `~{RAM_EN}` / `ROM_EN` (memory sheet): waiting on the MAR sheet
      (in progress) to source these — expected gap, not a bug.
    - CW0-15 flagged by the automated checker but is a FALSE POSITIVE: the
      EEPROM symbol's I/O pins are typed `input` in the KiCad library even
      though they're genuine outputs during a ROM read. Ignore that class
      of finding for memory-type chips.
    - IS0-7, LOAD_MODE (input_output.kicad_sch): no driver found — part of
      that sheet's pre-existing, untouched-this-session gap list above.

## Recurring bug pattern (ledger, ongoing)

    STRIKES 1-4 (2026-07-12, register/clock/PC phase — see prior session
    notes): wrong-polarity gates (NOR vs NAND for "assert on conjunction of
    actives"), stamp inputs on /CLK instead of true CLK, Y1->D0 pin-role
    mixups. Truth-table every new gate in asserted/idle terms first.

    STRIKE 5 (2026-07-13, this session): cross-sheet NAME mismatches
    surviving because sheets are netlist islands — a label spelled two
    different ways for "the same" signal never connects, and nothing in
    KiCad's per-sheet ERC catches it (each sheet is internally consistent
    on its own). Five found this session (OUT_REG_LOAD/REG_OUT_LOAD,
    T-state labels, IRB mirror-reversal, PC_MAR_MUX/PC_MUX, plus the
    duplicate-CW-label bus scare), ALL FIXED. Lesson: when a signal
    crosses a sheet boundary, grep BOTH sheets for the exact string
    before trusting it's wired — matching intent isn't matching text.

    Assistant-side correction (2026-07-13, this session): flagged PC_UP's
    active-low rename as a logic bug (assumed U36's consuming NAND needed
    rework). Wrong — conflated "'138 outputs are hardware-fixed active-low"
    with "these 4 bus-tap bits must follow the same convention." They
    don't; a raw ROM bit's polarity is free choice, and Rico just picked
    active-high consistently. Lesson for future audits: before flagging a
    polarity change as broken, check whether the signal actually passes
    through a fixed-polarity primitive (a decoder, a specific counter pin)
    or is just a raw data bit with no hardware-imposed convention.

    Bus-trunk lesson (this session): a KiCad bus trunk is a routing-only
    graphic, not a conductor — treating it as one falsely shorts every bit
    riding it together (bit this session's netlist tool once; also caused
    the CW0/CW5 duplicate-label scare when two different bus_entry stubs
    briefly touched at the same point). Real bus connectivity is carried
    by matching label text on the individual per-bit stubs, same as any
    other local label in this project.

## Register technology rule (FINAL 2026-07-13, unchanged this session)

    ALL registers are 74LS373 EXCEPT the flags register, which is 74LS273
    (no '173 in stock — see ALU section above for why '273 needed the
    '157 mux to emulate the load-enable pins '173 would have had for free).
    Register boards keep v0.0.2 topology: joined D=Q local bus, one
    bidirectional '245 (DIR = /REG_x_OUT steered, /CE = /x_EN =
    AND(/REG_x_LOAD, /REG_x_OUT)), OE = /REG_x_OUT. LE = NOR(/REG_x_LOAD,
    CLK) stamp. IR/MAR/MDR unchanged ('373 + stamp / snoop).
    OUT: '373, OE GROUNDED (exposure register), LE = NOR(/REG_OUT_LOAD,
    CLK), fed by U44 one-way (DIR strap, /CE = /REG_OUT_LOAD). Load-only;
    src 111 stays reserved for IN port.
    ALU operands: SHADOW REGISTERS TMP_A/TMP_B on the ALU sheet — the
    A->ALU->A loop is broken by the ALU OUTPUT LATCH (master/slave):
    output latch transparent iff CLK high; ALL destination latches
    (registers and shadows) transparent iff CLK low; never both. Two
    commit edges per state: falling = ALU result + flags freeze; rising =
    destinations + shadows capture, '163 advances, PC++.

## TODO, in order (NEXT SESSION STARTS HERE)

    1. MAR sheet (mar.kicad_sch) — START HERE. Stub parts already placed
       (U54 '245, U55 '373, U58 '373, U59 '245) but zero pins wired.
       Needs: A15/~A15 decode -> RAM_EN/ROM_EN; NOR stamps off
       /MAR_LO_LOAD//MAR_HI_LOAD feeding U55/U58's LE pins (same pattern
       as the ALU sheet's TMP_A/TMP_B stamps — NOR(/xxx_LOAD, CLK));
       U54/U59's DIR/CE/OE for the 16-bit M-bus drive (2x '245, one per
       byte); OE grounded on U55/U58 (same pattern as TMP_A/TMP_B, only
       output-enabled to feed the '245s, never bus-shared directly).
    2. input_output.kicad_sch: finish the remaining floating gaps (LED
       anodes D1-D8, SW1 pins 10-16, SWITCH-GATE1 power pins, C48). Not
       urgent, pre-existing, no dependency on MAR work.
    3. Decide (not urgent): hardware-clear registers A/B/C/MDR/IR/output,
       or accept undefined-until-loaded as final.
    4. Full-hierarchy compile-and-audit once MAR has real content (10 of
       11 sheets already clean; rerun the sweep once MAR is wired).
    5. Testing strategy: dino_cpu_testing_strategy.md is STALE (describes
       a superseded 555/'163 clock and an overlapping ROM/RAM map) —
       needs a rewrite pass to match the actual built architecture before
       it's useful. Flagged by the docs-cleanup agent, not yet done.
    6. Finish line unchanged: LDAI/LDBI/SUB/JNZ/OUT/HALT countdown demo.
