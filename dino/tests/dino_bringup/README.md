# DINO bring-up rig

**Bench procedure lives in [BRINGUP.md](BRINGUP.md)** — per-stage wiring
tables, commands, expected output, failure meanings. Start there.

Bare-metal ATmega2560 test rig for the DINO CPU. Spec:
`../../docs/notes/dino_test_bringup_design.md` (test definitions,
build-program order, power/grounding rules). Pin hookups: flash, connect
serial, `pins <module>`.

## Quick start
    source env.sh          # port autodetect (override: DINO_RIG_PORT)
    build                  # avr-gcc via Makefile
    flash                  # avrdude through the Mega bootloader
    monitor                # screen, 115200 (exit: ctrl-a k)

## Shell
    list                   # all tests grouped by module
    run all                # everything (absent modules fail presence fast)
    run root               # one module
    run root.divider       # one test
    pins root              # jumper hookup table (GND first, always)
    selftest root          # rig-only loopback for ONE module's pins —
                           # prints its own pair list (root = 6 jumpers).
                           # `run selftest` = full 27-jumper all-pin check.

## Per-module workflow
    1. build the module board, hand-check it
    2. `selftest <mod>` — jumper the printed pairs, rig-only, expect PASS
    3. pull the jumpers, wire the DUT per `pins <mod>`
    4. `run <mod>` — fix / approve

## Bench rules (from the spec — non-negotiable)
- Bench 5V powers the DUT boards; Mega on USB; grounds commoned once.
  An UNPOWERED board does NOT fail cleanly: the rig's driven lines steal
  current through the DUT's input clamp diodes and CMOS parts read fine
  on it (measured 2026-07-23: memory scored 7/10 with the supply off).
  Every module suite gets a `power` test that runs first — it holds the
  rig's outputs low so there is nothing to steal. FAIL there = check the
  supply before believing any other FAIL.
- 220-470R series resistor in every rig-DRIVEN jumper.
- SWAPPED RIG WIRES are a first-class fault (ALU bring-up 2026-07-26). When
  two signals behave as EACH OTHER'S values, there are three places the
  transposition can live: the board wires, the strip slots, or the rig
  ribbon. Check the RIBBON FIRST — it is one accessible end, nothing is
  glued down, and both ends look correct at a glance. On the ALU this cost
  two rounds of beeping the DUT (U48 outputs, then U48 inputs) before the
  ribbon turned out to be the culprit.
- root runs LIVE: Y1 seated, DUT free-runs at 1.024MHz; rig monitors and
  drives only contract signals (END/HALT driven, rest sampled). You press
  the physical reset button when a test prints `ARM ...` — 10s window.
  Note: RESET stays asserted a while after release (RC stretch, measured
  0.25-2.2s bench-dependent); tests wait on the line, not a timer.
