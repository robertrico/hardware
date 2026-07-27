#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "cw_expect.h"

/* Control word board: three '138 decoders + U62 COND gates. Pure
   combinational, NO CLK on this sheet. Rig drives the microcode-side
   inputs (CW0-8) plus FLAG_Z (ALU absent at this stage) and samples every
   decoder/gate output.

   Netlist-verified structure (control_word.kicad_sch, 2026-07-17):
     U30 (CW2:CW1:CW0) dst   O1..O7 = ~{REG_A_LOAD} ~{REG_B_LOAD}
         ~{REG_C_LOAD} ~{MAR_LO_LOAD} ~{MAR_HI_LOAD} ~{IR_LOAD}
         ~{RAM_LOAD}; O0 NC.
     U28 (CW5:CW4:CW3) src   O0 = SRC_ACTIVE (pin 15 — contract OUT since
         the bug-4 U25 bridge fix: LOW only on src=NONE), O1..O7 =
         ~{ROM_OUT} ~{RAM_OUT} ~{REG_A_OUT} ~{REG_B_OUT} ~{REG_C_OUT}
         ~{ALU_OUT} ~{SW_OUT}.
     U29 (CW8:CW7:CW6)       O1=~{PC_CLEAR} O2=~{PC_LOAD_JMP} O3=~{COND}
         O4=~{MDR_OUT} O6=~{REG_OUT_LOAD}; O0/O5/O7 NC.
     All three: E1=E2=GND, E3=+5V — always enabled, outputs totem-pole
     (never high-Z; the old NONE/NC tie-together fight lives in the
     session ledger).
     U62 '02: COND_TAKEN  = NOR(~{COND}, FLAG_Z)          pin 1
              PC_LOAD_JMP = INV(~{PC_LOAD_JMP})           pin 4
              ~{PC_LOAD}  = NOR(COND_TAKEN, PC_LOAD_JMP)  pin 10

   Expected values come from cw_expect.h (host-tested model — see
   hosttest/test_cw_expect.c); every check compares the full 21-signal
   state, so cross-group isolation is baked into every assert.

   Pin layout (kicad_contracts.py PIN_ASSIGN/PIN_PROBES): one unbroken
   D53->D22 descent + the D19 spill, ONE CONTIGUOUS BLOCK PER CHIP —
   each block is the chip's driven address pins (1,2,3) then its outputs
   descending. `pins control_word` prints every wire, probes included.
   CW0-8 are deliberately OFF the PORTC byte here so each CW bit sits
   with its decoder; cw_set() drives them per-pin (settle() dwarfs it).

   Rig-internal probes (in the bundle, but internal nets — not sheet
   contracts): ~{PC_LOAD_JMP} (U29.13), ~{COND} (U29.12), COND_TAKEN
   (U62.1), PC_LOAD_JMP (U62.4). With U62's inputs AND outputs probed,
   a truth-table FAIL names the exact lying gate.

   Driven lines: CW0 CW1 CW2 CW3 CW4 CW5 CW6 CW7 CW8, FLAG_Z (series R).
   Sampled lines: ~{REG_A_LOAD} ~{REG_B_LOAD} ~{REG_C_LOAD}
   ~{MAR_LO_LOAD} ~{MAR_HI_LOAD} ~{IR_LOAD} ~{RAM_LOAD} SRC_ACTIVE
   ~{ROM_OUT} ~{RAM_OUT} ~{REG_A_OUT} ~{REG_B_OUT} ~{REG_C_OUT}
   ~{ALU_OUT} ~{SW_OUT} ~{PC_CLEAR} ~{MDR_OUT} ~{REG_OUT_LOAD}
   ~{PC_LOAD} + probes ~{PC_LOAD_JMP} ~{COND} COND_TAKEN PC_LOAD_JMP
   (coverage: every contract signal named). */

static hwpin_t P_CWD[9], P_Z, P_OUT[CWO_COUNT];
static bool s_bound;
static uint8_t s_gen;

