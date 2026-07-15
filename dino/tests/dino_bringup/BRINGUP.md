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

Physical prep on the DUT side:
- Y1 OUT of its socket.
- Reset board + T-phase board powered per ground rules above.
- Nothing else attached downstream (PC/ALU/etc. boards disconnected).

Wiring (GND first; `O` = rig drives, series R required; `I` = rig samples,
direct). `pins root` prints the live version of this table.

    Mega pin   dir  DINO net      where on the boards
    GND        —    GND rail      first wire, always
    D45        O    END           the END tap net (control-word tap; for
                                  stage 2 it's the wire that feeds U61 pin 3)
    D42        O    HALT          the HALT tap net (feeds U61 pins 5/6)
    D38        I    CLK           U27A output side (CLK distribution net)
    D39        I    RESET         U27B pin 9 net
    D40        I    T0            U6 Q0 net
    D41        I    T1            U6 Q1 net
    D50        I    T2            U6 Q2 net
    D51        I    T3            U6 Q3 net
    D52        I    ~{CLK}        U27A ~Q side
    D53        I    ~{RESET}      U27B pin 8 net
    D18        O    CLKIN         Y1 socket pin 8 position / U20 clock input
    D19        O    RST_FORCE     the RC node (rig pulls low = button press;
                                  releases = RC recharges ~100ms, real button
                                  still works in parallel)

Run: `run root`. Expect 6 PASS. Takes a few seconds — reset tests include
deliberate 150ms RC-recharge waits.

What each test proves / what its FAIL means:

    root.divider       64 CLKIN pulses -> exactly 16 CLK rising edges, and
                       CLK/~CLK complementary. FAIL count wrong: divider
                       chain (U20 tap or U27A toggle). FAIL complement:
                       ~CLK wiring.
    root.tstate_walk   after reset, T counts 0..15 and wraps, one step per
                       CLK cycle. FAIL early values: U6 wiring/MR held.
                       FAIL at wrap: Q3/carry.
    root.reset_sync    async assert (RESET high while RST_FORCE held low),
                       complements agree, then the strong check: 150ms of
                       RC recharge with ZERO clock edges — RESET must still
                       hold — then one edge releases it. FAIL
                       held_before_edge: release isn't synchronous (check
                       U27B D=GND path). FAIL released_after_edge: front
                       end or D again.
    root.reset_tclear  reset mid-count clears T to 0.
    root.end_clear     END high across one rising edge clears T (U61 gate 1
                       + '163 sync MR); counting resumes next edge.
    root.halt_freeze   HALT freezes T with CLK still running; resumes on
                       release; reset overrides the freeze (sync-MR beats
                       CET). FAIL T_frozen: CET path/U61 gate 2. FAIL
                       reset_beats_halt: MR wiring.

Approve the stage: check the box in README.md, move on.

---

## Stages 3-13 — control word, microcode, registers, ALU, PC, MAR, memory,
MDR, I/O, integrations, free-run

Module tests land with plan 2 (docs/notes/plans/, forthcoming). The
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
