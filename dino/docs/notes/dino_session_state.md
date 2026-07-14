# DINO session state: decisions not captured elsewhere (updated 2026-07-14)

2026-07-14 session: MAR sheet wired complete (TODO item 1 done, including
a new strike-6 polarity bug found+fixed on the PC sheet — see ledger).
Then a full-schematic analysis pass (new tool:
docs/notes/kicad_xsheet_audit.py) found and fixed STRIKE 7 (all seven raw
control-word bus taps [15:9] were dangling label pairs — wired now) and
U66's missing power unit (registers_a_b). Second pass same day: NONE/NC
'138 bus fight untied (TODO 7), END and HALT circuits built (TODO 8-9,
new U61 on root — see as-built section), TO0-15 decided as debug taps
(TODO 11), COND design sketched (TODO 10, awaiting Rico's chip pick).
Schematic editing is now driven by docs/notes/kicad_gen_sheet.py — a
generic declarative generator (YAML/JSON ops files in
docs/notes/sheet_ops/, deterministic uuid5 output, built-in collision
check); the one-shot MAR generator was deleted in its favor. Working
tree NOT yet committed. Third pass: COND/JNZ built (TODO 10, U62 on
control word — every demo-blocking circuit now exists). NEXT SESSION:
TODO 2 (input_output gaps), then microcode ROM images + demo program.
Reset, control word decode, MAR, END, HALT, COND: DONE, netlist-clean,
don't re-litigate. CAUTION: KiCad was open during these disk edits —
always File->Revert/reopen before editing in the GUI, saving a stale
view clobbers everything.

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
    SA2=CW9, SA1=CW10, SA0=CW11 (NOW confirmed by real wire — see STRIKE 7:
    until 2026-07-14 ALL seven tap pairs [15:9] were dangling label pairs
    with no wire between them; the earlier "confirmed by real wire" note
    here was wrong)
    000 CLR   001 BSUB   010 SUB   011 ADD
    100 XOR   101 OR     110 AND   111 SET

    [8:6] U29 '138 (CW8:CW7:CW6 address)
    000 NONE  001 /PC_CLEAR  010 /PC_LOAD  011 /COND
    100 /MDR_OUT  101 NC  110 /REG_OUT_LOAD  111 NC

    [5:3] U28 '138 (CW5:CW4:CW3 address) — W-bus source
    000 NONE  001 /ROM_OUT  010 /RAM_OUT  011 /REG_A_OUT
    100 /REG_B_OUT  101 /REG_C_OUT  110 /ALU_OUT  111 /SW_OUT
    (111 was the reserved-for-IN-port code; CLAIMED 2026-07-14 by the
    input_output sheet's switch '244 — U28.O7's no_connect removed.)

    [2:0] U30 '138 (CW2:CW1:CW0 address) — W-bus destination
    000 NONE  001 /REG_A_LOAD  010 /REG_B_LOAD  011 /REG_C_LOAD
    100 /MAR_LO_LOAD  101 /MAR_HI_LOAD  110 /IR_LOAD  111 /RAM_LOAD
    (dst=A also loads TMP_A; dst=B also loads TMP_B — shadows, not codes.)

    All three '138s share E1=E2=GND (always enabled), E3=+5V. Each has an
    O0="NONE" code and (U28/U29 only) an unused "NC" code — these were
    originally tied together across decoders as a "don't-care sink";
    FIXED 2026-07-14: that tie was a real bus fight. '138 outputs are
    totem-pole, NOT open-collector and NEVER high-Z — an unselected
    output drives HIGH actively, so tying O0s together shorts LOW vs
    HIGH on essentially every microword (universal T0 already does it).
    The six pins (U28.15/.7, U29.15/.7/.10, U30.15) are now individually
    open with no_connect flags — an unloaded totem-pole output floating
    is completely fine, no pull-up or other part needed.

## Microcode addressing

    EEPROM address = {IR[7:0], T[3:0]} = opcode*16 + T. Four hex digits 0x0OOT.
    e.g. LDAI=0x11: rows 0x0110-0x011F. Space 0x0000-0x0FFF, A12 unused.
    Two AT28C64B in parallel: U9 = word[7:0] (CW0-7), U15 = word[15:8]
    (CW8-15), same address. (CORRECTED 2026-07-14 — this line previously
    had the byte roles swapped; netlist truth: U9 I/O0-7 -> CW0-7,
    U15 I/O0-7 -> CW8-15. Matters for which hex file burns into which chip.)
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
    JNZ:  T3: MUX=MAR, [8:6]=011 (/COND), END (T1/T2 as STA) — loads PC
          from the M-bus only when FLAG_Z=0, via the U62 gates (added
          2026-07-14, see COND as-built section). JMP stays its own
          opcode via [8:6]=010.
    ADD:  T1: ALU=ADD src=ALU dst=A END             = 0x1631
    ALU family = 0x1631 with [11:9] swapped: SUB 0x1431, AND 0x1C31,
    OR 0x1A31, XOR 0x1831, CLR 0x1031, SET 0x1E31, BSUB 0x1231
    OUT:  T1: src=REG_A, [8:6]=OUT_REG_LOAD, END
    HALT: T1: bit15 ONLY = 0x8000 — NO END BIT (RULE CHANGED 2026-07-14:
      the halt hardware freezes the T-state counter via CET, parking the
      CPU in the HALT microword forever; END would sync-clear T back to
      T0 on the next edge and the CPU would fetch right past the halt.
      '163 sync-MR overrides CET, so reset still exits a halted CPU.)
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

    COMPLETE (2026-07-14 session): MAR sheet (mar.kicad_sch) — fully wired,
    verified clean by BOTH kicad_netlist.py AND kicad-cli netlist export
    (see "MAR sheet — as-built" section below for full pin detail).
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

## MAR sheet — as-built wiring (COMPLETE 2026-07-14)

    U55 (MAR_LO '373): D0-7=W0-7, O0-7=MAR0-7, OE=GND, LE=LE_MAR_LO.
    U58 (MAR_HI '373): D0-7=W0-7, O0-7=MAR8-15, OE=GND, LE=LE_MAR_HI.
    U54 ('245 low byte):  A0-7=MAR0-7,  B0-7=M0-M7,  DIR=+5V (A->B one-way),
      CE=PC_MAR_MUX (active-low CE: MAR drives M-bus when bit14=0 — matches
      the bit-map convention PC=1/MAR=0 directly, no inverter needed).
    U59 ('245 high byte): A0-7=MAR8-15, B0-7=M8-M15, DIR=+5V, CE=PC_MAR_MUX.
    U60 (new quad '02, decoupled by C63) — all 4 gates used:
      gate1 (1<-2,3):    LE_MAR_LO = NOR(~{MAR_LO_LOAD}, CLK)  [ALU-stamp pattern]
      gate2 (4<-5,6):    LE_MAR_HI = NOR(~{MAR_HI_LOAD}, CLK)
      gate3 (10<-8,9):   ~{RAM_EN} = NOR(M15,M15) i.e. INV(A15); the gate-input
                         wire carries BOTH labels M15 and ROM_EN — ROM_EN is
                         A15 direct (ROM /CE=A15 per memory map), no gate.
      gate4 (13<-11,12): ~{PC_MAR_MUX} = NOR(PC_MAR_MUX,PC_MAR_MUX) — feeds the
                         PC sheet's U13/U14 CE pins (see STRIKE 6 below).
    Cross-sheet strings verified exact via grep on both endpoint files:
    W0-7 (alu/mdr), M0-M14 (memory/program_counter), M15 (program_counter),
    CLK, ~{MAR_LO_LOAD}/~{MAR_HI_LOAD} (control_word U30 O4/O5), PC_MAR_MUX
    (control_word), ~{PC_MAR_MUX} (program_counter), ROM_EN + ~{RAM_EN}
    (memory). Memory sheet has 2 dangling decorative M15 labels (no pin on
    them) — harmless, its ROM /CE connects via the ROM_EN label.
    Mux break/make note: gate4's ~10ns inverter delay means PC and MAR '245s
    can both be enabled for ~1 gate delay on one edge of a PC_MAR_MUX flip
    (make-before-break). Momentary LS bus contention, standard-practice
    tolerable at 1MHz hobby scale; noted, not actioned.

## END + HALT circuits — as-built (2026-07-14, second pass)

    New U61 (quad '02 on the ROOT sheet, decoupled by C65):
      gate1 (1<-2,3): ~{END_OR_RESET} = NOR(RESET, END) -> U6.~MR.
        U6's ~MR label was renamed from ~{RESET} to ~{END_OR_RESET}
        (U27B.~Q's own ~{RESET} label stays — the ALU flags register
        still consumes it cross-sheet). '163 MR is SYNCHRONOUS: an END
        microword clears T to 0 on the next rising CLK edge — exactly
        "this is the instruction's last state, next state is T0".
      gate2 (4<-5,6): ~{HALT} = NOR(HALT, HALT) i.e. inverter -> U6.CET.
        CET was detached from the +5V strap (CEP stays high). HALT=1
        freezes the T-state counter; the CPU parks in the HALT microword
        with the clock still RUNNING (scope/LEDs/flags stay alive —
        deliberate choice over oscillator gating, see TODO 9 notes).
        Requires the HALT-microword rule change in the microword section.
      gates 3,4: spares, inputs tied GND, outputs no_connect.
    Reset interplay: '163 sync clear dominates the count enables, so
    RESET works even while halted. Both verified in kicad_netlist.py AND
    kicad-cli netlist export.

## COND / JNZ logic — as-built (2026-07-14, third pass)

    New U62 (quad '02 on the CONTROL WORD sheet, decoupled by C66).
    U29 O2's decoder output was RENAMED ~{PC_LOAD} -> ~{PC_LOAD_JMP};
    U62 gate3's output now owns the ~{PC_LOAD} name the PC sheet consumes
    (same never-share-a-net merge pattern as PC_CLEAR_OR_RESET).
      gate1 (1<-2,3):   COND_TAKEN  = NOR(~{COND}, FLAG_Z)
                        high only when /COND asserted AND Z==0 (JNZ taken)
      gate2 (4<-5,6):   PC_LOAD_JMP = INV(~{PC_LOAD_JMP})
                        high on unconditional JMP's decoder code
      gate3 (10<-8,9):  ~{PC_LOAD}  = NOR(COND_TAKEN, PC_LOAD_JMP)
      gate4: spare, inputs GND, output no_connect.
    Truth check: JMP -> load ✓; JNZ w/ Z=0 -> load ✓; JNZ w/ Z=1 -> no
    load ✓; idle -> no load ✓. Two extra gate delays into the PC sheet's
    existing ~PC_LOAD_STABLE conditioning — negligible at 1MHz.
    FLAG_Z (ALU U49) gets its first consumer here. Semantics hardwired =
    jump-if-Z-clear; a future JZ needs one spare inverter + a second
    COND decoder code. Verified in kicad_netlist.py AND kicad-cli export.

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
      direct). Done — BUT "no merge needed" was premature: the Phase 0.5
      END bit is supposed to combine into this same pin (TODO item 8).
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
    - `~{RAM_EN}` / `ROM_EN` (memory sheet): RESOLVED 2026-07-14 — now
      sourced by the MAR sheet's U60 gate3 / M15 direct tap.
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

    STRIKE 6 (2026-07-14, MAR session): PC_MAR_MUX POLARITY BUG on the PC
    sheet, found before wiring MAR. U13/U14 ('245 PC->M drivers) had their
    active-low CE tied to PC_MAR_MUX DIRECT — meaning PC would drive the
    M-bus when bit14=0, but the bit map says PC=1/MAR=0 and every fetch
    microword (T0=0x600E) sets bit14=1. As wired, T0 would have tri-stated
    the address bus on every fetch. FIX: MAR sheet's new '02 gate4 makes
    ~{PC_MAR_MUX}; the PC sheet's U13/U14 CE label was renamed
    PC_MAR_MUX -> ~{PC_MAR_MUX} (one label, both '245s share the net).
    MAR '245s take PC_MAR_MUX direct (low = MAR selected, correct as-is).
    Zero microcode/doc churn — convention PC=1/MAR=0 stands. Same family
    as strike 1-4 polarity errors: the '245 CE is a fixed-polarity
    primitive (hardware active-low), so the raw active-high ROM bit needed
    one inversion somewhere and had none.

    STRIKE 7 (2026-07-14, full-schematic analysis pass): ALL SEVEN raw
    control-word bus taps were dangling. The control_word sheet had the
    tap labels drawn as PAIRS (SA2 next to CW9, END next to CW12, PC_UP
    next to CW13, PC_MAR_MUX next to CW14, HALT next to CW15, SA1/CW10,
    SA0/CW11) at matching Y coordinates — but with NO WIRE between any
    pair. Bits [15:9] of the control word were connected to nothing.
    Neither prior netlist sweep caught it because a pinless label is
    invisible to a pins-only audit; ERC had 14 label_dangling errors the
    whole time, drowned in island noise. FIXED: 7 wires drawn between the
    pairs, pairings verified against the bit map (all matched — the
    labels were placed correctly, just never joined). Lesson: dangling-
    label ERC errors are the ONE non-noise class on these sheets — check
    that list explicitly, it's short. Also: the previous session's
    "confirmed by real wire" claim for SA2=CW9 was wrong; treat past
    verification claims as re-checkable, not settled.

    ALSO FOUND 2026-07-14 (same analysis pass): U66 (registers_a_b '02,
    gates 3/4 = REG_C/OUT LE stamps) had NO POWER UNIT placed — no VCC or
    GND anywhere in the schematic, invisible to pin audits because
    unplaced units have no pins to audit. Only ERC's missing_power_pin
    check saw it. FIXED: unit E placed + power symbols + C64 decoupler,
    confirmed on +5V/GND in the kicad-cli netlist export.

    Tooling lesson #2 (2026-07-14, second pass): PLACEMENT COLLISIONS.
    First attempt at placing U61 checked the target area for SYMBOLS but
    not WIRES — its stub endpoints landed on the root sheet's GND rail
    and T-state bus, silently shorting END to GND and ~MR/CET into the
    +5V/T3 nets. Caught immediately by the post-edit kicad_netlist.py
    check (net printed as "END/GND" — a slash-joined name is the tell for
    an accidental label union). Root sheet was git-reverted and redone.
    kicad_gen_sheet.py now has a built-in collision pass: every new pin
    point, stub endpoint, and label anchor is checked against existing
    wire segments/pins/labels and the run is REFUSED (nothing written)
    on any hit. Self-tested: a deliberately colliding ops file exits
    with a listing.

    Tooling lesson (2026-07-14): when GENERATING .kicad_sch text, inner
    double-quotes in string fields MUST be escaped (\"). Sixteen generated
    power-symbol Description strings ('...global label with name "+5V"')
    went in unescaped; kicad_netlist.py's tolerant tokenizer shrugged and
    reported the sheet clean, but kicad-cli's real parser silently dropped
    every symbol after the first bad quote — power pins showed as
    unconnected-() in the exported netlist. Caught by cross-checking with
    `kicad-cli sch export netlist` (at /Applications/KiCad/KiCad.app/
    Contents/MacOS/kicad-cli). Rule going forward: any scripted edit to a
    .kicad_sch gets verified with BOTH kicad_netlist.py (per-sheet pin
    audit) and a kicad-cli netlist export (authoritative connectivity);
    kicad-cli ERC is too noisy to gate on (local-label islands make
    pin_not_driven fire for every cross-sheet net) but its per-class
    counts diffed against a git-baseline worktree catch regressions.

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

## TODO, in order (updated 2026-07-14)

    1. DONE 2026-07-14: MAR sheet wired and verified (kicad_netlist.py +
       kicad-cli netlist export both clean; see as-built section above).
       Includes the A15 decode, LE stamps, '245 M-bus drive, AND the
       strike-6 PC_MAR_MUX polarity fix (~{PC_MAR_MUX} inverter on the
       MAR sheet + U13/U14 CE relabel on the PC sheet).
    2. DONE 2026-07-14: input_output sheet complete (Rico rewired the
       topology in the GUI, remaining power hookups scripted). As-built:
       - LED bank: OB0-7 (from OUT register U35, cross-sheet by label)
         -> 330R -> LED anode, cathode -> GND. ACTIVE HIGH, lit = 1.
       - IN port: R17-24 are 10k PULL-UPS (+5V -> ISx); SW1 closes
         ISx -> GND (all commons pins 9-16 grounded). "All inputs high
         unless the dipswitch gives them a path to ground." Series-R-
         to-GND was rejected: an LS input's ~0.4mA source current
         through 10k would sit at ~4V, far above VIL=0.8V.
       - SWITCH-GATE1 ('244): A=IS0-7, Y=W0-W7 direct, both G-bars =
         ~{SW_OUT} = U28 O7 (src code 111). IB bus eliminated.
       - IN-instruction microword (draft): INA: T1: src=111(SW),
         dst=REG_A, END. Not yet in the instruction table's final list.
    3. DECIDED 2026-07-14 (Rico ack'd): registers stay UNDEFINED at
       power-up — no hardware clear, ever. Same contract as vintage
       CPUs (6809: A/B/X/Y undefined at reset). Flags are the one
       exception and already hardware-clear (U49 Mr=~RESET) because
       conditionals branch on them. The decision creates two HARD RULES:
       - MICROCODE EEPROMs: ALL 4096 {opcode,T} rows programmed, no
         gaps. Unused rows = SAFE-FILL 0x1000 (END) — garbage IR at
         power-on or T overrun always snaps back to T0 fetch (works for
         real now that the END hardware exists). T0 must be the
         universal fetch word in all 256 opcode rows.
       - PROGRAM ROM: unused bytes = the HALT opcode — PC running off
         the program's end freezes observably instead of executing
         garbage.
       Programs init-before-read (CLR via ALU is free); LEDs show
       garbage until the first OUT — cosmetic, accepted.
    4. DONE 2026-07-14 (rolled into item 1): full-hierarchy check ran via
       kicad-cli netlist export + ERC diff against the git HEAD baseline.
       All 11 sheets now netlist-clean; ERC deltas vs baseline all
       improvements (pin_not_connected 69->29, power_pin_not_driven 7->3;
       remaining ppnd = the pre-existing input_output gaps in item 2).
    5. Testing strategy: old dino_cpu_testing_strategy.md ARCHIVED to
       Done/ 2026-07-14 (Rico: "ditch it"). Replacement to be written
       fresh: a SHEET-TO-SHEET CONTRACT doc — for each module, the exact
       signals it consumes/produces (name, polarity, timing edge), so
       each board can be tested against its contract before integration.
       The kicad_xsheet_audit.py merged-net output is the natural
       starting skeleton.
    6. Finish line unchanged: LDAI/LDBI/SUB/JNZ/OUT/HALT countdown demo.

    NEW ITEMS from the 2026-07-14 full-schematic analysis (see
    docs/notes/kicad_xsheet_audit.py, rerun it any time):
    7. DONE 2026-07-14: NONE/NC '138 outputs untied (see bit-map section
       note). Rico confirmed — his "aren't they high-Z?" was the root of
       the original tie; '138s are totem-pole, never high-Z.
    8. DONE 2026-07-14: END circuit built — U61 gate1 on the root sheet,
       ~MR = NOR(RESET, END). See "END + HALT — as-built".
    9. DONE 2026-07-14: HALT built as T-STATE FREEZE (U61 gate2 ->
       U6.CET), not oscillator gating. Rationale recorded: hobby CPUs
       (SAP-1 lineage) usually gate the clock itself; real CPUs stop
       sequencing, not the oscillator. Freeze wins here because (a) zero
       glitch risk — CET is a synchronous enable, while AND-gating CLK
       can emit runt pulses when HALT changes mid-phase; (b) the clock
       stays alive for scope/LED observation while halted. REQUIRED
       MICROCODE RULE CHANGE: HALT word = 0x8000, no END bit (see
       microword section).
    10. DONE 2026-07-14: COND/JNZ built — U62 on the control word sheet,
       3 NOR gates (see "COND / JNZ — as-built"). JNZ microword row added
       to the instruction table. Future JZ = spare inverter + second
       COND code, not needed for the demo.
    11. TO0-TO15 (root sheet U7/U8 one-hot T-state decode): DECIDED
       2026-07-14 — keep as UNCOMMITTED DEBUG TAPS (scope / logic
       analyzer / LED probes during bring-up). Deliberately no consumer
       drawn; audits treat driven-but-unconsumed one-hot outputs as
       expected here. Do not delete U7/U8.
    12. Benign/known false positives, do NOT chase (documented here so
       future audits skip them): CW0-8 "undriven" (EEPROM lib types I/O
       pins as input); MAR0-15/PC0-15 "unconsumed" ('245 pins are
       tri_state, audit sees no input-type consumer); U38/U40 GND
       pin_to_pin power_out clash (F382 lib typing); #PWR02 ERC
       power-not-driven quirk on the root sheet (+5V net verified real in
       netlist export); U50.10 floating spare gate output (ALU); two
       decorative M15 labels on the memory sheet; IS0-7 "undriven"
       (pull-up + switch + buffer-input nets are all-passive-or-input —
       no active driver exists by design).
