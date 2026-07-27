#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "reg_expect.h"

/* Registers board: A/B/C register file + OUT exposure register. Lives
   on the MDR bus (W only exists via the mdr sheet's U25 bridge — a
   DIFFERENT module). CLK is rig-driven and only gates the LE stamps.

   Netlist-verified structure (registers_a_b.kicad_sch, 2026-07-20,
   post-U66-consolidation):
     U31/32/33 '373  A/B/C registers — bus-hold latches (D and Q paired
               on the private AB/BB/CB buses), LE = ~{REG_x_LE} (active
               HIGH despite the name), OE = ~{REG_x_OUT}: the register
               drives its private bus only while being read.
     U41/42/43 '245  register-file port: A side = MDR, B side = the
               private bus. DIR = ~{REG_x_OUT} (high: MDR->reg for
               loads; low: reg->MDR for reads). CE = ~{x_EN}.
     U5 '08    ~{x_EN} = AND(~{REG_x_LOAD}, ~{REG_x_OUT}) — port open
               on load OR read, closed at idle (register rule: each
               register's private bus is isolated unless addressed).
     U57 '02   all four LE stamps: ~{REG_x_LE} = NOR(~{REG_x_LOAD},
               CLK) — a load lands only while CLK is LOW.
     U44 '245  OUT path: A = MDR, B = U35's D pins, DIR strapped
               MDR->D, CE = ~{REG_OUT_LOAD} directly.
     U35 '373  OUT register: OE grounded — OB0-7 never float.

   Expected gate values come from reg_expect.h (host-tested model —
   hosttest/test_reg_expect.c). FIGHT RULE (reg_fight): two /OUTs at
   once puts two '245s on MDR — the one-hot src decoder can never
   encode it; the sweep skips it and no test drives it. The LEGAL
   version (one /OUT + another register's /LOAD = a register-to-
   register transfer) is tested explicitly.

   Bus discipline: rig releases MDR before asserting any /OUT; rig
   drives MDR only with all /OUTs idle.

   Rig-internal probes (in the bundle): ~{REG_A_LE} ~{REG_B_LE}
   ~{REG_C_LE} ~{REG_OUT_LE} (U57 outs) + ~{A_EN} ~{B_EN} ~{C_EN}
   (U5 outs) — full stamp/steering observability; a FAIL names the
   lying gate.

   Driven lines: ~{REG_A_LOAD} ~{REG_B_LOAD} ~{REG_C_LOAD}
   ~{REG_OUT_LOAD} ~{REG_A_OUT} ~{REG_B_OUT} ~{REG_C_OUT} CLK
   (series R; MDR jumpers also get series R — rig drives them during
   loads even though the contract marks them DUT-out).
   Sampled lines: OB0 OB1 OB2 OB3 OB4 OB5 OB6 OB7 + the 7 probes.
   Bidir bus: MDR0 MDR1 MDR2 MDR3 MDR4 MDR5 MDR6 MDR7 (PORTF).
   (coverage: every contract signal named). */

static hwpin_t P_IN[RGI_COUNT], P_LOG[RGO_COUNT];
static hwpin_t P_MDR[8], P_OB[8];
static bool s_bound;
static uint8_t s_gen;

