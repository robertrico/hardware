#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "alu_expect.h"

/* ALU board: two '382 nibbles + the TMP_A/TMP_B shadows + the output
   latch + the zero tree + the flag mux and register. The only board
   with real sequential state on both sides of the clock, so it gets
   ten probes.

   Netlist-verified structure (alu.kicad_sch, 2026-07-24):
     U45/U46 '373  TMP_A / TMP_B shadow latches: D = W0-7 (both from the
               SAME W byte), Q = TA0-7 / TB0-7, OE grounded — the
               shadows always present their operands to the '382s.
               LE_TMP_x = NOR(~{REG_x_LOAD}, CLK)   [U50 g1/g2] — the
               house two-edge stamp: a register load latches the ALU
               operand at the same instant the register file takes it.
     U38/U40 '382  the 8-bit ALU, S2:S1:S0 = SA2:SA1:SA0:
               000 CLEAR  001 B-A  010 A-B  011 A+B
               100 A^B    101 A|B  110 A&B  111 PRESET
               U38 (low) CN = ALU_CIN, CN+4 = CRY -> U40 (high) CN.
               U40 CN+4 = ALU_C, OVR = ALU_V. U38's OVR is NC.
               ALU_CIN = NAND(SA1, SA0)  [U53 g4 -> U50 g4]: ADD and
               SET carry 0, everything else carries 1 — which is what
               makes both subtract codes true two's complement.
     U47 '373  output latch: D = F0-7, Q = W0-7, LE = CLK (transparent
               while CLK is HIGH), OE = ~{ALU_OUT}.
     U52/U53   zero tree: Z = AND(NOR(F0,F1), NOR(F2,F3), NOR(F4,F5),
               NOR(F6,F7)) — high iff all eight result bits are low.
     U48 '157  flag mux, S = ~{ALU_OUT}: with the ALU driving W it
               passes the NEW values (ALU_C, Z, ALU_V, F7); idle it
               feeds the flags back to themselves, so they HOLD.
     U49 '273  flag register: Cp = ~{CLK}, so flags commit on the
               RISING edge of ~CLK = the FALLING edge of CLK.
               ~Mr = ~{RESET} (async clear). Q0-Q3 = FLAG_C, FLAG_Z,
               FLAG_V, FLAG_N; D4-D7 grounded, Q4-Q7 NC.

   Expected results come from alu_expect.h (host-tested model —
   hosttest/test_alu_expect.c, exhaustive over the operand grid). The
   '382 only defines carry and overflow for the three arithmetic codes,
   so `ops` asserts C/V exactly there and reports what the chip did on
   the logic codes without judging it.

   THE OP CYCLE this file uses everywhere (it is the real machine's ALU
   T-state): load the shadows -> set SA -> CLK high (U47 transparent) ->
   ~{ALU_OUT} low (U47 drives W) -> read the result and the
   combinational probes -> CLK low (U47 latches, U49 commits the flags)
   -> read the flags -> release.

   Bus discipline: the rig drives W only while ~{ALU_OUT} is HIGH; the
   moment it goes low U47 owns the bus.

   Rig-internal probes (in the bundle): LE_TMP_A LE_TMP_B (the stamps),
   ALU_CIN (the carry rule), CRY (the nibble ripple — a mis-wired one
   shows as "low nibble right, high nibble off by one"), ALU_C ALU_V Z
   (combinational, before the register) and FLAG_C FLAG_V FLAG_N (after
   it). Having both sides of U49 means a flag FAIL says whether the
   arithmetic or the commit is at fault.

   Driven lines: W0 W1 W2 W3 W4 W5 W6 W7 (during loads) ~{REG_A_LOAD}
   ~{REG_B_LOAD} ~{ALU_OUT} CW9=SA2 CW10=SA1 CW11=SA0 CLK ~{CLK}
   ~{RESET} (series R).
   Sampled lines: FLAG_Z + the ten probes; W0-7 on readback.
   (coverage: every contract signal named). */

static hwpin_t P_ALOAD, P_BLOAD, P_AOUT, P_SA[3], P_CLK, P_CLKN, P_RESETN;
static hwpin_t P_W[8];
static bool s_bound;
static uint8_t s_gen;

