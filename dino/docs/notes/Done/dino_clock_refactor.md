# DINO clock refactor: 555 → 4MHz can + divider + complementary pair

Machine: DINO v0.0.3, control sheet (dino_v0_0_2.kicad_sch root)
Status: design doc, replaces the 555 astable before integration bring-up.
Companions: dino_121_elimination_plan.md (the two-halves discipline this clock
must honor — including the 2026-07-13 addendum: the FALLING edge is now a
commitment edge for the ALU domain), dino_pc_193_integration.md and
dino_alu_74f382_design.md (consumers of /CLK).

---

## 0. Why the 555 goes

1. DUTY: the astable charges through R1+R2, discharges through R2. High half >
   low half, drifting with R/C tolerance and temperature. The entire two-halves
   discipline (first half settle, second half capture window) silently assumes
   the halves are halves. Current values are near-symmetric by luck; the
   architecture should not depend on luck.
   (2026-07-13: this got stricter — the falling edge now clocks the ALU output
   latch freeze and the flags '173. Duty symmetry is no longer just a settling
   budget; the falling edge's PLACEMENT is a commitment time.)
2. DRIFT: RC frequency wanders with temperature. Fine for blink tests, wrong
   for a machine whose timing budget is written in ns.
3. EDGES/DRIVE: 555 output edges are slow and its drive is mediocre. It should
   never fan out to a machine; it should feed exactly one gate input.
4. The ~3MHz derated ceiling (EEPROM-bound) deserves a source that can actually
   sit near it repeatably.

## 1. Architecture: three stages, each swappable

    [SOURCE] --> [DIVIDER '163] --> [PAIR GEN '74] --> CLK, /CLK to the machine

    SOURCE:   4MHz can oscillator (socketed).
              Alternates jumperable into the same node: the old 555 (slow
              bring-up) or a debounced single-step button.
    DIVIDER:  74LS163, free-running (PE, CET, CEP, /MR all high), CP from
              SOURCE. Taps at Q0..Q3 = /2, /4, /8, /16.
              All taps are 50% duty by construction (binary counter bits).
    PAIR GEN: 74LS74 half. /Q wired to D (toggle config), CP from the selected
              tap (or from SOURCE directly for max speed). Outputs:
                  CLK  = Q
                  /CLK = /Q
              Complementary from the same storage node: skew between CLK and
              /CLK is sub-ns, not gate-delay. Duty is exactly 50% regardless
              of source duty. This stage is the answer to "how do I line up
              CLK and /CLK without an OR": don't align two derived signals,
              generate both from one flip-flop.

## 2. Frequency plan

    Source tap        after '74     use
    4MHz direct        2MHz         nominal run speed (ceiling is ~3MHz
                                    derated; 2MHz leaves 50% margin)
    Q0 (2MHz)          1MHz         integration bring-up default
    Q1 (1MHz)          500kHz       cautious bring-up / scope-friendly
    Q3 (250kHz)        125kHz       demo-at-visible-LED speed
    555 (~Hz-kHz)      half that    legacy slow mode if ever wanted
    button             1 toggle     single-step: TWO presses = one full CLK
                                    period (press = half-period). Document on
                                    the panel; it is a feature (you can park
                                    the machine mid-state and probe each half).
                                    (2026-07-13: parking after the FIRST press
                                    of an ALU state = the falling edge has
                                    fired — ALU result and flags are frozen
                                    and probeable before the writeback. Probe
                                    heaven; use it in bring-up.)

    Tap selection: one jumper block. Change speed = move one jumper. Nothing
    downstream changes, ever.

## 3. Distribution rules (unchanged in spirit, now official)

- CLK and /CLK are machine-wide hierarchical nets sourced ONLY from the '74.
- SRC_CLK (oscillator output) has exactly one consumer: the divider CP (or
  the '74 CP in max-speed config). Grep rule: any other SRC_CLK reference is
  a bug.
- No local CLK inversions anywhere on any sheet. Consumers import /CLK.
- Route both with clock discipline: short, no stubs, dedicated jumper color
  per phase on the breadboard.
- BOTH EDGES ARE COMMITMENT-CLASS (2026-07-13): rising = register captures +
  '163 advance + PC++; falling = ALU output latch freeze + flags '173 CP
  (via /CLK) + every stamp window opening. Consumer census: CLK → '163,
  stamp NORs (IR, A, B, C, OUT, TMP_A, TMP_B), ALU output latch LE, MDR LE
  chain; /CLK → memory /WE NAND, PC UP//LOAD gates, flags '173 CP. Route to
  the ALU latch LE and '173 CP with the same care as to the '163.
- Phase note for the decode map: CLK and /CLK switch simultaneously (same
  flop). Neither leads. Retire the earlier "/CLK leads by one gate delay"
  note when this is built.

## 4. Package economics

- The '74: one half is this pair generator. The OTHER half is the reset
  release synchronizer (Phase 0.5): D <- raw RC /RESET, CP <- CLK, Q -> the
  '163 /MR combine and PC CLR gate. One package, both clock-domain utilities.
- The '163 divider is a second '163 on the board (the sequencer keeps its
  own). If the parts bin objects, the divider is optional: 4MHz -> '74 = 2MHz
  with no divider at all, and slow modes come from the 555 jumper. But taps
  are cheap and bring-up loves a speed knob.
- U23A/U23B (the buffered-inverter pair from the interim design) return to
  spares. U23C keeps its '138-enable job for the LED display.

## 5. What gets removed / kept

- REMOVE from clock duty: 555 astable as the machine source. KEEP the 555
  circuit physically, jumperable into the SOURCE node, as the slow-mode
  generator. It is already built and it is exactly the right tool for
  LED-speed demos.
- REMOVE: any consumer of the raw oscillator, any local /CLK generation.
- KEEP: single-step pushbutton path (debounce with two cross-coupled NAND
  spares or the classic SR pair) into the SOURCE jumper block.

## 6. Bring-up test plan (clock cluster alone, before anything consumes it)

1. Scope SRC_CLK: 4MHz, whatever duty the can gives (45-55% is fine).
2. Scope each '163 tap: /2 /4 /8 /16, all 50.0% duty.
3. Scope CLK vs /CLK dual-channel at the '74: complementary, transitions
   aligned within scope resolution, 50% duty at the selected tap frequency.
4. Load test: with all sheets connected, re-scope CLK at the FARTHEST
   consumer (memory sheet /WE gate) AND at the ALU latch LE. Edges must stay
   clean; if they slump, the fan-out wants a buffer ('244 sections) at the
   source, not more inverter copies.
5. Single-step mode: two button presses advance exactly one T-state (watch
   the one-hot LEDs). Park mid-state (one press), probe, resume.
6. Duty audit under the DSLogic: capture 1000 periods at 1MHz tap, verify
   half-period jitter is crystal-class (ns), not RC-class (percent).

## 7. Decode map entries

    CLK   = '74 Q,  machine master phase. High = first half (settle; ALU
            output latch transparent), low = second half (capture window).
            Rising edge = register commitment ('163, PC, destinations +
            shadows). Falling edge = ALU commitment (output latch freeze,
            flags capture).
    /CLK  = '74 /Q, exact complement, same flop, no lead/lag. Consumers:
            memory /WE gate, PC gates, flags '173 CP.
    SRC   = jumper: {4MHz can | 555 slow | single-step button} -> divider CP.
    Speed = divider tap jumper: 2M/1M/500k/250k/125k effective CLK.

---

Sequencing: build alongside Phase 0.5 (shares the '74). Everything downstream
was designed against ideal CLK//CLK; this is the sheet that makes the ideal
real. The 555 dies as a master and retires as a demo speed.