/* enum order of cw_expect.h — index i samples model bit i */
static const char out_names_s0[] PROGMEM = "~{REG_A_LOAD}";
static const char out_names_s1[] PROGMEM = "~{REG_B_LOAD}";
static const char out_names_s2[] PROGMEM = "~{REG_C_LOAD}";
static const char out_names_s3[] PROGMEM = "~{MAR_LO_LOAD}";
static const char out_names_s4[] PROGMEM = "~{MAR_HI_LOAD}";
static const char out_names_s5[] PROGMEM = "~{IR_LOAD}";
static const char out_names_s6[] PROGMEM = "~{RAM_LOAD}";
static const char out_names_s7[] PROGMEM = "SRC_ACTIVE";
static const char out_names_s8[] PROGMEM = "~{ROM_OUT}";
static const char out_names_s9[] PROGMEM = "~{RAM_OUT}";
static const char out_names_s10[] PROGMEM = "~{REG_A_OUT}";
static const char out_names_s11[] PROGMEM = "~{REG_B_OUT}";
static const char out_names_s12[] PROGMEM = "~{REG_C_OUT}";
static const char out_names_s13[] PROGMEM = "~{ALU_OUT}";
static const char out_names_s14[] PROGMEM = "~{SW_OUT}";
static const char out_names_s15[] PROGMEM = "~{PC_CLEAR}";
static const char out_names_s16[] PROGMEM = "~{MDR_OUT}";
static const char out_names_s17[] PROGMEM = "~{REG_OUT_LOAD}";
static const char out_names_s18[] PROGMEM = "~{PC_LOAD_JMP}";
static const char out_names_s19[] PROGMEM = "~{COND}";
static const char out_names_s20[] PROGMEM = "~{PC_LOAD}";
static const char out_names_s21[] PROGMEM = "COND_TAKEN";
static const char out_names_s22[] PROGMEM = "PC_LOAD_JMP";
static const char * const OUT_NAMES[CWO_COUNT] PROGMEM = { out_names_s0, out_names_s1, out_names_s2, out_names_s3, out_names_s4, out_names_s5, out_names_s6, out_names_s7, out_names_s8, out_names_s9, out_names_s10, out_names_s11, out_names_s12, out_names_s13, out_names_s14, out_names_s15, out_names_s16, out_names_s17, out_names_s18, out_names_s19, out_names_s20, out_names_s21, out_names_s22 };

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];                       /* sig_lookup wants RAM */
    strcpy_P(sig, sig_P);
    if (sig_lookup("control_word", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = true;
    static const char cw_names_s0[] PROGMEM = "CW0";
static const char cw_names_s1[] PROGMEM = "CW1";
static const char cw_names_s2[] PROGMEM = "CW2";
static const char cw_names_s3[] PROGMEM = "CW3";
static const char cw_names_s4[] PROGMEM = "CW4";
static const char cw_names_s5[] PROGMEM = "CW5";
static const char cw_names_s6[] PROGMEM = "CW6";
static const char cw_names_s7[] PROGMEM = "CW7";
static const char cw_names_s8[] PROGMEM = "CW8";
static const char * const CW_NAMES[9] PROGMEM = { cw_names_s0, cw_names_s1, cw_names_s2, cw_names_s3, cw_names_s4, cw_names_s5, cw_names_s6, cw_names_s7, cw_names_s8 };
    for (uint8_t i = 0; i < 9; i++)
        ok &= bind1(PN(CW_NAMES, i), &P_CWD[i]);
    ok &= bind1(PSTR("FLAG_Z"), &P_Z);
    for (uint8_t i = 0; i < CWO_COUNT; i++)     /* probes are in the
        bundle too — everything binds by name */
        ok &= bind1(PN(OUT_NAMES, i), &P_OUT[i]);
    if (!ok) return false;                  /* never drive a garbage pin */
    for (uint8_t i = 0; i < CWO_COUNT; i++) rel(&P_OUT[i]);
    for (uint8_t i = 0; i < 9; i++) drv(&P_CWD[i], false);  /* NONE codes */
    drv(&P_Z, true);                        /* Z=1: JNZ-not-taken side */
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static void cw_set(uint16_t cw, bool z) {
    for (uint8_t i = 0; i < 9; i++)
        drv(&P_CWD[i], (cw >> i) & 1);
    drv(&P_Z, z);
    settle();
}

static uint32_t cw_sample(void) {
    uint32_t v = 0;
    for (uint8_t i = 0; i < CWO_COUNT; i++)
        if (smp(&P_OUT[i])) v |= 1UL << i;
    return v;
}

/* drive a state and check EVERY sampled signal against the model — a
   mismatch fails under the signal's own name */
static void check_state(uint16_t cw, bool z) {
    cw_set(cw, z);
    uint32_t got = cw_sample(), want = cw_expect(cw, z ? 1 : 0);
    for (uint8_t i = 0; i < CWO_COUNT; i++)
        if (((got ^ want) >> i) & 1)
            test_check_bool((got >> i) & 1, (want >> i) & 1, PN(OUT_NAMES, i));
}

/* quiet full-state compare for warmup/sweep/stability loops */
static bool state_ok(uint16_t cw, bool z) {
    cw_set(cw, z);
    return cw_sample() == cw_expect(cw, z ? 1 : 0);
}

void t_control_word_warmup(void) {
    test_begin(PSTR("control_word"), PSTR("warmup"));
    if (!bind()) { test_end(); return; }
    /* power-on readiness probe (bench lesson from pc/microcode warmup):
       loop a NONE + all-groups-active vector pair until it holds 4x in a
       row, print the settle time. */
    uint16_t waited_ms = 0;
    uint8_t streak = 0;
    while (streak < 4 && waited_ms < 10000) {
        bool ok = state_ok(0x000, true) && state_ok(0x1FF, true) &&
                  state_ok(0x049, false);   /* dst=1 src=1 jmp=1 */
        if (ok) {
            streak++;
        } else {
            streak = 0;
            _delay_ms(100);
            waited_ms += 100;
        }
    }
    uart_putsP("     ready after ~");
    uart_putdec(waited_ms);
    uart_putsP("ms of settle\r\n");
    test_check_bool(streak == 4, true, PSTR("board_ready_within_10s"));
    test_end();
}

void t_control_word_presence(void) {
    test_begin(PSTR("control_word"), PSTR("presence"));
    if (!bind()) { test_end(); return; }
    /* '138 outputs are totem-pole and always enabled (E1=E2=GND, E3=+5V),
       U62 outputs always driven — a floating line = missing chip or dead
       jumper, and the FAIL names the wire. */
    cw_set(0x000, true);
    for (uint8_t i = 0; i < CWO_COUNT; i++)
        test_check_bool(!floats(&P_OUT[i]), true, PN(OUT_NAMES, i));
    test_end();
}

void t_control_word_walk(void) {
    test_begin(PSTR("control_word"), PSTR("walk"));
    if (!bind()) { test_end(); return; }
    /* dec.walk: each '138 group through all 8 codes, other groups at
       NONE. check_state asserts ALL 23 signals every time, so a stray
       assertion in ANY other group (the old NONE/NC tie-together fight)
       fails right here under the stray signal's name. */
    for (uint8_t shift = 0; shift <= 6; shift += 3)
        for (uint8_t code = 0; code < 8; code++)
            check_state((uint16_t)code << shift, true);
    /* all three groups active at once — decoders must not interact */
    check_state(0x1FF, true);               /* 7/7/7 */
    check_state(0x0AA, true);               /* 2/5/2 */
    check_state(0x155, true);               /* 5/2/5 */
    test_end();
}

void t_control_word_none(void) {
    test_begin(PSTR("control_word"), PSTR("none"));
    if (!bind()) { test_end(); return; }
    /* dec.none: code 000 in every group, both Z values — no named output
       low. SRC_ACTIVE is the exception by design: it IS the src NONE
       decode (U28.O0), so it rests LOW here; the model encodes that. */
    check_state(0x000, false);
    check_state(0x000, true);
    test_end();
}

void t_control_word_truth(void) {
    test_begin(PSTR("control_word"), PSTR("truth"));
    if (!bind()) { test_end(); return; }
    /* cond.truth: the 4 documented U62 rows, asserted directly (labels
       name the row, independent of the model). jmp codes: 010 =
       ~{PC_LOAD_JMP}, 011 = ~{COND}. Both U62 inputs are probed, so a
       FAIL pattern names the lying part: decoder-out wrong = U29,
       COND_TAKEN wrong with good inputs = gate 1 (or the FLAG_Z wire),
       PC_LOAD_JMP wrong = gate 2, only ~{PC_LOAD} wrong = gate 3. */
    cw_set(3 << 6, false);                  /* /COND asserted, Z=0: taken */
    test_check_bool(smp(&P_OUT[CWO_COND_N]), false, PSTR("JNZ_Z0_COND_decoded"));
    test_check_bool(smp(&P_OUT[CWO_COND_TAKEN]), true, PSTR("JNZ_Z0_COND_TAKEN"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_JMP]), false, PSTR("JNZ_Z0_not_JMP"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), false, PSTR("JNZ_Z0_loads"));
    cw_set(3 << 6, true);                   /* /COND asserted, Z=1: not */
    test_check_bool(smp(&P_OUT[CWO_COND_N]), false, PSTR("JNZ_Z1_COND_decoded"));
    test_check_bool(smp(&P_OUT[CWO_COND_TAKEN]), false, PSTR("JNZ_Z1_not_taken"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), true, PSTR("JNZ_Z1_no_load"));
    cw_set(2 << 6, false);                  /* JMP code: Z is don't-care */
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_JMP_N]), false, PSTR("JMP_Z0_decoded"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_JMP]), true, PSTR("JMP_Z0_inverted"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), false, PSTR("JMP_Z0_loads"));
    cw_set(2 << 6, true);
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_JMP]), true, PSTR("JMP_Z1_inverted"));
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), false, PSTR("JMP_Z1_loads"));
    cw_set(0x000, false);                   /* idle: no load either Z */
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), true, PSTR("idle_Z0_no_load"));
    cw_set(0x000, true);
    test_check_bool(smp(&P_OUT[CWO_PC_LOAD_N]), true, PSTR("idle_Z1_no_load"));
    test_end();
}