/* sampled signals, index order = SIG_* below */
enum {
    SIG_LE_A, SIG_LE_B, SIG_CIN, SIG_CRY,
    SIG_ALU_C, SIG_ALU_V, SIG_Z,
    SIG_FLAG_C, SIG_FLAG_Z, SIG_FLAG_V, SIG_FLAG_N,
    SIG_COUNT
};
static hwpin_t P_SIG[SIG_COUNT];

static const char sig_s0[] PROGMEM = "LE_TMP_A";
static const char sig_s1[] PROGMEM = "LE_TMP_B";
static const char sig_s2[] PROGMEM = "ALU_CIN";
static const char sig_s3[] PROGMEM = "CRY";
static const char sig_s4[] PROGMEM = "ALU_C";
static const char sig_s5[] PROGMEM = "ALU_V";
static const char sig_s6[] PROGMEM = "Z";
static const char sig_s7[] PROGMEM = "FLAG_C";
static const char sig_s8[] PROGMEM = "FLAG_Z";
static const char sig_s9[] PROGMEM = "FLAG_V";
static const char sig_s10[] PROGMEM = "FLAG_N";
static const char * const SIG_NAMES[SIG_COUNT] PROGMEM = {
    sig_s0, sig_s1, sig_s2, sig_s3, sig_s4, sig_s5,
    sig_s6, sig_s7, sig_s8, sig_s9, sig_s10,
};
static const char w_s0[] PROGMEM = "W0";
static const char w_s1[] PROGMEM = "W1";
static const char w_s2[] PROGMEM = "W2";
static const char w_s3[] PROGMEM = "W3";
static const char w_s4[] PROGMEM = "W4";
static const char w_s5[] PROGMEM = "W5";
static const char w_s6[] PROGMEM = "W6";
static const char w_s7[] PROGMEM = "W7";
static const char * const W_NAMES[8] PROGMEM = {
    w_s0, w_s1, w_s2, w_s3, w_s4, w_s5, w_s6, w_s7,
};
static const char sa_s0[] PROGMEM = "CW11=SA0";
static const char sa_s1[] PROGMEM = "CW10=SA1";
static const char sa_s2[] PROGMEM = "CW9=SA2";
static const char * const SA_NAMES[3] PROGMEM = {sa_s0, sa_s1, sa_s2};
/* op names, index = SA code */
static const char op_s0[] PROGMEM = "CLR";
static const char op_s1[] PROGMEM = "BSUB";
static const char op_s2[] PROGMEM = "SUB";
static const char op_s3[] PROGMEM = "ADD";
static const char op_s4[] PROGMEM = "XOR";
static const char op_s5[] PROGMEM = "OR";
static const char op_s6[] PROGMEM = "AND";
static const char op_s7[] PROGMEM = "SET";
static const char * const OP_NAMES[ALU_OPS] PROGMEM = {
    op_s0, op_s1, op_s2, op_s3, op_s4, op_s5, op_s6, op_s7,
};

/* ---- per-pin W access ----
   The Mega pins for this module were assigned to match the breakout strip
   as it is physically wired (pin = slot + 17), so W0-7 lands across PORTA
   and PORTC and is no longer byte-aligned. Drive and sample it per pin;
   settle() dominates either way. */
static void w_write(uint8_t v) {
    for (uint8_t i = 0; i < 8; i++) drv(&P_W[i], (v >> i) & 1);
}

static void w_release(void) {
    for (uint8_t i = 0; i < 8; i++) rel(&P_W[i]);
}

