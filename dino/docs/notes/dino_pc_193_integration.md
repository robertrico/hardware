# DINO PC integration: 74LS193 control wiring

Machine: DINO v0.0.2 → v0.0.3, sheet /Program Counter/ (program_counter.kicad_sch)
Status: PC counters + four '245s exist and are wired. Control pins were bench-tested
with buttons and DIP switches only; never wired to the control system. This document
is the integration spec: what replaces the buttons, why, and how to prove it.

Companion: dino_121_elimination_plan.md (clock discipline, LE gating stamp, timing
budget). This document assumes its section 0 (one edge per state, first half = settle,
second half = destination window, closing edge = commitment).

---

## 0. Why the '193 needs special handling

The timer-state counter is a 74LS163: fully synchronous, every control pin sampled
at the clock edge. The PC is 4x 74LS193: a different, older discipline. Three of its
control pins are asynchronous or edge-clocked in ways that violate the one-edge-per-
state law unless gated:

- UP (pin 5) is a CLOCK INPUT, not an enable. The chip counts on rising edges OF THE
  UP PIN. A control-word level cannot drive it directly.
- /LOAD (pin 11) is ASYNCHRONOUS and level-sensitive: the counter is transparent to
  its D inputs the entire time /LOAD is low.
- CLR (pin 14) is ASYNCHRONOUS active-high: any pulse, including decode ripple from
  the '138s at state boundaries, zeroes PC instantly and silently.

Decode ripple is real: the microcode EEPROM output scrambles for tens of ns after
every state boundary while its address changes, and the downstream '138s briefly
decode false codes. Synchronous inputs ignore this (they sample at the edge, when
everything is long stable). Asynchronous inputs act on it. Therefore every async
'193 pin gets phase-gated so it can only assert during the second half of a state,
when the control word has been stable for hundreds of ns.

## 1. The wiring (three gates + one strap)

Signals assumed to exist: CLK and /CLK (both from the clock cluster's '74 pair —
see dino_clock_refactor.md; no local inversions), PC_UP_ctl (control word bit 13),
/PC_CLEAR (U29 O1, [8:6]=001, active low), /PC_LOAD (U29 O2, [8:6]=010 - the code
formerly named PC_PRESET, active low), /RESET (from the Phase 0.5 reset circuit).

### 1a. UP - edge forming (functional requirement, not protection)

    UP_pin = NAND(PC_UP_ctl, /CLK)

Behavior: control bit low -> pin idles high, no edges, no counting. Control bit
high -> pin sits low through the second half, RISES at the state's closing edge ->
PC counts exactly on the machine edge. One NAND gate.

Without this gate PC does not count at all (or counts on decode transitions at
wrong times). This is the translation layer between "PC_UP is asserted this state"
and the pin's edge-clocked semantics.

Wire to U1 pin 5 (low byte, bits 0-3). Upper chips receive carry, not this signal.
(Replaces the test-button/DIP-era feed on the same pin.)

### 1b. DOWN - strap

U1 pin 4 to +5V. No ISA use for PC_DOWN. (Future: mirror NAND off a spare control
bit if ever wanted. Noted, not built.)

### 1c. CLR - ripple-gated, reset-merged

    CLR_pin = NOR(/PC_CLEAR_gated_input, CLK)
    where the input side merges decode and reset:
    /PC_CLEAR_gated_input = AND(/PC_CLEAR, /RESET)     [active-low OR]

Behavior: assertion possible only in a second half, when the decode is stable.
A ripple flicker on /PC_CLEAR during the first half cannot reach the pin (CLK high
holds the NOR low). Power-on/button reset holds the input active across many edges,
so gating costs reset nothing - it asserts in every second half until released.

Wire to CLR on all four '193s (verify whether pin 14 is bused on the sheet; bus it
if not - all four must clear together).

### 1d. /LOAD - phase-gated transparent window

    /LOAD_pin = NAND(PC_LOAD_decoded_active_high, /CLK)

(If consuming U29's active-low O2 directly, invert first or restructure; note the
final gate choice here when built: ____________)

Behavior: in the JMP T3 state (MUX=MAR, PC_LOAD, END), /LOAD drops for the second
half only. MAR has been driving the M bus through its '245s since early in the
state; the '193s go transparent onto a stable bus, track it, and seal at the
closing edge. The async load becomes a half-period latch window - the same door
rhythm as every '373 in the machine.

Wire to /LOAD on all four '193s (bused).

Gate budget: 2 NAND + 1 NOR + 1 AND-equivalent. All available from existing spares
(U5/U10 have free gates; /CLK arrives from the clock cluster).

## 2. Carry chain - CONFIRMED order and budget