- Later module stages: rig is the clock, Y1 OUT (per spec).
- Loopback jumpers for `run selftest` are printed by the test itself.
- `run selftest` (and therefore `run all`) drives the loopback pool pins,
  which double as root's sampled lines — run selftest ONLY in the rig-only
  loopback config, never with a DUT board wired (series resistors limit
  the damage, but don't lean on them).

## Build-program progress (update as stages pass)
- [ ] 1 rig self-test — implemented in firmware (mod_selftest.c), BENCH PENDING (not yet run on hardware)
- [x] 2 root — PASSING on bench 2026-07-15 (live-clock guided workflow, 5/5)
- [x] 7 pc — PASSING on bench (baseline 9/9, by 2026-07-16). Hardened beyond passing: blind fault-injection runs (pulled GND, pulled ~CO2 carry wire) — suite correctly fingerprinted each fault class (value-dependent load corruption = grounding; bits 8-11 count corruption + growing clear residue = floating '193 UP pin).
- [x] 4 microcode — PASSING on bench 2026-07-16, BOTH burns (DIAG 7/7 then REAL 7/7, CRCs exact: U9=0xAD70 U15=0x58D7). Caught during bring-up: A8-A11 wire rotation + rig-side IRB5/7 jumper cross — addr.order self-named every one. REAL pair stays seated. Opcode table is PROPOSED 2026-07-16 (only LDAI=0x11 was documented) — see microcode_gen.py OPCODES.
- [x] 3 control_word — PASSING on bench 2026-07-17 (7/7). Pin layout: one unbroken D53->D22 descent, one contiguous block per chip (kicad_contracts.py PIN_ASSIGN/PIN_PROBES); `pins control_word` prints every wire, probes included. Bring-up caught 5 rig-wiring faults over 5 runs, all on the U62/COND leg + the D19 spill wire — the U62 input/output probes fingerprinted each one from the FAIL pattern alone (~PC_LOAD=NOR(FLAG_Z,..) signature, probe-reads-Z signature, floating pin 1). One-hole slips around U62 pins 1/2/3 were 4 of the 5. INT-A (control_word + microcode) now unblocked. INT-A unblocks when this passes.
- [x] 10 mdr — PASSING on bench 2026-07-20 (8/8, landed early out of build-order). bridge.route retired schematic bug 4 on real copper. Bring-up caught 6 rig/board wiring faults over 3 runs, all serial-log-diagnosed: IRB bank dead (U34 side), WRITE_DIR wire, BUS_DIR run to U25.1, ~IR_LOAD leg, and the finale — U18.1 (OE) wired to MDR_OUT (U37 pin 6) instead of ~{MDR_OUT} (U37 pin 5): enable polarity inverted, U18 drove MDR at idle and released during replay, which cascaded into capture/tristate/bridge/stability fails until the fight analysis fingered U18. THIRD one-hole-slip fault class on this build ('04 in/out pins are adjacent — beep against both neighbors before power).
- [x] 5 registers — PASSING on bench 2026-07-21 (9/9). Longest bring-up yet (~8 runs): CLK<->C_LOAD leg swap, /OUT distribution shifted one register, gate-INPUT-vs-OUTPUT taps (U57.8-for-10, U57.14-VCC-for-13 — the beeps-to-every-chip rail fingerprint), dead 5V rail segment + lost U44 DIR strap after rework (parasitic-power signature: gates die as more strobes assert), OUT harness mirror+bridge+dangle, and the finale: PORTF->MDR jumper bank flipped — invisible to every A/B/C round-trip test (write/read through same wires cancels), caught ONLY by the asymmetric outreg path. Mirror-witness rule now codified in the spec; warmup vector hardened 0x5A->0xC5 (palindrome was mirror-blind). Meter rule earned: never beep a live board (`idle` first); in-circuit leg-to-leg reads diodes, not copper.
- [x] 8 mar — PASSING on bench 2026-07-22 (7/7). Bring-up caught: missing common ground (the all-float scan — bench rule 1 in action), a full stale-layout rewire (pre-PIN_ASSIGN hookup; rewire-alert process rule born here), '245 CEs on the inverted mux net (U60.13 for .11), the scrambled U60 right column, M9<->M10 swap (walk-decoded). One test bug found+fixed in the open: logic pass A compared RAM_EN against a latch that sweep states could recapture from floating W — W now held during the pass, and mismatches print state+signal detail. Suite: 7 tests, gate model host-tested, 2 probes (both on U60), decode hits the 0x8000 boundary from both bus drivers incl. a latch-vs-bus contradiction row. INT-C (pc+mar) unblocked. See BRINGUP.md stage 8.
- [x] 9 memory — PASSING on bench 2026-07-23, BOTH burns, 11/11 with the power test (DIAG crc 0xDFE7, REAL crc 0xF501 — both exact). The '121 is GONE: memory.window proves the RAM write pulse is now NAND(WRITE_DIR, ~CLK), a gate off the clock phase. memory.idle retired schematic bug 2. Added after a deliberate power-off run scored 7/10: memory.power, a phantom-power check that runs FIRST (rig sources nothing, so an unpowered '00 cannot hold its HIGH outputs). Bring-up: ONE fault, one run — MDR5<->MDR6 crossed (D48/D47), decoded from the byte-0 arithmetic alone (0xA5 -> 0xC5 = exactly a bit-5/6 exchange). ramrw/window/idle all passed THROUGH the swap because they round-trip the rig's own bytes — only the asymmetric ROM path could see it (mirror-witness rule earning its keep). Firmware (mod_memory.c, 10 tests; U51 gate model host-tested in hosttest/test_mem_expect.c; netlist-verified 2026-07-23), BENCH PENDING. v0.0.2 board updated to v0.0.3: the '121 one-shot is gone, the RAM write pulse is a gate (NAND(WRITE_DIR, ~CLK)) — memory.window is its test. memory.idle retires schematic bug 2 (U21 CE = AND(~RAM_OUT, ~WRITE_DIR)). NEW TOOLING: docs/notes/progrom_gen.py (host-tested, 16 tests) emits roms/PROG_diag.bin (self-naming address proof over 15 lines) + roms/PROG.bin (THE MILESTONE PROGRAM: LDAI 5; LDBI 3; ADD; OUT; HALT, safe-filled HALT) + CRCs + src/progrom_expect.h; assembler validates operand counts against microcode_gen's instruction table. Burn: make burn-prog-diag / burn-prog. Pin layout is ribbon-first per Rico's bench call: both byte buses in one unbroken 24-pin run D53->D30 (MDR0-7 = D53-D46, M0-M15 = D45-D30), signals on D29-D22 + D19 — neither bus is byte-aligned, so this module drives/samples per pin. See BRINGUP.md stage 9.
- [x] 6 alu — PASSING on bench 2026-07-26 (10/10). Board wiring was sound; the bring-up cost was process, not copper (see the ledger: slot renumbering mid-wiring, and a map reconstructed from inference instead of read off the board). Real fault: swapped rig ribbon wires on the FLAG_Z/FLAG_V pair. Test bugs found and fixed: alu.shadow's held-value assertions called compute(), which reloads the operands it was checking; alu.power claimed UNPOWERED on a partial collapse. '382 C/V on the logic codes came back operand-dependent (XOR 3/10, OR 1/10, CLR & AND 10/10, SET 0/10) with C and V always agreeing — deterministic but not constant, so not worth a baseline. Original: (mod_alu.c, 10 tests; arithmetic + gate model host-tested in hosttest/test_alu_expect.c, exhaustive over the operand grid; netlist-verified 2026-07-24), BENCH PENDING. Most probed board on the machine: 10 of 20 control wires are probes (both shadow stamps, ALU_CIN, the CRY nibble ripple, ALU_C/ALU_V/Z combinational AND FLAG_C/V/N registered — so a flag FAIL says whether the arithmetic or the commit lied). C/V asserted only on the three arithmetic codes ('382 leaves them undefined for logic). See BRINGUP.md stage 6.
- [x] 11 io — PASSING on bench 2026-07-26 (5/5, FIRST RUN — the only module to pass first time). Guided tests: io.switches prompts per-switch open/closed (pull-ups + switch-to-GND mean a CLOSED switch reads 0, so the prompt spells it out rather than naming a byte); io.leds walks a single LED twice then lights all eight, two y/n questions. Patterns 0xC5/0x3A chosen non-palindromic per the mirror-witness rule. io.tristate is the one that matters downstream — the '244 must truly release W for the ALU/MAR/MDR to share the bus.
- [ ] 12-13 remainder: integrations (INT-A/B/B2/C/D/E), free-run (see spec)

ALL TEN MODULES BENCH-PROVEN as of 2026-07-26: root, pc, microcode, control_word, mdr, registers, mar, memory, alu, io. Coverage lint reports 0 gaps and 0 pending. What remains is the integration ladder and free-run — the milestone program (LDAI 5; LDBI 3; ADD; OUT; HALT) is already burned and seated in the program ROM.

## RAM discipline (8KB SRAM is the rig's scarcest resource)
Every string the firmware only PRINTS lives in flash: literal messages
via `uart_putsP()`, test labels via `PSTR()`, signal-name tables as
PROGMEM flash-pointer arrays indexed with `PN()`, the TESTS registry in
PROGMEM (copy out with `memcpy_P`). The `test_check_*_r` variants exist
only for runtime-built RAM labels (selftest pin names). Bulk capture
borrows `g_arena` (2KB, one user at a time — root's burst buffers live
there) instead of adding static buffers. As of 2026-07-20 (5 modules +
selftest + shell): 39.8% RAM. Budget ~350B/module for pin bindings —
all remaining stages fit with room to spare.

## Regenerating
    python3 ../../docs/notes/kicad_contracts.py --pinmap   # after any schematic change
    python3 ../../docs/notes/coverage_lint.py              # coverage invariant
    python3 ../../docs/notes/microcode_gen.py              # after any microcode/opcode
                                                           # change: bins + expect header
                                                           # (reflash rig, re-burn ROMs)
    python3 ../../docs/notes/progrom_gen.py                # after any program/ISA change:
                                                           # PROG bins + expect header
    python3 ../../docs/notes/layout_gen.py <mod>           # breadboard placement page,
                                                           # scored from the netlist
    python3 ../../docs/notes/layout_gen.py <mod> --auto    # derive a placement instead
