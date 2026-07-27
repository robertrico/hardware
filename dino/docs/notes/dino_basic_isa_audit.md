# DINO ISA audit + BASIC roadmap (2026-07-16)

Netlist-verified audit of what the buses can actually move, instruction by
instruction, against the goal: SCELBI-class BASIC (SCELBAL lineage — the
8008 proved this ISA class runs BASIC; its whole indirect-addressing story
was one pointer pair (HL) plus an accumulator, which maps to B:C + A here).

Everything below was traced through the kicad-cli netlist
(`/tmp/kicad_netlist_dino_v0_0_2.xml`, 2026-07-16), not the bit map. Where
this doc says "as drawn," it means wire truth.

STATUS: FINDINGS + PROPOSALS. Nothing here is committed hardware; sheet_ops
land only after Rico reviews.

## 1. Bus truth (netlist, 2026-07-16)

Two 8-bit data buses, one bridge:

    W bus                          MDR bus
    drivers:                       drivers:
      U47  ALU out latch             U19  '245 ROM->MDR (~{ROM_OUT})
           (F->W, OE=~ALU_OUT)       U21  '245 RAM<->MDR (~{RAM_MDR_EN})
      SWITCH-GATE1 '244              U41-44 register '245s (/REG_x_OUT)
           (IS->W, ~{SW_OUT})        U18  MDR replay '373 (OE=~MDR_OUT)
      U25 B->A                       U25 A->B
    consumers:                     consumers:
      U34  IR      (D<-W)            register latches (via U41-44)
      U55  MAR_LO  (D<-W)            RAM DQ (via U21)
      U58  MAR_HI  (D<-W)            U18 D (bus-capture)
      U45  TMP_A   (D<-W)
      U46  TMP_B   (D<-W)

U25 ('245, A=W, B=MDR) control, as drawn (U37='04, U39='00, U22='02):

    READS_IDLE = AND(~ROM_OUT, ~RAM_OUT)        [U39a + U37a]
    LE_MDR     = NAND(~RAM_LOAD, READS_IDLE)    [U39b]
    WRITE_DIR  = NOT(~RAM_LOAD)                 [U37b]  DIR: 1 = W->MDR
    ~MDR_EN    = NOR(LE_MDR, MDR_OUT)           [U22b]  CE, active low

So the bridge is ON only during: a memory read, a RAM write, or MDR
replay. Direction is W->MDR only during a RAM write.

## 2. FINDING: bridge logic strands W-side sources (as-drawn bugs)

Electrical result per (src, dst) family — src field [5:3], dst field [2:0]:

    src=ROM/RAM      -> MDR, bridge ON, MDR->W:  every dst reachable. OK.
    misc=/MDR_OUT    -> MDR, bridge ON, MDR->W:  every dst reachable. OK.
    src=ALU, SW      -> W only. Bridge OFF (no strobe trips it).
                        dst=MAR_LO/HI: OK (direct on W).
                        dst=RAM: OK (RAM_LOAD flips DIR, W crosses). 
                        dst=REG_x: *** DEAD — registers load from MDR,
                        nothing crosses. ADD/SUB/... writeback (0x1631
                        family) and INA CANNOT WORK AS DRAWN. ***
    src=REG_x        -> MDR only.
                        dst=REG_y: data lands, *** but TMP shadows load
                        from W, which floats -> MOV to A or B poisons
                        TMP_A/TMP_B. ***
                        dst=MAR_LO/HI: *** DEAD — MAR is on W. Blocks all
                        register-indirect addressing. ***
                        dst=RAM (STA T3, 0x101F): *** BUS FIGHT — RAM_LOAD
                        flips U25 to W->MDR while W floats; U25 drives
                        garbage into REG_A's '245. STA broken as drawn. ***