Chain: U1 -> U2 -> U3 -> U4, LO to HI.
    U1 = bits 0-3, U2 = bits 4-7, U3 = bits 8-11, U4 = bits 12-15.
U4 is terminal: its /CO and /BO no-connects are correct as drawn.

(Verification note, 2026-07-11: two recalled orders and one schematic misread -
C4's designator sitting beside U3 was read as "U4" - all disagreed before the
drawing was traced properly. Drawing order = chain order = significance order.
Probe 4's rollover tests remain the copper-level certification.)

Inter-stage /BO -> DOWN wiring exists in parallel with /CO -> UP. LEAVE IT. It is
the textbook '193 cascade and it is dormant: with U1's DOWN strapped high, no
down-clock ever enters the chain, so no borrow is ever generated and the entire
/BO network idles high forever. Pulling it would be layering surgery to remove
wires that are harmless and would be re-added if PC_DOWN ever gets a control bit.

Cross-check with the '245s: U1/U2 Q pins must feed the low-byte driver, U3/U4 the
high-byte driver, or the M bus reads scrambled at nibble boundaries.

Timing consequence: the carry RIPPLES. On rollover (xxFF -> x100 etc.) each stage
counts ~15ns after the one below it. Worst case (FFFF -> 0000) PC is not fully
stable until ~45-60ns after the edge.

This is acceptable and already inside the design's post-edge settling window (the
same window that covers '163+'138 decode lag), but it belongs in the timing budget
as a line item:

    PC valid = closing edge + ~15ns x (stages that roll), worst ~60ns.
    Consumed by: M bus -> memory tACC (150ns) which begins after PC settles.
    At 1MHz bring-up: irrelevant. At the ~3MHz ceiling: still inside the first
    half-period with margin; do not let it surprise a future fmax calculation.

## 3. What gets removed

- The test buttons on /LOAD and CLR and their wiring.
- The DIP-switch feed on the '245 load path (U11/U12 side) - or keep it jumperable:
  it is exactly the right test fixture for section 4 and for MAR bring-up later.
- Any PULSE_REQ-era wiring toward UP/DOWN if present (audit the sheet; the old
  design may have intended a '121-derived pulse here - it dies with the rest).

## 4. Test plan (first half of Phase 4; PC is the register everything depends on)

Fixture: 555 at ~1Hz or single-step button. Control signals forced by jumper -
the microcode EEPROM is NOT required for any of this. Sixteen LEDs on the M bus
(enable U13/U14 by jumpering /PC_MUX active) = PC display. Keep the one-hot state
LEDs visible beside it.

1. COUNT: jumper PC_UP_ctl high, all else idle. PC increments once per clock,
   exactly at the rising edge, never between. Scope UP_pin against CLK: rising
   edge of UP_pin aligned to closing edge.
2. GATED CLR: mid-count, force /PC_CLEAR low. PC zeroes at the NEXT edge's second-
   half assertion - never asynchronously mid-first-half. Release; counting resumes.
3. GATED LOAD: put a known pattern on the M bus via DIP switches (through the
   existing '245 load path or a spare '244). Force the PC_LOAD decode. PC captures
   the pattern; verify it tracked only during the second half (scope /LOAD_pin
   against CLK).
4. CARRY BOUNDARIES: preload and count across each chip boundary:
       0x00FF -> 0x0100   (first boundary)
       0x0FFF -> 0x1000   (second)
       0xFFFF -> 0x0000   (full wrap)
   One swapped carry wire hides for months; these three probes cover every
   boundary in five minutes.
5. RESET: press the reset button mid-count. PC parks at 0x0000 and holds while
   pressed (asserting every second half); releases cleanly; counting resumes on
   the next PC_UP state.

Pass criteria: all five behaviors exactly as described, captured once on the
DSLogic for the log book. PC is then PROVEN, not presumed.

## 5. Decode map entries (append to the constitution's decode map page)

    PC++      means: bit13=1 -> NAND w/ /CLK -> UP pin edge at closing edge
    PC_CLEAR  means: [8:6]=001 -> /PC_CLEAR -> reset-merge -> NOR w/ CLK ->
                     CLR pin, second-half assertion, zeroes at edge
    PC_LOAD   means: [8:6]=010 -> gate w/ /CLK -> /LOAD pin, transparent window
                     second half, seals at edge; requires MUX=MAR same state
    (U1 DOWN strapped high; inter-stage /BO->DOWN wiring retained but dormant;
     carry chain U1->U2->U3->U4, LO->HI, U4 terminal)

---

Sequencing: this work is Phase 2 material (second of the three '121-era areas,
even though this sheet's sin is async pins rather than a literal '121). Wire the
gates, run section 4, and the machine's most depended-upon register is done.