void t_control_word_sweep(void) {
    test_begin(PSTR("control_word"), PSTR("sweep"));
    if (!bind()) { test_end(); return; }
    /* exhaustive: all 512 CW[8:0] codes x both Z, full 21-signal compare
       each time (~1024 states, well under a second). This is the
       strongest cross-wiring proof — e.g. a CW bit feeding two decoder
       address pins shows up ONLY when both groups run non-walking codes.
       First few mismatching states print their differing signals. */
    uint16_t bad = 0;
    for (uint16_t cw = 0; cw < 512; cw++) {
        for (uint8_t z = 0; z < 2; z++) {
            cw_set(cw, z);
            uint32_t got = cw_sample(), want = cw_expect(cw, z);
            if (got == want) continue;
            bad++;
            if (bad <= 4) {
                uart_putsP("     cw=0x"); uart_puthex16(cw);
                uart_puts(z ? " Z=1:" : " Z=0:");
                for (uint8_t i = 0; i < CWO_COUNT; i++)
                    if (((got ^ want) >> i) & 1) {
                        uart_putc(' '); uart_puts_p(PN(OUT_NAMES, i));
                        uart_puts(((want >> i) & 1) ? "(want 1)"
                                                    : "(want 0)");
                    }
                uart_putsP("\r\n");
            }
        }
    }
    if (bad > 4) uart_putsP("     ... further mismatches suppressed\r\n");
    test_check_u16(bad, 0, PSTR("sweep_mismatch_states"));
    test_end();
}

void t_control_word_stability(void) {
    test_begin(PSTR("control_word"), PSTR("stability"));
    if (!bind()) { test_end(); return; }
    /* edge stress. Decoders are static — ANY flicker here is electrical:
       seating, supply/ground trouble (see the bench ledger smell). */
    uint16_t bad = 0;
    for (uint8_t i = 0; i < 64; i++)        /* same state, repeated */
        if (!state_ok(0x149, true)) bad++;  /* dst=1 src=1 jmp=5 */
    test_check_u16(bad, 0, PSTR("repeat_read_flicker"));
    bad = 0;
    for (uint8_t i = 0; i < 32; i++) {      /* complementary alternation */
        if (!state_ok(0x155, true)) bad++;
        if (!state_ok(0x0AA, false)) bad++;
    }
    test_check_u16(bad, 0, PSTR("alternate_155_0AA"));
    bad = 0;
    for (uint8_t i = 0; i < 32; i++) {      /* all inputs slamming */
        if (!state_ok(0x000, false)) bad++;
        if (!state_ok(0x1FF, true)) bad++;
    }
    test_check_u16(bad, 0, PSTR("slam_000_1FF"));
    test_end();
}
