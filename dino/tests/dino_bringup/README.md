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
- 220-470R series resistor in every rig-DRIVEN jumper.
- Y1 stays OUT of its socket until the free-run stage; the rig is the clock.
- Loopback jumpers for `run selftest` are printed by the test itself.
- `run selftest` (and therefore `run all`) drives the loopback pool pins,
  which double as root's sampled lines — run selftest ONLY in the rig-only
  loopback config, never with a DUT board wired (series resistors limit
  the damage, but don't lean on them).

## Build-program progress (update as stages pass)
- [ ] 1 rig self-test — implemented in firmware (mod_selftest.c), BENCH PENDING (not yet run on hardware)
- [ ] 2 root — implemented in firmware (mod_root.c), BENCH PENDING (not yet run on hardware)
- [ ] 3-13: see spec (modules land in plan 2)

## Regenerating
    python3 ../../docs/notes/kicad_contracts.py --pinmap   # after any schematic change
    python3 ../../docs/notes/coverage_lint.py              # coverage invariant