Three of the seventeen shipped instructions (ADD family writeback, STA
commit) plus the whole BASIC wishlist die on the same root cause. The
2026-07-14 review deferred the real bridge to INT-B2 ("rig EMULATES the
bridge") — this is what it would have found on the bench.

## 3. PROPOSED FIX: steer the bridge from the source field

Root cause: DIR/EN are derived from the *destination* (RAM_LOAD) and the
*memory strobes*, but bus direction is a property of the SOURCE side.

    W_SRC   = OR(ALU_OUT, SW_OUT)         source is W-side (U28 O6/O7,
                                          both active low -> NAND)
    BUS_DIR = W_SRC                       U25 DIR: 1 = W->MDR
    SRC_ACTIVE = NOT(U28.O0) OR MDR_OUT   any source selected (O0 = the
                                          NONE decode, low when idle)
    ~MDR_EN = NOT(SRC_ACTIVE)             bridge ON whenever anything
                                          drives either bus

Then every legal word routes itself:
  - src=ALU dst=REG_A: W->MDR, regs load, shadows see W. ADD lives.
  - src=REG_A dst=RAM: MDR->W (harmless mirror), no fight, U21 steers
    MDR->DQ. STA lives.
  - src=REG_C dst=MAR_LO: MDR->W, MAR latches. INDIRECT ADDRESSING lives.
  - src=REG_B dst=REG_A: MDR->W mirror keeps TMP shadows honest. MOV lives.

IMPORTANT SPLIT: WRITE_DIR is currently overloaded — U25 direction AND the
Memory sheet's write steering (U51: ~RAM_MDR_EN = f(~RAM_OUT, WRITE_DIR)).
The fix must split it: U25 gets BUS_DIR (above); Memory keeps a
RAM_WRITE = NOT(~RAM_LOAD) strobe under the old name or a new label.
U21's 2026-07-14 gating fix must be re-audited against the new signal.

Gate budget (APPLIED + netlist-verified 2026-07-16 — sheet_ops/2026-07-16_
u25_bridge_fix.json + _cw.json; MDR board not yet built so zero rework):
    BUS_DIR    = NAND(~ALU_OUT, ~SW_OUT)      U39 gate3 (spare) -> U25.1
    SRC_ACTIVE = U28.O0 (pin 15, NONE decode,  control_word sheet, NC
                 HIGH when any source chosen)  flag removed + labeled
                 POLARITY NOTE: yes, a '138 output without a bar — O0's
                 low-true event is "NONE selected", which nothing
                 consumes; the bridge wants the complement, and that is
                 high-true by the deselected-output-drives-HIGH rule.
                 Same wire as a hypothetical ~{SRC_NONE}. Free "any of
                 seven sources" OR, no inverter.
    ~MDR_EN    = NOR(SRC_ACTIVE, MDR_OUT)      U22 gate2, pin 5 rewired
                                               from LE_MDR
WRITE_DIR untouched (Memory-sheet U51 steering keeps it); LE_MDR keeps
feeding U18.11 only. No new chips. Notated: session-state bug 4, spec bug
list (4), spec test mdr.bridge.route. Proving tests: mdr.bridge.route +
INT-B2.

## 4. Instruction audit (ISA PoV -> hardware PoV)

"bridge" = needs section-3 fix. "gate" = needs section-5 JC gate. "none" =
works on today's wires.

    Instruction        Encoding sketch (T1+)                Needs
    -- shipped 17 --
    NOP/HALT/JMP/JNZ   (as burned)                          none
    LDAI/LDBI/LDCI     src=ROM dst=REG (via MDR)            none
    LDA                T3 src=RAM dst=REG_A                 none
    STA                T3 src=REG_A dst=RAM                 bridge (fight!)
    ADD..BSUB (8)      T1 src=ALU dst=REG_A                 bridge (dead!)
    OUT                src=REG_A misc=REG_OUT_LOAD          none
    -- proposed, zero new chips (post-bridge-fix) --
    MOV r,r  (6)       src=REG_y dst=REG_x, END             bridge
    LDAX               T1 B->MAR_HI, T2 C->MAR_LO,          bridge
                       T3 MUX=MAR src=RAM dst=REG_A END
    STAX               same, T3 src=REG_A dst=RAM           bridge
    JMPX               same, T3 MUX=MAR PC_LOAD END         bridge
    CMP                T1 src=ALU(SUB) dst=NONE END         none (flags
                       (flags commit, A untouched)           commit rule)
    CPI/ADDI/SUBI      T1 fetch->REG_B, T2 ALU op END       bridge (ADDI/
                       (2-byte immediates, fused LDBI+op)    SUBI), CPI none
    INA                T1 src=SW dst=REG_A END              bridge
    LDR                as LDA but T3 src=ROM dst=REG_A —    none
                       DATA-read from the ROM half (tables,
                       constants, card firmware bytes). The
                       current ISA cannot read ROM data at
                       all: LDA is src=RAM (see section 6)
    -- proposed, small hardware --
    JC/JNC             misc=101 (U29 O5, currently NC)      gate + 1 wire
    JZ                 misc=111 (U29 O7, currently NC)      gate
    -- impossible in microcode, by wire truth --
    CALL/RET           PC drives M only; NO M->W path.      '245 pair + src
                       Link-register idiom instead:          codes (3rd
                       LDBI/LDCI ret-addr; JMP; sub JMPX     EEPROM era)
    INX/DEX (16-bit)   microcode has no conditional          software macro
                       T-sequencing; carry-skip can't        (~8 instr) —
                       happen inside one instruction         interpreter tax
    LDA (addr) mem-    needs MAR increment between the       MAR '373->'163
    indirect           two pointer-byte reads                + strobe

Interpreter model that falls out: A = accumulator, B:C = HL-style pointer
pair, all 16-bit values in RAM. Right shift = ROM lookup tables (256B per
table, src=ROM is free). Multiply/divide = shift-add / restoring division,
left-shift only (MOV B<-A; ADD). SCELBAL-grade slow; accepted.

## 5. Flag branches (the 16-bit math unlock)

FLAG_C is latched on the ALU sheet but never leaves it (contract: only
FLAG_Z exits). JC = one wire (FLAG_C -> control_word) + one U62-family
gate on misc code 101 (U29 O5 currently NC), mirroring the existing JNZ
COND gate. Turns a 16-bit add from ~25 instructions into ~4. Highest-value
gate in this document.

## 6. Memory map + expansion (card slots, ACIA)

Decided direction: memory-mapped I/O. Peripherals are MDR-side citizens,
exactly like RAM — src=RAM/dst=RAM microcode reaches them for free.

REVISED 2026-07-16 (Rico): card space lives in the ROM half, Apple II
option-ROM style — per-slot firmware ROM travels with the card. Rico
DECIDED 2026-07-16: 16K/16K.

    0x0000-0x3FFF  system ROM (U24 — CE must EXCLUDE the card region)
    0x4000-0x7FFF  card region = ~M15 & M14 (one gate) -> '138 on
                   M13-M11 = 8 slots x 2KB. Each slot: the card's own
                   firmware ROM (slots in with the card) + registers.
    0x8000-0xFFFF  RAM, contiguous (NO card carve — cards wanting
                   buffer RAM bring it in their own slot space; keep
                   the interpreter heap unbroken). DINO peripherals are
                   ROM- and RAM-based by design; parts on hand.

STROBE SCHEME (the part that makes it free): DINO memory reads are
double-keyed — microcode picks the strobe, address picks the region.
  - Card REGISTERS answer ~{RAM_OUT}/~{RAM_LOAD} + slot CS. The RAM chip
    is already region-disabled in the low half, so plain LDA/STA reach
    card registers with ZERO new instructions and no contention.
  - Card FIRMWARE ROM answers ~{ROM_OUT} + slot CS — the CPU fetches and
    executes card drivers in place (the option-ROM point).
  - Memory-board change when this lands: U24's CE decode excludes the
    card region.

LATENT ISA GAP (found by this design, applies regardless): LDA's T3 is
src=RAM, so the current ISA cannot DATA-READ the ROM half at all —
executes fine, loads nothing (tables/constants/strings dead). Needs
`LDR abs` = LDA with T3 src=ROM. Pure microcode, post-milestone;
added to the section-4 wishlist.

    First card (top slot): MC6850 ACIA (part on hand, Grant Searle 6809
    lineage; supersedes the DUART idea). RS = M0, /CS from slot decode,
    R/W derived from ~{RAM_OUT} vs WRITE_DIR, E strobe gated by ~{CLK}
    (same timing family as RAM). No on-chip baud gen: card-local
    1.8432MHz can come time, /16 = 115200 baud.

A card slot needs (this is the whole expansion bus):

    M0-15          address (PC/MAR '245s already drive it)
    MDR0-7         data (card drives via its own '245 or open-collector,
                   enabled by /CS AND ~RAM_OUT)
    ~{RAM_OUT}     read strobe        RAM_WRITE      write strobe (the
    ~{CLK}         timing reference                  section-3 split signal)
    /CS_n          per-slot decode of M15..M4
    +5V, GND       power (bulk cap per card, bench rule 2)

Decode cost: one '688 or NAND cluster for the 0xFF page detect + a '138
for slot selects; the page detect also gates RAM's CE so RAM and cards
never fight. The ACIA just hijacks the top slot.

FIRST PERIPHERAL (decided 2026-07-16): the ACIA serial card — MC6850 on
hand, card-local baud oscillator added come time (1.8432MHz can, /16 =
115200). PRE-MILESTONE PROVISION (cheap, not an extension): when the
Memory board is breadboarded, land M0-15, MDR0-7, ~{RAM_OUT}, ~{ROM_OUT}
(card firmware ROMs answer it), WRITE_DIR, ~{CLK}, +5V/GND on a dedicated
expansion header row THEN — no decode
logic yet, just pins. Retrofitting taps into a proven board later is
rework; a dead header row is free. The page-detect/slot decode and the
RAM-CE carve-out stay post-milestone with the rest of section 8.

## 7. Extending the ISA ROM (the "why 3" answer)

DECIDED 2026-07-16 (Rico): third parallel AT28C64B committed — part
already on hand (had three). Socket + 8 spare-line headers go on the
microcode board with the section-3 sheet_ops; bits stay unassigned until
JC/flag-select/MAR++ claim them. Historical footing: parallel PROM slices
were THE control-store pattern (PDP-11/VAX microstores, Am2900 bit-slice
systems at 48-96 bits) — width by paralleling, never one wide chip.

Word width, not chip count: U9+U15 = 16 control bits, ALL assigned —
dst 8/8, src 8/8, SA 8/8, taps 4/4, misc 6/8 (101 and 111 are the last
two codes, spoken for by JC/JZ above). A third AT28C64B in PARALLEL —
same A0-A12, same {IRB,T} address — adds 8 fresh control bits: MAR++
strobe, flag-select field, card strobes, CALL-era M->W enable. That is
the standing relief valve from the design notes.

Mechanics already in place: microcode_gen.py splits words per chip; going
16->24 bits is a table-width change and a third .bin. Board provision =
one more socket + 8 headers, populate never-until-needed.

Opcode space is not a constraint: 17/256 used; every proposed instruction
above fits in 4 T-states of the 16 available.

## 8. Order of operations toward BASIC

GATE (Rico, 2026-07-16): NO ISA extensions until the whole system is
connected, built, and adds two numbers (countdown-demo class milestone).
Steps 3+ are frozen behind that. The bridge fix is NOT an extension — ADD
writeback and STA commit are broken as drawn (section 2), so the milestone
itself requires step 2.

    -- before the milestone --
    1. Bench the microcode board as burned (current 17-instruction bins —
       tests don't care that STA/ADD words have a bridge bug downstream;
       this stage proves ROMs/addressing only).
    2. Review + sheet_ops the section-3 bridge fix; re-run kicad_contracts
       --pinmap; INT-B2 becomes the proving test.
       -> build out remaining modules, integrations, ADD demo runs. GATE.
    -- after the milestone --
    3. JC gate + FLAG_C wire (section 5), third-EEPROM socket (section 7).
    4. Extend microcode_gen.py table: MOV/LDAX/STAX/JMPX/CMP/CPI/ADDI/
       SUBI/INA + JC/JNC/JZ. Re-burn. (Generator asserts already police
       the new words.)
    5. I/O window decode + ACIA card (section 6).
    6. Tiny-BASIC-grade interpreter skeleton; SCELBAL float pack only
       after the integer core runs.
