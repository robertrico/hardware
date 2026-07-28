# DINO bring-up test suite — design spec (2026-07-14)

Companion to dino_session_state.md (authoritative for architecture facts) and
dino_sheet_contracts.md (generated per-sheet boundary lists — the tests below
implement those contracts).
Status: REVIEWED 2026-07-14 (netlist-verified review), corrections applied.
The review also surfaced three SCHEMATIC bugs (not spec bugs) — fixes are
staged as sheet_ops and tracked in dino_session_state.md:
  (1) microcode EEPROMs U9/U15: ~WE and A12 floating (NC-flagged!) —
      ~WE -> +5V, A12 -> GND;
  (2) memory: U24.~OE / U19.CE anonymous undriven net — missing ~{ROM_OUT}
      label, ROM read path dead as drawn;
  (3) memory: U21 (RAM-side '245) enabled by ~RAM_EN alone — buffers
      floating RAM DQ onto MDR whenever MAR parks on a RAM address with no
      RAM op in flight; fix = U51 spare gates, CE = AND(~RAM_OUT,
      ~WRITE_DIR). Retired forever by memory.idle.release below.
  (4) FOUND 2026-07-16 (bridge audit, dino_basic_isa_audit.md): U25
      W<->MDR bridge DIR/EN keyed on destination, not source — ALU/SW
      writeback dead (ADD cannot commit), STA T3 bus fight, reg->MAR
      blocked. Fix staged (2026-07-16_u25_bridge_fix.json): BUS_DIR from
      src decode, ~MDR_EN from U28.O0 SRC_ACTIVE. Retired by
      mdr.bridge.route below + INT-B2.

## Goal

Bring up the DINO CPU one breadboarded module at a time with an ATmega2560
(Arduino Mega 2560 board, bare-metal C — no Arduino IDE/core) acting as
stimulus, clock, and analyzer. Every sheet's contract boundary and every
integration assumption gets an explicit test. End state: microcode + program
EEPROMs burned (TL866), countdown demo free-running.

## Power and grounding (added per review)

- All module breadboards run from a BENCH 5V supply, not the Mega's
  regulator (11 boards of LS/HC + EEPROMs + RAM is far past the board's
  budget). Mega powered separately (USB), grounds COMMONED at one point.
- One bulk electrolytic (10-47uF) per breadboard rail, plus the per-chip
  0.1uF already in the schematic.
- Multi-board stacks (bench-learned, 2026-07-15): per-board bulk is NOT
  sufficient when supply and return route through different boards — the
  switching-current loop crosses the inter-board jumpers and no per-board
  cap bypasses it. Add a bulk cap ACROSS each board boundary (board A +5V
  to board B GND), and route hot+gnd onto each board as a pair. Symptom
  when missed: threshold-referenced circuits (RC ramps into Schmitt
  inputs) retrigger whenever the neighbor board switches.
- Every rig jumper bundle's FIRST wire is ground (see pin budget section).

## Constraints and decisions

- MCU: ATmega2560 on Mega 2560 board. 5V native — no level shifting needed.
- Toolchain: avr-gcc + avr-libc + Make, flashed via avrdude (`-c wiring`,
  115200, through the board's stk500v2 bootloader). `env.sh` with
  build/flash/monitor functions, same pattern as the STM32 projects.
- Language: C (C99). Assembly only where cycle-exact pulse shaping matters
  (none anticipated — the rig single-steps, DUT logic is static).
- ROM burning: TL866 (dedicated programmer). The rig VERIFIES burned EEPROMs
  but never programs them.
- Modules: breadboards, one per sheet. Rig connects with jumper bundles to
  the module's labeled nets (the MODULE CONTRACT text block on each sheet is
  the hookup list).
- The rig is the clock for module stages 3+ — Y1 (4.096MHz can) out of its
  socket, rig drives CLK and ~CLK as two GPIOs (complementary, never both
  high — see harness API). EXCEPTION (revised): the root stage runs LIVE,
  Y1 seated, rig demoted to monitor + END/HALT driver, reset via the
  physical button. Root's checks are statistical (see root section);
  step-tracking a 1MHz counter from the Mega isn't possible and the hybrid
  workflow beats fake tooling (CLKIN injection, RC force-low) anyway.

## Firmware architecture

One firmware image, all tests compiled in, selected at runtime over UART.

    tests/dino_bringup/
      Makefile            avr-gcc, -mmcu=atmega2560, -Os
      env.sh              source: build / flash / monitor (screen or picocom)
      src/
        main.c            UART shell + test registry
        uart.c/.h         115200 8N1, blocking TX, line-buffered RX
        harness.c/.h      pins, buses, clock, settle, assert machinery
        pinmap.h          ALL rig pin assignments, one place
        test_registry.h   X-macro table: every test = (module, name, fn)
        mod_root.c        per-module test files: standalone tests
        mod_control_word.c
        mod_microcode.c
        mod_registers.c
        mod_alu.c
        mod_pc.c
        mod_mar.c
        mod_memory.c
        mod_mdr.c
        mod_io.c
        integ.c           integration tests (seams listed below)

### UART shell

    > list                 all tests, grouped by module
    > run all              every test in registry order (build-program order)
    > run mar              all tests for one module
    > run mar.tristate     one test
    > pins mar             print the jumper hookup table for that module
    Output per test: PASS / FAIL name, and on FAIL the vector: what was
    driven, what was expected, what was read (bit-level diff).
    Summary line: `N pass, M fail` — greppable.

`run all` is meaningful only when the corresponding module is wired to the
rig; tests for absent modules fail fast on a presence check (see below), so
`run all` is really "run everything that's connected."

### Harness API (harness.h)

    void bus_w_write(uint8_t v);      // W0-7   -> PORTA (whole-port atomic)
    uint8_t bus_w_read(void);         //           DDRA flips for BIDIR nets
    void bus_w_release(void);         // tri-state rig side
    uint16_t bus_m_read(void);        // M0-15  <- PORTC(lo) + PORTL(hi)
    void bus_m_drive(uint16_t v);     //           only for memory-module rig
    void bus_m_release(void);         // hand M bus to the DUT (pc.mux.gate)
    void bus_mdr_write(uint8_t v);    // MDR0-7 <-> PORTF (registers, memory,
    uint8_t bus_mdr_read(void);       //            MDR rigs live on THIS bus)
    void bus_mdr_release(void);
    void ctl(pin_t p, bool level);    // named control line
    bool smp(pin_t p);                // sample named line
    void clk_lo(void); clk_hi(void);  // drives CLK and ~CLK complementary
    void step(void);                  // lo -> settle -> hi -> settle
    void settle(void);                // ~5us: >> any LS prop chain here
    bool floats(pin_t p);             // tri-state check: pullup reads 1,
                                      // pulldown reads 0 => nobody driving
    ASSERT_EQ(expr, want, "label")    // records vector on fail, continues

`floats()` is the tri-state primitive (review-improved, zero extra wires):
drive the line LOW as output, release to input with pullup OFF, read the
capacitance-held 0; then the same from HIGH. If anything drives the net,
the read snaps to the driver instead. Internal-pullup variant kept as a
fallback for slow/leaky nets. Every BIDIR contract line gets one.

Presence check: each module file starts with `presence()` — one cheap vector
that any wired module passes (e.g. MAR: pulse LE with W=0x55, see any M
activity) and an unwired header cannot (all-floating detection). Keeps
`run all` honest.

### Pin budget (pinmap.h, single source of truth)

    PORTA (D22-29)  = W bus (bidir)
    PORTC (D30-37)  = M bus low / CW low (per-module reuse)
    PORTL (D42-49)  = M bus high / CW high
    PORTK (A8-15)   = IRB / IS / OB byte
    PORTF (A0-7)    = MDR byte (registers/memory/MDR rigs live here)
    D2-D13, D14-D21 = named control lines (CLK, ~CLK, RESET, stamps, enables)
    Worst case (review-recounted): control_word 32 signals (incl. the
    COND_TAKEN/PC_LOAD_JMP internal probes), MDR 31, MAR 30. Budget: 40
    port pins + ~20 control pins = 60, >25 spare at worst case.
    Ports are REUSED across modules — pinmap.h defines per-module bundles;
    `pins <module>` prints the active map so rewiring is mechanical.
    pinmap bundles are GENERATED from dino_sheet_contracts.md (small
    emitter added to the contracts tool) so hookup tables can never drift
    from the schematic; hand-tuning allowed only for rig-internal probes.
    EVERY bundle's first wire is GND (common ground before any signal).
    Series 220-470R resistors on every rig-DRIVEN line — when a wiring
    mistake pits the rig against a DUT output, the resistor saves both
    pins. Free at settle()-speed.

## Per-module standalone tests

Convention: every test drives only the module's IN list, samples only its
OUT/BIDIR list (from dino_sheet_contracts.md). "Walk" = walking-1s and
walking-0s. All patterns also include 0x00, 0xFF, 0xAA, 0x55.

MIRROR-WITNESS RULE (added 2026-07-21, registers bring-up lesson): a
write-then-read test through the SAME bus bank is permutation-blind — a
uniformly reversed jumper bank cancels itself and every walk passes.
Each module's suite MUST contain at least one symmetry-breaking path per
bus bank: an asymmetric arithmetic (pc.carry), a cross-bank route
(mdr.bridge, registers.outreg), content-addressed data
(microcode.addr.order), or a decoder truth (control_word). Audited: all
current+planned modules have one. Non-palindromic test bytes only in
readiness vectors (0x5A is bit-reverse-invariant — burned once).

### root (clock + T-state + reset + END/HALT gates) — LIVE, guided
Revised (2026-07-15): hybrid workflow. Y1 SEATED, DUT free-runs; no CLKIN
injection, no RC force-low. Rig drives END, HALT (series R); samples CLK,
~CLK, RESET, ~RESET, T0-3 — contract signals only, 10 jumpers + GND. Reset
is the physical button; armed-watcher tests print `ARM press...`, then
watch the RESET line (10s timeout = FAIL). Measured: RESET stays asserted
for a bench-dependent stretch after button release (0.25-2.2s observed) —
clock gated and T frozen for the duration; post-reset checks wait on the
LINE, never on a hardcoded delay.
Sampling rules (bench-taught): 16MHz rig vs 4.096MHz DUT is exactly 125:32,
so a fixed-period poll phase-locks to the T counter and deterministically
misses counts — coverage checks dither their sample spacing (LFSR). The T
nibble spans two AVR ports, so bits sharing a port are read atomically as
pairs (T1:T0, T3:T2); a 4-read composite stitches bits from different
counts and is never used on a live counter. Counting ORDER is proven on
T3:T2 (states last 4 CLK — tight poll can't skip one; every change must be
+1 mod 4). Frozen-value checks and a hardware edge count do the rest.
1. `clock`: Timer0 external-clock count on CLK (PD7/T0 pin), 100ms gate:
   expect 1024kHz +/-2%. ~CLK toggle check (complementarity at speed is
   scope territory).
2. `tstates`: burst capture — asm loop samples both T ports at 7 cycles/
   sample (437ns, >=2 samples per T state), 1024 samples to SRAM, then an
   offline walk requires every state change be +1 mod 16, rollover
   included (~450 sequential states, ~28 rollovers per run; prints the
   first stretch). Single-sample breaks are dropped as straddle glitches
   when the next sample resyncs (port reads sit 3 cycles apart). Proves
   full-nibble counting order; rate comes from `clock`. TO0-15 one-hot
   decode still checked by EYE (LEDs/scope on debug taps), not by rig
   (review call, unchanged).
3. `reset` (armed): press+hold -> RESET=1, ~RESET=0, T frozen at 0;
   release -> after RC stretch RESET=0, ~RESET=1, T counts again.
   (Sync-release edge timing at 1MHz is not rig-observable — scope check
   during free-run stage.)
4. `halt`: HALT high -> T frozen (any value); low -> resumes. Then HALT
   high + button press -> T frozen at 0 (MR overrides CET).
5. `end`: END high -> T reads 0 (cleared every edge, verifies U61 gate1 +
   sync MR); END low -> counting resumes.

### control_word (decoders + COND gates) — no CLK on this sheet
Rig drives: CW0-8, FLAG_Z. Samples: all decoder outputs + COND_TAKEN,
PC_LOAD_JMP, ~{PC_LOAD}.
1. `dec.walk`: for each '138 group, all 8 codes: exactly the named output
   low, all other outputs of ALL groups high (cross-group isolation baked
   into the same assert — this is where the old NONE/NC fight would show).
2. `dec.none`: code 000 in each group: NO named output low.
3. `cond.truth`: 4-row truth table:
   (/COND=0,Z=0) -> ~PC_LOAD low; (/COND=0,Z=1) -> high;
   (PC_LOAD_JMP code active) -> low regardless of Z; (idle) -> high.
(Review-corrected: the former `taps` test moved to the microcode module —
CW9-15 never enter the control_word board; the tap runs go from the
microcode board straight to their consumers.)

### microcode (2x AT28C64B + address buffers) — EEPROMs pre-burned via TL866
Rig drives: IRB0-7, T0-3. Samples: CW0-15.
1. `addr.order`: with a known diagnostic image (or the real microcode),
   verify IRB0->A4..IRB7->A11 and T0->A0..T3->A3 ordering by reading rows
   whose contents encode their own address (diagnostic burn: word =
   address). Retires the mirror-reversal bug class forever.
2. `word.split`: verify U9 = CW0-7 and U15 = CW8-15 (byte-role check —
   burn matters).
3. `image.crc`: walk all 4096 rows, CRC16 PER CHIP (U9 and U15 separately
   — a mismatch names the chip to reburn), compare against the CRCs the
   image generator printed. Full-ROM verify in-circuit.
4. `taps` (moved here from control_word per review): drive IRB/T to rows
   whose CW9-15 bits are known; sample SA0-2, END, PC_UP, PC_MAR_MUX,
   HALT at the tap ends — verifies the strike-7 tap runs physically.
   INT-A covers the far (consumer) ends.

### registers_a_b (A, B, C, OUT + '245s + LE stamps)
NB (review-corrected): the register file lives on the MDR BUS, not W —
all four '245s (U41-44) have their A-sides on MDR0-7; per-register
internal buses are AB/BB/CB. The W side only exists via the MDR sheet's
U25 bridge, which is a DIFFERENT module. Rig uses PORTF (MDR) here.
Rig drives: MDR0-7, /REG_x_LOAD, /REG_x_OUT, /REG_OUT_LOAD, CLK.
Samples: MDR (readback), OB0-7, LE nets.
1. `stamp.gate`: LE_x = NOR(/LOAD, CLK): asserts only when /LOAD low AND
   CLK low. 4-row truth per register.
2. `load.readback` (per A/B/C): MDR=pattern, pulse load protocol (CLK low
   with /LOAD low, then CLK high), release MDR, assert /REG_x_OUT,
   read MDR.
3. `isolation`: load A=0xAA B=0x55, read both back; assert A unchanged.
4. `tristate`: no /OUT asserted -> MDR floats (floats() on all 8 bits).
5. `out.reg`: /REG_OUT_LOAD protocol -> OB0-7 shows the byte permanently
   (OE grounded exposure register).
6. `no.fight`: assert /REG_A_OUT then also load B in same state — legal
   transfer; then deliberately never assert two /OUTs (rig-level check that
   the '245 CE = AND(load,out) logic isolates each register's local bus
   correctly per the register rule).

### alu (F382s + shadows + output latch + flags + Z-detect)
Rig drives: W0-7, /REG_A_LOAD, /REG_B_LOAD, /ALU_OUT, SA0-2, CLK, ~CLK,
~RESET. Samples: W, FLAG_C/Z/V/N.
1. `shadow.capture`: load-A protocol with W=x -> TMP_A follows (observed
   indirectly: compute later); same B.
2. `ops.vectors` (per op, 8 ops): operand table hits carry, borrow, zero,
   overflow, sign edges: (0,0) (FF,01) (7F,01) (80,80) (AA,55) (01,00) ...
   For each: load A,B; set SA; CLK high (output latch transparent) ->
   /ALU_OUT low, read W = expected F.
3. `flags.commit`: result flags appear ONLY after falling CLK edge with
   /ALU_OUT low (the '157 mux gating); idle cycles don't disturb flags.
4. `flags.reset`: ~RESET clears all four flags async.
5. `cin.rule`: ALU_CIN = NAND(SA1,SA0): ADD carries 0, SUB/BSUB carry 1
   verified through op results (e.g. 5-3=2 not 1).
6. `latch.break`: the A->ALU->A loop: with CLK high, changing A's latch
   (transparent) must NOT ripple to W mid-phase — output latch holds the
   pre-edge F. Single-step observable.

### pc (4x '193 + load/count gating) — IMPLEMENTED (mod_pc.c), netlist-checked
Rig drives: ~PC_LOAD, PC_UP, ~PC_CLEAR, RESET, CLK, ~CLK, M-bus (16, via
U11/U12 '245 PCD path), ~PC_MAR_MUX. Samples: M0-15 (PC drives when
~PC_MAR_MUX low via U13/U14).
Netlist corrections (2026-07-15) folded into the vectors:
- LOAD IS CLK-GATED: U36 makes ~PC_LOAD_STABLE = NAND(PC_LOAD, ~CLK) —
  the '193 load strobe only asserts while CLK is LOW. Load protocol:
  mux high, drive M, CLK low, strobe ~PC_LOAD, restore. A gating row
  (strobe with CLK high -> no load) proves U36 gate 3.
- PC_UP protocol: UP pin = NAND(PC_UP, ~CLK); deasserting PC_UP during
  CLK-low fires a spurious count. Rig (like the real CW timing) changes
  PC_UP only while CLK is high.
- Rig never drives M while ~PC_MAR_MUX is low (U13/U14 would fight it).
Tests: `presence` (reset->0, step->1); `count` (16-step printed walk +
hold with PC_UP low); `carry` (00FF/0FFF/7FFF/FFFF boundaries, ROM_EN=M15
flips at 0x8000); `load` (patterns + walking 1s/0s + CLK-high gating row);
`clear` (merge rows: blocked at CLK high, lands at CLK low, RESET un-gated
both phases); `mux` (high -> 16x floats(), low -> drives); `phase`
(UP-toggle at CLK high no count, falling edge no count, rising edge +1);
`precedence` (CLR dominates ~LOAD, load lands after clear release, RESET
beats count, count continues from loaded value).

### mar
Rig drives: W0-7, /MAR_LO_LOAD, /MAR_HI_LOAD, CLK, PC_MAR_MUX. Samples:
M0-15, ROM_EN(M15), ~RAM_EN, ~PC_MAR_MUX.
1. `latch.lo/hi`: load protocol per byte, walk patterns; other byte
   unchanged (independence).
2. `drive.mux`: PC_MAR_MUX=0 -> M = {HI,LO}; =1 -> M floats + ~PC_MAR_MUX
   low (inverter for the PC side).
3. `decode`: address 0x7FFF -> ROM_EN low(=M15) & ~RAM_EN high; 0x8000 ->
   ROM_EN high & ~RAM_EN low. Both boundary addresses exactly.
4. `stamp.gate`: LE only when /LOAD low AND CLK low (same 4-row truth).

### memory (ROM + RAM + WRITE_DIR steering)
Rig drives: M0-15 (rig owns address bus), ROM_EN/~RAM_EN, /RAM_OUT,
WRITE_DIR, ~CLK, MDR0-7. Samples: MDR0-7.
1. `rom.read`: with TL866-burned known image: read boundary addresses
   0x0000, 0x0001, 0x7FFF; CRC a 256-byte stride sample.
2. `ram.rw`: write/readback walk at 0x8000, 0xFFFF, random-stride set;
   address-uniqueness (write distinct bytes at A and A^0x0001 etc.).
3. `select`: ROM_EN high (RAM region) -> ROM stays off bus; both enables
   verified exclusive across the 0x8000 boundary.
4. `write.window`: RAM ~WE = NAND(WRITE_DIR, ~CLK) (U51 gate2) — write
   lands only inside that window; attempt outside leaves cell unchanged.
5. `idle.release` (added per review — permanently retires the U21 class):
   ~RAM_EN low (MAR parked on a RAM address), ~RAM_OUT high, WRITE_DIR=0
   -> MDR floats() on all 8 bits. FAILS on the pre-review schematic
   (U21 was enabled by ~RAM_EN alone and buffered floating RAM DQ onto
   MDR against legitimate register drivers — e.g. during the ALU
   T-states of any instruction that left a RAM address in MAR). Passes
   after the U51-gate fix: U21 CE = AND(~RAM_OUT, ~WRITE_DIR).

### mdr (MDR + IR + buffers)
Rig drives: W, MDR0-7, /MDR_OUT, /IR_LOAD, /RAM_LOAD, /ROM_OUT, /RAM_OUT,
~{ALU_OUT}, ~{SW_OUT}, SRC_ACTIVE, CLK. Samples: W, IRB0-7, MDR0-7,
WRITE_DIR. (Driven list grew 2026-07-16 with the bug-4 fix: the sheet
consumes ~ALU_OUT/~SW_OUT/SRC_ACTIVE for bridge steering. BUS_DIR is
sheet-INTERNAL — U39.8 -> U25.1 — verify it via bridge.route behavior,
or scope-probe the net directly; it is not a contract line.)
1. `capture`: MDR load protocol from either side per the sheet's steering;
   readback onto W via /MDR_OUT.
2. `ir.snoop`: /IR_LOAD protocol -> IRB0-7 = W byte, holds after W changes.
3. `dir.logic`: WRITE_DIR truth vs /RAM_LOAD//RAM_OUT states; BUS_DIR
   truth vs ~ALU_OUT/~SW_OUT (high iff either W-side source active).
4. `tristate`: nothing enabled, SRC_ACTIVE low -> W floats AND MDR floats
   (bridge fully idle).
5. `bridge.route` (added 2026-07-16, retires schematic bug 4): one row
   per source class — (a) SRC_ACTIVE high, W-side src (~ALU_OUT low):
   rig drives W, byte appears on MDR; (b) SRC_ACTIVE high, MDR-side src
   (both W-side strobes idle): rig drives MDR, byte appears on W;
   (c) /MDR_OUT replay with SRC_ACTIVE low: MDR crosses to W;
   (d) SRC_ACTIVE low, no replay: rig drives MDR, W stays floating
   (bridge off). Walking-1 per row so a single stuck '245 bit names
   itself.

### input_output
Rig drives: /SW_OUT, OB0-7 (as the OUT register substitute). Samples: W0-7.
Human in loop for switches/LEDs:
1. `sw.read`: prompt over serial "set switches to 0xA5", assert /SW_OUT,
   read W, compare; repeat 0x00/0xFF (pull-up + ground-path verify).
2. `led.show`: drive OB=walking 1 with 500ms delay; human confirms each
   LED lights in order (y/n over serial).
3. `sw.tristate`: /SW_OUT high -> W floats.

## Integration tests — SUPERSEDED 2026-07-28 by the BLOCK model

HISTORICAL. The INT-A..INT-E ladder below was written when no module had
been bench-proven and pairwise seams were the only safe unit of work. All
ten modules passed by 2026-07-26, which changes the problem: the modules
are fixtures, so integration is no longer about proving seams two at a
time. It is about building the datapath core ONCE and then growing it in
copper, with the rig retiring a slice per session.

The live plan is BRINGUP.md, "Integration — CONTROL FIRST". Summary:

  BLOCK 1  root + microcode + control_word (THE CONTROL UNIT). ~11 driven
           wires: CLK, RESET, IRB0-7, FLAG_Z. No datapath dependency.
  BLOCK 2  + pc + mar + memory   driven count UNCHANGED — three boards
           join for free, M0-15 and every strobe are copper
  BLOCK 3  + mdr                 11 -> 6 driven: real IR, machine fetches
  BLOCK 4  + registers + alu     6 -> 2 driven: real flags
  BLOCK 5  + io, single-stepped
  BLOCK 6  FREE-RUN, Y1 in socket, 0 driven — 8 wires + GND + HALT

THE GATE IS DRIVEN-WIRE COUNT AND IT MAY NEVER GO UP. Fewer rig wires ==
fewer rig-introduced error modes: the same goal. Risk is asymmetric — a
wrong SAMPLED wire is a false FAIL, a wrong DRIVEN wire can fight a real
driver, and a wrong driven STROBE is worst because strobes are ENABLES,
which is exactly how two boards end up on one bus. The control unit has
the highest fan-out in the machine, so a rig impersonating it builds the
largest and most dangerous harness of the project. Make it real first and
that harness never exists.

(The earlier datapath-core plan had the rig standing in for control across
four boards at once — ~40 driven wires including ~20 strobes. Inverted
2026-07-28 on Rico's wire-count constraint. Control-first also restores
what this spec originally said: INT-A first, because it needs no datapath.)

THREE INSTRUMENTS, THREE QUESTIONS. The rig answers WHAT — logic and
topology, exhaustive, but rig-speed only (settle() is 5us; it CANNOT see
timing). The DSLogic LA answers WHEN — 16ch at real speed: enable overlap,
one-hot T, END->T clear, decode glitches. The scope answers HOW — analog
edge quality, ringing, marginal levels. The Mega can stand in as a first
look (PINA is a true 8ch 62.5ns snapshot, ~3 MSa/s burst capture, Timer1
input capture at 62.5ns resolution) but CANNOT catch a 10-30ns decode
glitch at a ~300ns sample period, sees nothing analog, and has no
pulse-width trigger. Order of use: rig, Mega burst-capture, LA, scope.

cw_expect is now a CHECKER, not a driver: sample the real strobes, compare
against cw_expect(MC_REAL_WORDS[(op<<4)|t], flag_z). Same two generated
headers, same single source of truth — verifying hardware instead of
substituting for it.

Name mapping: INT-A -> Block 3; INT-D -> Block 4; INT-C -> Block 2;
INT-B2 -> Block 1 (its debt is paid inside the core); INT-E -> Block 5;
INT-B DELETED (it emulated the bridge the core keeps real).

--- historical ladder below, kept for the reasoning ---

Chosen where assumptions cross module boundaries; pairs that share no
assumption beyond a verified contract line are NOT tested pairwise.

1. `INT-A control_word+microcode`: rig drives IRB+T only, samples decoder
   outputs + taps. Walk every implemented opcode x T: assert the exact
   control-line pattern the symbolic table promises. Retires: EEPROM
   content, byte split, tap wiring, decode — the single highest-risk seam.
2. `INT-B registers+alu` (review-corrected): registers live on MDR, ALU
   shadows load from W; the real bridge (U25) is on the MDR sheet and not
   wired until stage 10. At stage 6 the RIG EMULATES THE BRIDGE — it owns
   both PORTA (W) and PORTF (MDR) and drives them coherently during loads,
   copying W->MDR on writeback. Executes LDAI 5; LDBI 3; SUB by
   hand-strobing; assert A=2, FLAG_Z=0; SUB to zero -> FLAG_Z=1.
   Retires: shadow timing, two-edge commit discipline. Does NOT retire
   real W<->MDR bus sharing — that's INT-B2.
2b. `INT-B2 registers+alu+mdr (real bridge)`: after stage 10, rerun the
   same sequence with the rig strobing only — data flows through U25.
   THIS retires the W/MDR seam.
3. `INT-C pc+mar+memory`: rig strobes: MAR load 0x8000-window address,
   mux=MAR, RAM write/read; then mux=PC, PC count, ROM fetch stream of 4
   bytes. Retires: M-bus tri-state handoff (the PC_MAR_MUX seam, strike-6
   territory), decode-vs-enable timing.
4. `INT-D root+control_word+microcode (sequencer)`: real T-state counter
   drives microcode T inputs (rig still owns CLK); IRB forced to NOP then
   HALT then a 2-byte op: assert END clears T at the documented state,
   HALT freezes, RESET recovers. Retires: END/HALT/T contract.
5. `INT-E fetch smoke test (near-full system)`: everything wired, rig owns
   only CLK + RESET. ROM program (review-corrected to exercise the
   conditional seam BEFORE free-run):
       LDAI 2; LDBI 1; loop: SUB; OUT; JNZ loop; HALT
   — JNZ taken once (2->1), not taken once (1->0, FLAG_Z=1), so the
   ALU->control_word FLAG_Z run and both U62 branch outcomes are proven
   single-stepped. Sample W, M, IR, T at each edge against a
   cycle-accurate expectation table generated from the microcode
   (int_e_expect.h, emitted by microcode_gen.py so rig and ROM can never
   disagree). Dress rehearsal for free-run.

## Build program (bring-up order)

Each stage = wire module to rig -> `run <module>` green -> earn the
integration test -> module becomes a trusted fixture for later stages.

    1. rig self-test        CLOSED 2026-07-28, not a gate — demoted to a
                            diagnostic. The module tests exercise more of
                            the path than a loopback jumper does; see
                            BRINGUP.md stage 1.
    2. root                 clock/T/reset/END/HALT      (tests: root.*)
                            LIVE stage: Y1 seated, guided (button + serial)
    3. control_word         rig-driven CW               (control_word.*)
    4. microcode            TL866 burn diag image, then real microcode
                            (microcode.*)  -> INT-A, then INT-D
                            (sequencer test needs only stages 2-4)
    5. registers_a_b        (registers.*)
    6. alu                  (alu.*)                     -> INT-B
    7. pc                   (pc.*)
    8. mar                  (mar.*)                     -> INT-C
    9. memory               TL866 burn program ROM: safe-fill HALT +
                            countdown demo               (memory.*)
    10. mdr                 (mdr.*)
    11. input_output        (io.*)
    12. full single-step                                 INT-E
    13. free-run            Y1 in socket, rig demoted to logic-probe mode
                            (passive sampler on OB + HALT line), countdown
                            demo runs, HALT observed. DONE.

    ^ stages 1-11 are DONE (all ten modules bench-proven 2026-07-26; stage
      1 closed as a diagnostic). Stages 12-13 are replaced by the BLOCK
      model — see the superseded-integration note above and BRINGUP.md.

Rationale for the order: every stage's rig can trust everything before it;
control/microcode first because INT-A is the highest-risk seam and needs no
datapath; memory late because it needs MAR's decode as fixture; MDR after
memory because its steering is meaningless untested against a real RAM.

## ROM images (feeds stage 4 and 9)

Separate small tool (host-side Python, not in this spec's firmware):
`microcode_gen.py` — symbolic table (from dino_session_state.md) -> U9.bin
(CW0-7) + U15.bin (CW8-15) + printed PER-CHIP CRC16s (consumed by
`microcode.image.crc`) + the INT-E cycle-accurate expectation table as a C
header (int_e_expect.h) so rig and ROM can never disagree.
Diagnostic image mode for `addr.order`: word encodes its own 12-bit address
in bits [11:0] and the INVERTED top address nibble in bits [15:12] — stuck-
high data lines get caught too (review refinement).
`asm/countdown.py` — hand-assembled demo (with the JNZ loop, see INT-E) ->
program.bin, safe-fill = HALT opcode. Burn all via TL866.
`coverage_lint.py` — diffs the test definitions against
dino_sheet_contracts.md and reports any contract line no test drives or
samples: "every boundary tested" as an invariant, not an intention.
(All three implemented in the plan phase, not this firmware.)

## Failure-handling conventions

- Tests continue after FAIL (full vector diff printed), summary at end —
  one wiring mistake shouldn't hide the next three.
- Every FAIL prints the contract line it tests, so the fix starts at the
  right net name.
- settle() is deliberately huge (µs vs ns) — timing bugs are NOT chased at
  rig speed; INT-E plus free-run are where real-time behavior is proven,
  scope on the T-state taps (TO0-15, their day in the sun).

## Out of scope

- Automated LED/switch verification (human-in-loop by design).
- Testing at speed (1MHz) — free-run + scope territory.
- PCB test headers — breadboard jumpers now; contracts make later
  migration mechanical.
