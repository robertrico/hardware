# DINO bring-up bible

The sit-down-and-read companion for bench sessions. One section per stage:
what to wire, where, what to type, what you should see, and what a failure
means. Deeper rationale lives in `../../docs/notes/dino_test_bringup_design.md`
(the spec); this document is the bench procedure.

HOOKUP TABLES ARE SNAPSHOTS of the generated pinmap (2026-07-15). After ANY
schematic change: regenerate (`python3 ../../docs/notes/kicad_contracts.py
--pinmap`), rebuild/reflash, and trust the rig's own `pins <mod>` /
`selftest <mod>` printouts over this file. The firmware resolves pins at
runtime from the same tables, so IT can't drift — paper can.

## Bench ground rules (non-negotiable, learned the hard way)

1. Bench 5V powers the CPU boards. Mega on USB. Grounds commoned at ONE point.
2. Bulk cap per breadboard rail AND across every board boundary the
   supply/return loop crosses (hot+gnd routed as a pair onto each board).
   Skipping the cross-board cap cost a full day — see the 2026-07-14 bench
   ledger in dino_session_state.md.
3. 220-470R series resistor in every rig-DRIVEN jumper (the `O` rows below).
   Sampled lines (`I` rows) connect direct.
4. Y1 stays OUT of its socket until the free-run stage. The rig is the clock.
5. Every jumper bundle's first wire is GND.
6. Selftest jumpers and DUT wiring are mutually exclusive. Never `run
   selftest`/`selftest <mod>` with a DUT attached.
7. Before calling a signal stuck, say out loud what it should REST at.
   (RESET rests LOW. Ask me how we know.)

## The flash/monitor cycle

    cd dino/tests/dino_bringup
    source env.sh          # picks up /dev/tty.usbmodem*
    build                  # avr-gcc, -Werror
    flash                  # exits with "Resource busy"? screen still owns
                           #   the port: screen -ls; screen -X -S <id> quit
    monitor                # 115200; exit with ctrl-a k, y
                           # (opening monitor resets the board — normal)

Shell commands: `list`, `run all`, `run <mod>`, `run <mod>.<test>`,
`pins <mod>`, `selftest <mod>`, `help`.

Output: `PASS <mod>.<test>` / `FAIL <mod>.<test> <label> want=0x.. got=0x..`
then `SUMMARY: n pass, m fail`. Tests continue after FAIL — read every line;
one wiring fault often explains a whole block of them.

---

## Stage 1a — rig self-test, per-module flavor (use this one)

No DUT. Jumper ONLY the pins the next module uses. `selftest root` prints
its own pair list; for reference, today's root pairing (6 jumpers, plain
wire, no resistors):

    D45 <-> D42        (END / HALT pins)
    D38 <-> D39        (CLK / RESET pins)
    D40 <-> D41        (T0 / T1 pins)
    D50 <-> D51        (T2 / T3 pins)
    D52 <-> D53        (~CLK / ~RESET pins)
    D18 <-> D19        (CLKIN / RST_FORCE, rig-side extras)

Run: `selftest root` → expect `PASS selftest.root`, `SUMMARY: 1 pass, 0 fail`.

FAIL on one pair = that jumper or one of its two header pins. FAIL on
everything = no jumpers installed (floating pins read stale values — you'll
see `got` trailing one pattern behind `want`).

THEN PULL ALL SIX JUMPERS.

## Stage 1b — full rig self-test (optional, deep check)

`run selftest` — all-pin version: PA<->PF bytewise (D22->A0 ... D29->A7),
PC<->PL bytewise (D30->D42 ... D37->D49), plus 11 pool pairs it prints.
27 jumpers. Worth doing once per rig, not per session.

---

## Stage 2 — root boards (clock divider + T-state + reset + END/HALT gates)

PASSED ON BENCH 2026-07-15 (5/5). This stage runs LIVE — the exception to
the rig-is-the-clock rule.

Physical prep on the DUT side:
- Y1 IN its socket — the DUT free-runs at 4.096MHz/4 = ~1.024MHz CLK.
- Reset board + T-phase board powered per ground rules above.
- Nothing else attached downstream (PC/ALU/etc. boards disconnected).
- You operate the physical reset button when a test prints `ARM ...`
  (10s window). RESET stays asserted for the RC stretch after release
  (0.25-2.2s measured, bench-dependent); tests wait on the line.

Wiring (GND first; `O` = rig drives, series R required; `I` = rig samples,
direct). `pins root` prints the live version of this table — 10 contract
jumpers + GND, nothing else (no CLKIN injection, no RC force wire).

    Mega pin   dir  DINO net      where on the boards
    GND        —    GND rail      first wire, always
    D45        O    END           the END tap net (feeds U61 pin 3)
    D42        O    HALT          the HALT tap net (feeds U61 pins 5/6)
    D38        I    CLK           U27A output side (CLK distribution net)
    D39        I    RESET         U27B pin 9 net
    D40        I    T0            U6 Q0 net
    D41        I    T1            U6 Q1 net
    D50        I    T2            U6 Q2 net
    D51        I    T3            U6 Q3 net
    D52        I    ~{CLK}        U27A ~Q side
    D53        I    ~{RESET}      U27B pin 8 net