static uint8_t w_read(void) {
    w_release();
    settle();
    uint8_t v = 0;
    for (uint8_t i = 0; i < 8; i++)
        if (smp(&P_W[i])) v |= (uint8_t)(1u << i);
    return v;
}

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];                       /* sig_lookup wants RAM */
    strcpy_P(sig, sig_P);
    if (sig_lookup("alu", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = true;
    ok &= bind1(PSTR("~{REG_A_LOAD}"), &P_ALOAD);
    ok &= bind1(PSTR("~{REG_B_LOAD}"), &P_BLOAD);
    ok &= bind1(PSTR("~{ALU_OUT}"), &P_AOUT);
    ok &= bind1(PSTR("CLK"), &P_CLK);
    ok &= bind1(PSTR("~{CLK}"), &P_CLKN);
    ok &= bind1(PSTR("~{RESET}"), &P_RESETN);
    for (uint8_t i = 0; i < 3; i++) ok &= bind1(PN(SA_NAMES, i), &P_SA[i]);
    for (uint8_t i = 0; i < SIG_COUNT; i++) ok &= bind1(PN(SIG_NAMES, i), &P_SIG[i]);
    for (uint8_t i = 0; i < 8; i++) ok &= bind1(PN(W_NAMES, i), &P_W[i]);
    if (!ok) return false;                  /* never drive a garbage pin */
    w_release();
    for (uint8_t i = 0; i < SIG_COUNT; i++) rel(&P_SIG[i]);
    drv(&P_ALOAD, true);                    /* strobes idle high */
    drv(&P_BLOAD, true);
    drv(&P_AOUT, true);                     /* U47 off the W bus */
    drv(&P_RESETN, true);                   /* not in reset      */
    for (uint8_t i = 0; i < 3; i++) drv(&P_SA[i], false);
    clk_bind(&P_CLK, &P_CLKN);              /* leaves CLK low    */
    clk_hi();
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static bool sig(uint8_t i) { return smp(&P_SIG[i]); }

static void set_op(uint8_t op) {
    for (uint8_t i = 0; i < 3; i++) drv(&P_SA[i], (op >> i) & 1);
    settle();
}

/* Load a shadow latch from W. The stamp only opens with the strobe AND
   the clock low, so this is the register file's protocol exactly. */
static void load_shadow(hwpin_t *strobe, uint8_t v) {
    drv(&P_AOUT, true);                     /* U47 off the bus first */
    w_write(v); settle();
    clk_lo();
    drv(strobe, false); settle();           /* LE opens  */
    drv(strobe, true); settle();            /* LE closes */
    clk_hi();
    w_release(); settle();
}

/* Drive the operands through the '382s and read the combinational
   result off W. Leaves CLK high and ~{ALU_OUT} low. */
static uint8_t compute(uint8_t op, uint8_t a, uint8_t b) {
    load_shadow(&P_ALOAD, a);
    load_shadow(&P_BLOAD, b);
    set_op(op);
    clk_hi();                               /* U47 transparent */
    drv(&P_AOUT, false); settle();          /* U47 drives W    */
    return w_read();
}

/* Read the current result without touching the shadows — compute()
   reloads both operands, so anything testing what the latches HOLD must
   use this instead. */
static uint8_t read_result(uint8_t op) {
    set_op(op);
    clk_hi();
    drv(&P_AOUT, false); settle();
    return w_read();
}

/* Commit: falling CLK clocks U49 through ~{CLK}. With ~{ALU_OUT} still
   low the mux is passing the new values, so the flags take them. */
static void commit(void) {
    clk_lo();
    settle();
}

static void release_alu(void) {
    drv(&P_AOUT, true);
    clk_hi();
    w_release();
    settle();
}

static void reset_flags(void) {
    drv(&P_RESETN, false); settle();
    drv(&P_RESETN, true); settle();
}

void t_alu_power(void) {
    test_begin(PSTR("alu"), PSTR("power"));
    if (!bind()) { test_end(); return; }
    /* PHANTOM-POWER CHECK (house rule since the memory board scored
       7/10 unpowered): hold every rig output at the level that sources
       NO current, then read outputs that must be pulled the other way.
       All-low here means both stamps open (NOR(0,0)=1), the carry rule
       asserts (NAND(0,0)=1), and SA=000 clears the '382s so the zero
       tree goes high — four HIGH outputs across U50 and U53 that an
       unpowered board cannot hold. */
    w_release();
    drv(&P_ALOAD, false); drv(&P_BLOAD, false);
    drv(&P_AOUT, false);                    /* U47 owns W; rig released */
    drv(&P_RESETN, false);
    for (uint8_t i = 0; i < 3; i++) drv(&P_SA[i], false);
    clk_lo();
    drv(&P_CLKN, false);                    /* both clock lines low     */
    _delay_ms(2);                           /* let stolen charge drain  */
    static const uint8_t MUST_BE_HIGH[4] = {SIG_LE_A, SIG_LE_B, SIG_CIN, SIG_Z};
    uint8_t bad = 0;
    for (uint8_t i = 0; i < 4; i++)
        if (!sig(MUST_BE_HIGH[i])) bad++;
    if (bad) {
        /* Only a TOTAL collapse means no supply. A subset failing means
           the chips are alive and something is miswired — say so, because
           the opposite claim sends you to the bench meter for nothing.
           (Bench 2026-07-26: 3 of 4 failed with the supply verified good;
           two of the three were correct readings of real wiring faults.) */
        if (bad == 4)
            uart_putsP("     DUT looks UNPOWERED (or U50/U53 have no VCC):"
                       " with the rig sourcing nothing, these must hold\r\n");
        else
            uart_putsP("     PARTIAL collapse — the chips are powered, this"
                       " is WIRING. These read wrong with the rig sourcing"
                       " nothing:\r\n");
        for (uint8_t i = 0; i < 4; i++)
            if (!sig(MUST_BE_HIGH[i])) {
                uart_putsP("       ");
                uart_puts_p(PN(SIG_NAMES, MUST_BE_HIGH[i]));
                uart_putsP(" want 1, reads 0\r\n");
            }
        uart_puts_p(bad == 4
                    ? PSTR("     check bench 5V before reading any other FAIL"
                           " in this run\r\n")
                    : PSTR("     supply is fine — read the rest of the run\r\n"));
    }
    for (uint8_t i = 0; i < 4; i++)
        test_check_bool(sig(MUST_BE_HIGH[i]), true,
                        PN(SIG_NAMES, MUST_BE_HIGH[i]));
    drv(&P_ALOAD, true); drv(&P_BLOAD, true); drv(&P_AOUT, true);
    drv(&P_RESETN, true);
    clk_hi();
    test_end();
}

void t_alu_warmup(void) {
    test_begin(PSTR("alu"), PSTR("warmup"));
    if (!bind()) { test_end(); return; }
    /* readiness probe: the milestone sum itself, plus a non-palindrome
       logic result so a mirrored W ribbon cannot slip through */
    uint16_t waited_ms = 0;
    uint8_t streak = 0;
    while (streak < 4 && waited_ms < 10000) {
        reset_flags();
        bool ok = (compute(ALU_ADD, 5, 3) == 8);
        commit();
        ok &= !sig(SIG_FLAG_Z);
        release_alu();
        ok &= (compute(ALU_OR, 0xC0, 0x05) == 0xC5);
        release_alu();
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

void t_alu_presence(void) {
    test_begin(PSTR("alu"), PSTR("presence"));
    if (!bind()) { test_end(); return; }
    /* every sampled line is a totem-pole output ('02, '08, '382, '273)
       and is always driven — a float names a missing chip or a dead
       jumper */
    set_op(ALU_CLR);
    release_alu();
    for (uint8_t i = 0; i < SIG_COUNT; i++)
        test_check_bool(!floats(&P_SIG[i]), true, PN(SIG_NAMES, i));
    /* W is driven only while ~{ALU_OUT} is low */
    (void)compute(ALU_SET, 0, 0);
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(!floats(&P_W[i]), true, PN(W_NAMES, i));
    release_alu();
    /* ...and released the moment it goes high (U47 is the only driver) */
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(floats(&P_W[i]), true, PN(W_NAMES, i));
    test_end();
}

void t_alu_gates(void) {
    test_begin(PSTR("alu"), PSTR("gates"));
    if (!bind()) { test_end(); return; }
    /* stamp.gate: LE_TMP_x = NOR(~{REG_x_LOAD}, CLK), 4 rows each */
    drv(&P_AOUT, true);
    for (uint8_t clk = 0; clk < 2; clk++) {
        if (clk) clk_hi(); else clk_lo();
        for (uint8_t ld = 0; ld < 2; ld++) {
            drv(&P_ALOAD, ld); drv(&P_BLOAD, ld); settle();
            test_check_bool(sig(SIG_LE_A), alu_le(ld, clk),
                            PN(SIG_NAMES, SIG_LE_A));
            test_check_bool(sig(SIG_LE_B), alu_le(ld, clk),
                            PN(SIG_NAMES, SIG_LE_B));
        }
    }
    drv(&P_ALOAD, true); drv(&P_BLOAD, true);
    clk_hi();
    /* cin.rule: ALU_CIN = NAND(SA1, SA0) across all 8 select codes —
       this is what makes SUB compute 5-3=2 rather than 1 */
    for (uint8_t op = 0; op < ALU_OPS; op++) {
        set_op(op);
        test_check_bool(sig(SIG_CIN), alu_cin(op) != 0, PN(OP_NAMES, op));
    }
    test_end();
}

void t_alu_shadow(void) {
    test_begin(PSTR("alu"), PSTR("shadow"));
    if (!bind()) { test_end(); return; }
    /* shadow.capture — the latches are observed through the ALU: OR
       with 0x00 passes an operand straight to the result. */
    static const uint8_t pat[4] = {0x00, 0xFF, 0xC5, 0x3A};
    for (uint8_t i = 0; i < 4; i++) {
        load_shadow(&P_BLOAD, 0x00);
        test_check_u16(compute(ALU_OR, pat[i], 0x00), pat[i], PSTR("TMP_A"));
        release_alu();
        load_shadow(&P_ALOAD, 0x00);
        test_check_u16(compute(ALU_OR, 0x00, pat[i]), pat[i], PSTR("TMP_B"));
        release_alu();
    }
    /* per-bit walk proves all eight W->shadow wires on both latches */
    for (uint8_t b = 0; b < 8; b++) {
        uint8_t v = (uint8_t)(1u << b);
        test_check_u16(compute(ALU_OR, v, 0x00), v, PSTR("TMP_A_walk"));
        release_alu();
        test_check_u16(compute(ALU_OR, 0x00, v), v, PSTR("TMP_B_walk"));
        release_alu();
    }
    /* independence: loading B must not disturb A */
    load_shadow(&P_ALOAD, 0xAA);
    load_shadow(&P_BLOAD, 0x55);
    test_check_u16(read_result(ALU_OR), 0xFF, PSTR("A_and_B_both_held"));
    release_alu();
    /* gating: a strobe with CLK HIGH must not land (U50 stamp) */
    load_shadow(&P_ALOAD, 0x3C);
    drv(&P_AOUT, true);
    w_write(0xC3); settle();
    clk_hi();
    drv(&P_ALOAD, false); settle();         /* CLK high: LE stays shut */
    drv(&P_ALOAD, true); settle();
    w_release(); settle();
    load_shadow(&P_BLOAD, 0x00);
    test_check_u16(read_result(ALU_OR), 0x3C, PSTR("load_gated_by_CLK_low"));
    release_alu();
    test_end();
}

void t_alu_ops(void) {
    test_begin(PSTR("alu"), PSTR("ops"));
    if (!bind()) { test_end(); return; }
    /* ops.vectors: every function code across an operand table that
       hits carry, borrow, zero, overflow and sign edges. F comes back
       on W; N and Z are asserted on every op; C and V only where the
       '382 defines them (the arithmetic codes) — for the logic codes
       the observed values are printed once, not judged. */
    static const uint8_t VA[10] = {0x00, 0xFF, 0x7F, 0x80, 0xAA,
                                   0x01, 0x05, 0x03, 0xFF, 0x80};
    static const uint8_t VB[10] = {0x00, 0x01, 0x01, 0x80, 0x55,
                                   0x00, 0x03, 0x05, 0xFF, 0x01};
    uint16_t bad = 0;
    for (uint8_t op = 0; op < ALU_OPS; op++) {
        for (uint8_t i = 0; i < 10; i++) {
            alu_res_t e = alu_eval(op, VA[i], VB[i]);
            uint8_t got = compute(op, VA[i], VB[i]);
            bool zc = sig(SIG_Z), cc = sig(SIG_ALU_C), vc = sig(SIG_ALU_V);
            commit();
            bool fz = sig(SIG_FLAG_Z), fn = sig(SIG_FLAG_N);
            bool fc = sig(SIG_FLAG_C), fv = sig(SIG_FLAG_V);
            release_alu();
            bool row_ok = (got == e.f) && (zc == e.z) && (fz == e.z)
                          && (fn == e.n);
            if (e.cv_defined)
                row_ok = row_ok && (cc == e.c) && (vc == e.v)
                         && (fc == e.c) && (fv == e.v);
            if (row_ok) continue;
            bad++;
            if (bad <= 8) {
                uart_putsP("     "); uart_puts_p(PN(OP_NAMES, op));
                uart_putsP(" a=0x"); uart_puthex8(VA[i]);
                uart_putsP(" b=0x"); uart_puthex8(VB[i]);
                uart_putsP(": F want 0x"); uart_puthex8(e.f);
                uart_putsP(" got 0x"); uart_puthex8(got);
                if (zc != e.z || fz != e.z) uart_putsP(" Z!");
                if (fn != e.n) uart_putsP(" N!");
                if (e.cv_defined && (cc != e.c || fc != e.c)) uart_putsP(" C!");
                if (e.cv_defined && (vc != e.v || fv != e.v)) uart_putsP(" V!");
                uart_putsP("\r\n");
            }
        }
    }
    if (bad > 8) uart_putsP("     ... further mismatches suppressed\r\n");
    /* CHARACTERIZATION, not a verdict. The '382 datasheet defines CN+4
       and OVR only for the arithmetic codes, so asserting a value on
       the logic codes would be testing an accident of this particular
       silicon rather than a contract. Print what the chips actually do
       instead: if a code reads 0/10 or 10/10 the behaviour is constant
       and could be locked in as a regression baseline later; a mixed
       count means C/V track the carry chain and would need modelling.
       FLAG_Z is unaffected either way — it comes from the discrete zero
       tree (U52/U53), not from the '382 — and FLAG_N is just F7. */
    uart_putsP("     '382 C/V where the datasheet defines neither:\r\n");
    for (uint8_t op = 0; op < ALU_OPS; op++) {
        if (alu_eval(op, 0, 0).cv_defined) continue;
        uint8_t nc = 0, nv = 0;
        for (uint8_t i = 0; i < 10; i++) {
            (void)compute(op, VA[i], VB[i]);
            if (sig(SIG_ALU_C)) nc++;
            if (sig(SIG_ALU_V)) nv++;
            release_alu();
        }
        uart_putsP("       "); uart_puts_p(PN(OP_NAMES, op));
        uart_putsP(": C high "); uart_putdec(nc);
        uart_putsP("/10, V high "); uart_putdec(nv);
        uart_putsP("/10\r\n");
    }
    test_check_u16(bad, 0, PSTR("op_vector_mismatches"));
    test_end();
}

void t_alu_flags(void) {
    test_begin(PSTR("alu"), PSTR("flags"));
    if (!bind()) { test_end(); return; }
    /* flags.commit: the '157 mux only presents new values while
       ~{ALU_OUT} is low, so an idle clock edge must leave the flags
       exactly as they were. */
    reset_flags();
    (void)compute(ALU_ADD, 0xFF, 0x01);     /* -> F=0x00, C=1, Z=1 */
    commit();
    test_check_bool(sig(SIG_FLAG_Z), true, PSTR("Z_after_commit"));
    test_check_bool(sig(SIG_FLAG_C), true, PSTR("C_after_commit"));
    release_alu();
    /* idle cycles: operands and op change, ~{ALU_OUT} stays HIGH */
    load_shadow(&P_ALOAD, 0x01);
    load_shadow(&P_BLOAD, 0x01);
    set_op(ALU_ADD);
    for (uint8_t i = 0; i < 4; i++) { clk_lo(); clk_hi(); }
    test_check_bool(sig(SIG_FLAG_Z), true, PSTR("Z_held_over_idle_edges"));
    test_check_bool(sig(SIG_FLAG_C), true, PSTR("C_held_over_idle_edges"));
    /* now the same operands WITH the ALU enabled: flags must update */
    (void)compute(ALU_ADD, 0x01, 0x01);     /* -> F=0x02, C=0, Z=0 */
    test_check_bool(sig(SIG_FLAG_Z), true, PSTR("Z_not_yet_before_edge"));
    commit();
    test_check_bool(sig(SIG_FLAG_Z), false, PSTR("Z_cleared_by_commit"));
    test_check_bool(sig(SIG_FLAG_C), false, PSTR("C_cleared_by_commit"));
    release_alu();
    /* FLAG_N tracks the sign bit of the committed result */
    (void)compute(ALU_ADD, 0x7F, 0x01);     /* -> 0x80, N=1, V=1 */
    commit();
    test_check_bool(sig(SIG_FLAG_N), true, PSTR("N_set_on_negative"));
    test_check_bool(sig(SIG_FLAG_V), true, PSTR("V_set_on_overflow"));
    release_alu();
    test_end();
}

void t_alu_reset(void) {
    test_begin(PSTR("alu"), PSTR("reset"));
    if (!bind()) { test_end(); return; }
    /* flags.reset: ~{RESET} is U49's async ~Mr — it clears all four
       flags with no clock edge at all. */
    (void)compute(ALU_ADD, 0xFF, 0x01);     /* C=1, Z=1 */
    commit();
    release_alu();
    (void)compute(ALU_SET, 0, 0);           /* N=1 too */
    commit();
    release_alu();
    test_check_bool(sig(SIG_FLAG_N), true, PSTR("N_set_before_reset"));
    /* assert reset with the clock parked — no edge may occur */
    drv(&P_RESETN, false); settle();
    test_check_bool(sig(SIG_FLAG_C), false, PSTR("C_cleared_async"));
    test_check_bool(sig(SIG_FLAG_Z), false, PSTR("Z_cleared_async"));
    test_check_bool(sig(SIG_FLAG_V), false, PSTR("V_cleared_async"));
    test_check_bool(sig(SIG_FLAG_N), false, PSTR("N_cleared_async"));
    drv(&P_RESETN, true); settle();
    test_check_bool(sig(SIG_FLAG_Z), false, PSTR("stays_clear_after_release"));
    test_end();
}

void t_alu_carry(void) {
    test_begin(PSTR("alu"), PSTR("carry"));
    if (!bind()) { test_end(); return; }
    /* CRY is U38's CN+4 feeding U40's CN — the wire that makes two
       4-bit slices behave as one 8-bit ALU. A break here reads as
       "low nibble correct, high nibble off by one", so it gets its
       own probe and its own vectors. */
    (void)compute(ALU_ADD, 0x07, 0x07);     /* 0x7+0x7 = 0xE, no ripple */
    test_check_bool(sig(SIG_CRY), false, PSTR("no_ripple_0x07_0x07"));
    test_check_u16(w_read(), 0x0E, PSTR("F_0x0E"));
    release_alu();
    (void)compute(ALU_ADD, 0x0F, 0x01);     /* low nibble overflows     */
    test_check_bool(sig(SIG_CRY), true, PSTR("ripple_0x0F_0x01"));
    test_check_u16(w_read(), 0x10, PSTR("F_0x10_needs_ripple"));
    release_alu();
    (void)compute(ALU_ADD, 0xF0, 0x10);     /* only the high nibble adds */
    test_check_bool(sig(SIG_CRY), false, PSTR("no_ripple_high_only"));
    test_check_bool(sig(SIG_ALU_C), true, PSTR("ALU_C_from_high_nibble"));
    release_alu();
    (void)compute(ALU_ADD, 0xFF, 0x01);     /* ripple all the way out    */
    test_check_bool(sig(SIG_CRY), true, PSTR("ripple_full_width"));
    test_check_bool(sig(SIG_ALU_C), true, PSTR("ALU_C_full_width"));
    test_check_u16(w_read(), 0x00, PSTR("F_wraps_to_zero"));
    release_alu();
    /* the subtract codes borrow through the same wire */
    (void)compute(ALU_SUB, 0x10, 0x01);     /* 0x10-0x01 = 0x0F         */
    test_check_u16(w_read(), 0x0F, PSTR("SUB_borrows_across_nibbles"));
    release_alu();
    test_end();
}

void t_alu_stability(void) {
    test_begin(PSTR("alu"), PSTR("stability"));
    if (!bind()) { test_end(); return; }
    /* edge stress: the '382s are combinational and the shadows are
       static, so any flicker is electrical (bench ledger smell). */
    uint16_t bad = 0;
    for (uint8_t i = 0; i < 32; i++) {
        if (compute(ALU_ADD, 0xC5, 0x3A) != 0xFF) bad++;
        release_alu();
    }
    test_check_u16(bad, 0, PSTR("repeat_add_flicker"));
    bad = 0;
    for (uint8_t i = 0; i < 16; i++) {      /* complementary slam */
        if (compute(ALU_XOR, 0xAA, 0x55) != 0xFF) bad++;
        release_alu();
        if (compute(ALU_AND, 0xAA, 0x55) != 0x00) bad++;
        release_alu();
    }
    test_check_u16(bad, 0, PSTR("alternate_AA_55"));
    bad = 0;
    for (uint8_t i = 0; i < 16; i++) {      /* flags across repeats */
        (void)compute(ALU_SUB, 0x07, 0x07);
        commit();
        if (!sig(SIG_FLAG_Z)) bad++;
        release_alu();
        (void)compute(ALU_SUB, 0x07, 0x06);
        commit();
        if (sig(SIG_FLAG_Z)) bad++;
        release_alu();
    }
    test_check_u16(bad, 0, PSTR("flag_commit_slam"));
    test_end();
}