/* enum order of reg_expect.h */
static const char in_names_s0[] PROGMEM = "~{REG_A_LOAD}";
static const char in_names_s1[] PROGMEM = "~{REG_B_LOAD}";
static const char in_names_s2[] PROGMEM = "~{REG_C_LOAD}";
static const char in_names_s3[] PROGMEM = "~{REG_OUT_LOAD}";
static const char in_names_s4[] PROGMEM = "~{REG_A_OUT}";
static const char in_names_s5[] PROGMEM = "~{REG_B_OUT}";
static const char in_names_s6[] PROGMEM = "~{REG_C_OUT}";
static const char in_names_s7[] PROGMEM = "CLK";
static const char * const IN_NAMES[RGI_COUNT] PROGMEM = {
    in_names_s0, in_names_s1, in_names_s2, in_names_s3,
    in_names_s4, in_names_s5, in_names_s6, in_names_s7,
};
static const char log_names_s0[] PROGMEM = "~{REG_A_LE}";
static const char log_names_s1[] PROGMEM = "~{REG_B_LE}";
static const char log_names_s2[] PROGMEM = "~{REG_C_LE}";
static const char log_names_s3[] PROGMEM = "~{REG_OUT_LE}";
static const char log_names_s4[] PROGMEM = "~{A_EN}";
static const char log_names_s5[] PROGMEM = "~{B_EN}";
static const char log_names_s6[] PROGMEM = "~{C_EN}";
static const char * const LOG_NAMES[RGO_COUNT] PROGMEM = {
    log_names_s0, log_names_s1, log_names_s2, log_names_s3,
    log_names_s4, log_names_s5, log_names_s6,
};
static const char mdr_names_s0[] PROGMEM = "MDR0";
static const char mdr_names_s1[] PROGMEM = "MDR1";
static const char mdr_names_s2[] PROGMEM = "MDR2";
static const char mdr_names_s3[] PROGMEM = "MDR3";
static const char mdr_names_s4[] PROGMEM = "MDR4";
static const char mdr_names_s5[] PROGMEM = "MDR5";
static const char mdr_names_s6[] PROGMEM = "MDR6";
static const char mdr_names_s7[] PROGMEM = "MDR7";
static const char * const MDR_NAMES[8] PROGMEM = {
    mdr_names_s0, mdr_names_s1, mdr_names_s2, mdr_names_s3,
    mdr_names_s4, mdr_names_s5, mdr_names_s6, mdr_names_s7,
};
static const char ob_names_s0[] PROGMEM = "OB0";
static const char ob_names_s1[] PROGMEM = "OB1";
static const char ob_names_s2[] PROGMEM = "OB2";
static const char ob_names_s3[] PROGMEM = "OB3";
static const char ob_names_s4[] PROGMEM = "OB4";
static const char ob_names_s5[] PROGMEM = "OB5";
static const char ob_names_s6[] PROGMEM = "OB6";
static const char ob_names_s7[] PROGMEM = "OB7";
static const char * const OB_NAMES[8] PROGMEM = {
    ob_names_s0, ob_names_s1, ob_names_s2, ob_names_s3,
    ob_names_s4, ob_names_s5, ob_names_s6, ob_names_s7,
};
/* per-register readback labels */
static const char lbl_a[] PROGMEM = "reg_A";
static const char lbl_b[] PROGMEM = "reg_B";
static const char lbl_c[] PROGMEM = "reg_C";
static const char * const REG_LBL[3] PROGMEM = {lbl_a, lbl_b, lbl_c};

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];                       /* sig_lookup wants RAM */
    strcpy_P(sig, sig_P);
    if (sig_lookup("registers", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = true;
    for (uint8_t i = 0; i < RGI_COUNT; i++) ok &= bind1(PN(IN_NAMES, i), &P_IN[i]);
    for (uint8_t i = 0; i < RGO_COUNT; i++) ok &= bind1(PN(LOG_NAMES, i), &P_LOG[i]);
    for (uint8_t i = 0; i < 8; i++) {
        ok &= bind1(PN(MDR_NAMES, i), &P_MDR[i]);
        ok &= bind1(PN(OB_NAMES, i), &P_OB[i]);
    }
    if (!ok) return false;                  /* never drive a garbage pin */
    /* byte helpers assume the fixed bus ports — guard pinmap moves */
    if (P_MDR[0].pinr != &PINF || P_MDR[7].bit != 7 ||
        P_OB[0].pinr != &PINK || P_OB[7].bit != 7) {
        test_check_bool(false, true, PSTR("MDR_on_PORTF_OB_on_PORTK"));
        return false;
    }
    bus_mdr_release();
    DDRK = 0x00; PORTK = 0x00;              /* OB sampled */
    for (uint8_t i = 0; i < RGO_COUNT; i++) rel(&P_LOG[i]);
    for (uint8_t i = 0; i < RGI_COUNT; i++)
        drv(&P_IN[i], (REG_IDLE >> i) & 1);
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static void reg_set(uint16_t in) {
    for (uint8_t i = 0; i < RGI_COUNT; i++)
        drv(&P_IN[i], (in >> i) & 1);
    settle();
}

static uint8_t log_sample(void) {
    uint8_t v = 0;
    for (uint8_t i = 0; i < RGO_COUNT; i++)
        if (smp(&P_LOG[i])) v |= (uint8_t)(1u << i);
    return v;
}

static uint8_t ob_read(void) { settle(); return PINK; }

#define NO_BIT(b) ((uint16_t)~(1u << (b)))

/* load register r (0=A 1=B 2=C 3=OUT): MDR = v, strobe /LOAD while CLK
   is low (the only phase the LE stamp can open), close, release MDR */
static void load_reg(uint8_t r, uint8_t v) {
    uint16_t clk_lo_s = REG_IDLE & NO_BIT(RGI_CLK);
    bus_mdr_write(v);
    reg_set(clk_lo_s);
    reg_set(clk_lo_s & NO_BIT(RGI_A_LOAD_N + r));   /* LE opens  */
    reg_set(clk_lo_s);                              /* LE closes */
    reg_set(REG_IDLE);
    bus_mdr_release(); settle();
}

/* read register r (0=A 1=B 2=C): /OUT drives the byte onto MDR */
static uint8_t read_reg(uint8_t r) {
    bus_mdr_release();
    reg_set(REG_IDLE & NO_BIT(RGI_A_OUT_N + r));
    uint8_t v = bus_mdr_read();
    reg_set(REG_IDLE);
    return v;
}

void t_registers_warmup(void) {
    test_begin(PSTR("registers"), PSTR("warmup"));
    if (!bind()) { test_end(); return; }
    /* power-on readiness probe: idle gates + a full load/readback +
       an OUT-register load, until stable 4x. Also conditions the
       power-up-undefined latches to known values. */
    uint16_t waited_ms = 0;
    uint8_t streak = 0;
    while (streak < 4 && waited_ms < 10000) {
        reg_set(REG_IDLE);
        bool ok = (log_sample() == reg_expect(REG_IDLE));
        load_reg(0, 0xA5); ok &= (read_reg(0) == 0xA5);
        /* 0xC5, not a palindrome — a mirrored OUT harness must FAIL
           here (0x5A let one through: bit-reverse(0x5A) == 0x5A) */
        load_reg(3, 0xC5); ok &= (ob_read() == 0xC5);
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

void t_registers_presence(void) {
    test_begin(PSTR("registers"), PSTR("presence"));
    if (!bind()) { test_end(); return; }
    /* always-driven lines: 7 gate outputs (totem-pole) + OB0-7 (U35 OE
       grounded). A float = missing chip or dead jumper — FAIL names
       the wire. MDR is covered by `tristate`. */
    reg_set(REG_IDLE);
    for (uint8_t i = 0; i < RGO_COUNT; i++)
        test_check_bool(!floats(&P_LOG[i]), true, PN(LOG_NAMES, i));
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(!floats(&P_OB[i]), true, PN(OB_NAMES, i));
    test_end();
}

void t_registers_logic(void) {
    test_begin(PSTR("registers"), PSTR("logic"));
    if (!bind()) { test_end(); return; }
    /* stamp.gate + EN truth, exhaustive: all 256 input states x all 7
       gate signals vs the host-tested model. Two-/OUT fight states
       skipped and counted (never encodable by the one-hot decoder). */
    uint16_t bad = 0, skipped = 0;
    for (uint16_t in = 0; in < (1u << RGI_COUNT); in++) {
        if (reg_fight(in)) { skipped++; continue; }
        reg_set(in);
        uint8_t got = log_sample(), want = reg_expect(in);
        if (got == want) continue;
        bad++;
        if (bad <= 4) {
            uart_putsP("     in=0x"); uart_puthex16(in);
            for (uint8_t i = 0; i < RGO_COUNT; i++)
                if (((got ^ want) >> i) & 1) {
                    uart_putc(' '); uart_puts_p(PN(LOG_NAMES, i));
                    uart_puts_p(((want >> i) & 1) ? PSTR("(want 1)")
                                                  : PSTR("(want 0)"));
                }
            uart_putsP("\r\n");
        }
    }
    if (bad > 4) uart_putsP("     ... further mismatches suppressed\r\n");
    uart_putsP("     skipped ");
    uart_putdec(skipped);
    uart_putsP(" two-/OUT fight states (by design)\r\n");
    reg_set(REG_IDLE);
    test_check_u16(bad, 0, PSTR("logic_mismatch_states"));
    test_end();
}

void t_registers_load(void) {
    test_begin(PSTR("registers"), PSTR("load"));
    if (!bind()) { test_end(); return; }
    /* load.readback per register: patterns everywhere, per-bit walks
       through A (the walks prove the 8 MDR wires + latch bits; B/C
       get both levels of every bit from 0xFF/0x00/0xAA/0x55). */
    static const uint8_t pat[4] = {0x00, 0xFF, 0xAA, 0x55};
    for (uint8_t r = 0; r < 3; r++)
        for (uint8_t i = 0; i < 4; i++) {
            load_reg(r, pat[i]);
            test_check_u16(read_reg(r), pat[i], PN(REG_LBL, r));
        }
    for (uint8_t b = 0; b < 8; b++) {
        load_reg(0, (uint8_t)(1u << b));
        test_check_u16(read_reg(0), (uint8_t)(1u << b), PSTR("A_walk1"));
        load_reg(0, (uint8_t)~(1u << b));
        test_check_u16(read_reg(0), (uint8_t)~(1u << b), PSTR("A_walk0"));
    }
    /* gating: /LOAD strobed with CLK HIGH must NOT land (U57 stamp) */
    load_reg(0, 0x3C);
    bus_mdr_write(0xC3);
    reg_set(REG_IDLE & NO_BIT(RGI_A_LOAD_N));       /* CLK stays high */
    reg_set(REG_IDLE);
    bus_mdr_release(); settle();
    test_check_u16(read_reg(0), 0x3C, PSTR("load_gated_by_CLK_low"));
    test_end();
}

void t_registers_isolation(void) {
    test_begin(PSTR("registers"), PSTR("isolation"));
    if (!bind()) { test_end(); return; }
    /* three distinct bytes in, three distinct bytes back — loading or
       reading one register must not disturb another */
    load_reg(0, 0xAA);
    load_reg(1, 0x55);
    load_reg(2, 0xC3);
    test_check_u16(read_reg(2), 0xC3, PSTR("C_after_loads"));
    test_check_u16(read_reg(1), 0x55, PSTR("B_after_loads"));
    test_check_u16(read_reg(0), 0xAA, PSTR("A_after_loads"));
    test_check_u16(read_reg(0), 0xAA, PSTR("A_after_reads"));
    test_end();
}

void t_registers_transfer(void) {
    test_begin(PSTR("registers"), PSTR("transfer"));
    if (!bind()) { test_end(); return; }
    /* the legal one-/OUT-plus-one-/LOAD row (register-to-register MOV
       seam): A drives MDR while B loads from it — rig drives NOTHING.
       Proves the CE/DIR steering under real bus traffic. */
    load_reg(0, 0x69);
    load_reg(1, 0x00);
    uint16_t a_out = REG_IDLE & NO_BIT(RGI_A_OUT_N);
    reg_set(a_out);                                 /* A -> MDR      */
    reg_set(a_out & NO_BIT(RGI_CLK));
    reg_set(a_out & NO_BIT(RGI_CLK) & NO_BIT(RGI_B_LOAD_N));  /* B LE */
    reg_set(a_out & NO_BIT(RGI_CLK));               /* B latches     */
    reg_set(a_out);
    reg_set(REG_IDLE);
    test_check_u16(read_reg(1), 0x69, PSTR("B_gets_A"));
    test_check_u16(read_reg(0), 0x69, PSTR("A_unchanged"));
    test_end();
}

void t_registers_outreg(void) {
    test_begin(PSTR("registers"), PSTR("outreg"));
    if (!bind()) { test_end(); return; }
    /* out.reg: /REG_OUT_LOAD protocol -> OB shows the byte permanently
       (OE-grounded exposure register); per-bit walk proves the 8 OB
       wires + latch bits; holds after MDR changes. */
    static const uint8_t pat[4] = {0x00, 0xFF, 0xAA, 0x55};
    for (uint8_t i = 0; i < 4; i++) {
        load_reg(3, pat[i]);
        test_check_u16(ob_read(), pat[i], PSTR("OB_pattern"));
    }
    for (uint8_t b = 0; b < 8; b++) {
        load_reg(3, (uint8_t)(1u << b));
        test_check_u16(ob_read(), (uint8_t)(1u << b), PSTR("OB_walk1"));
    }
    load_reg(3, 0x96);
    bus_mdr_write(0x69); settle();
    bus_mdr_release(); settle();
    test_check_u16(ob_read(), 0x96, PSTR("OB_holds"));
    test_end();
}

void t_registers_tristate(void) {
    test_begin(PSTR("registers"), PSTR("tristate"));
    if (!bind()) { test_end(); return; }
    /* no /OUT asserted -> every register port closed -> MDR floats on
       all 8 bits (the register-rule quiescent contract) */
    reg_set(REG_IDLE);
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(floats(&P_MDR[i]), true, PN(MDR_NAMES, i));
    test_end();
}

void t_registers_stability(void) {
    test_begin(PSTR("registers"), PSTR("stability"));
    if (!bind()) { test_end(); return; }
    /* edge stress: repeated gate reads at two states, then a
       load/readback slam. Flicker = electrical (bench ledger). */
    uint16_t bad = 0;
    uint16_t in_active = REG_IDLE & NO_BIT(RGI_A_OUT_N);
    for (uint8_t i = 0; i < 32; i++) {
        reg_set(REG_IDLE);
        if (log_sample() != reg_expect(REG_IDLE)) bad++;
        reg_set(in_active);
        if (log_sample() != reg_expect(in_active)) bad++;
    }
    reg_set(REG_IDLE);
    test_check_u16(bad, 0, PSTR("gate_flicker"));
    bad = 0;
    for (uint8_t i = 0; i < 16; i++) {
        load_reg(0, 0xAA);
        if (read_reg(0) != 0xAA) bad++;
        load_reg(0, 0x55);
        if (read_reg(0) != 0x55) bad++;
    }
    test_check_u16(bad, 0, PSTR("load_read_slam"));
    test_end();
}