Run: `run root`. Expect 5 PASS. Two tests are armed — press the reset
button when told.

What each test proves / what its FAIL means:

    root.clock    hardware edge count (Timer0 on D38): CLK = 1024kHz +/-2%,
                  ~CLK toggling. FAIL kHz: Y1/divider chain (U20/U27A).
                  FAIL CLKN: ~CLK wiring.
    root.tstates  burst capture (2+ samples per T state), then every state
                  change must be +1 mod 16 with rollover — prints the
                  sequence. FAIL steps: T not advancing (U6 clock/MR).
                  FAIL violations: counting order (Q wiring, bit swap).
    root.reset    armed. Hold: RESET/~RESET complementary, T frozen at 0.
                  Release: complements flip after the RC stretch, T counts.
    root.halt     HALT freezes T (any value); resumes on release; then
                  reset-while-halted clears to 0 (sync-MR beats CET).
                  FAIL T_frozen: CET path/U61 gate 2. FAIL reset_beats_halt:
                  MR wiring.
    root.end      END high pins T at 0 (U61 gate 1 + '163 sync MR, cleared
                  every edge); counting resumes when released.

Approve the stage: check the box in README.md, move on.

---

## Stage 7 — program counter (4x '193 + load/count gating + '245 mux)

Rig is the clock again (Y1 rule back in force): PC board standalone, all
inputs rig-driven, fully deterministic. `selftest pc` first, then wire per
`pins pc` — 23 contract jumpers + GND (M bus is 16 of them: PORTC = M0-7,
PORTL = M8-15).

Netlist facts the tests lean on (program_counter.kicad_sch, verified):

    U10 '02   CLR = OR(NOR(~PC_CLEAR, CLK), RESET) — decoder clear lands
              only while CLK is LOW; the RESET leg is NOT gated.
    U36 '00   UP pin = NAND(PC_UP, ~CLK) — counts on CLK rising.
              ~PC_LOAD_STABLE = NAND(PC_LOAD, ~CLK) — load lands only
              while CLK is LOW (NOT async, despite the '193 pin name).
    U11/U12   '245 A->B: M -> PCD (load path), enabled by ~PC_LOAD.
    U13/U14   '245 B->A: PC -> M, enabled by ~PC_MAR_MUX.

Protocol rules the firmware obeys (mirror them when hand-probing):
- PC_UP changes only while CLK is HIGH — deasserting during CLK-low fires
  a spurious count through U36.
- Never drive M with ~PC_MAR_MUX low — U13/U14 fight you through the
  series resistors.

Run: `run pc`. Expect 8 PASS, no button work.

    pc.presence    reset -> 0, one step -> 1. Wired at all?
    pc.count       prints the 16-step walk; then 8 clocks with PC_UP low —
                   no creep. FAIL walk: U36 gate 1 / '193 chain. FAIL hold:
                   PC_UP net stuck.
    pc.carry       00FF->0100, 0FFF->1000, 7FFF->8000, FFFF->0000; ROM_EN
                   (M15) flips exactly at 0x8000. FAIL: ~CO cascade between
                   the '193s.
    pc.load        patterns + walking 1s/0s through the M->PCD path; plus
                   ~PC_LOAD strobed with CLK HIGH must NOT land (U36 gate 3).
    pc.clear       ~PC_CLEAR blocked at CLK high, lands at CLK low (U10
                   NOR); RESET clears at either phase (un-gated leg).
    pc.mux         ~PC_MAR_MUX high -> all 16 M lines float (checked
                   individually); low -> PC drives again.
    pc.phase       PC_UP toggled during CLK-high -> no count; falling edge
                   -> no count; rising edge -> exactly +1.
    pc.precedence  clear beats load ('193 CLR dominance); load lands after
                   clear releases; RESET beats a count in flight; counting
                   continues from a loaded value (JMP-then-fetch seam).

Approve the stage: check the box in README.md, move on.

---

## Stages 3-13 — control word, microcode, registers, ALU, MAR, memory,
MDR, I/O, integrations, free-run

Module tests land with plan 2 (docs/notes/plans/, forthcoming) — PC (stage
7, above) landed early out of build-order because its board was next on
the bench. The
workflow will be identical for every module:

    1. build the board, hand-check what you believe works
    2. `selftest <mod>`      — rig-only, jumper the printed pairs
    3. pull jumpers, wire per `pins <mod>` (GND first, series R on `O` rows)
    4. `run <mod>`           — fix / approve
    5. integration test when the build-program order says so
       (INT-A after microcode, INT-B after ALU, INT-C after MAR,
        INT-D after stage 4, INT-B2 after MDR, INT-E before free-run)

Build order and the integration seams are in the spec's "Build program"
section. ROM burning (TL866, microcode diag image, CRCs) arrives with plan 3.
