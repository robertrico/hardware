#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "mar_expect.h"

/* MAR board: LO/HI address latches + the MAR->M port + the two board
   decodes. CLK is rig-driven and only gates the LE stamps.

   Netlist-verified structure (mar.kicad_sch, 2026-07-22):
     U55/U58 '373  LO/HI latches: D = W0-7 (BOTH from the same W byte,
               separate LEs), Q = private MAR0-15, OE grounded — the
               latches always drive the private bus; no fight class
               exists on this board.
     U54/U59 '245  MAR -> M port: DIR strapped A->B, CE = PC_MAR_MUX
               plain (enabled at 0 — the bit map's "PC=1, MAR=0").
     U60 '02   all four gates, zero spares:
               LE_MAR_LO = NOR(~{MAR_LO_LOAD}, CLK)   (house stamp)
               LE_MAR_HI = NOR(~{MAR_HI_LOAD}, CLK)
               ~{RAM_EN} = INV(M15) — decodes the BUS, so the RAM
               strobe is correct no matter who drives M (PC at fetch,
               MAR at execute)
               ~{PC_MAR_MUX} = INV(PC_MAR_MUX) — complementary enables
               for the PC-side '245s

   Expected gate values come from mar_expect.h (host-tested model —
   hosttest/test_mar_expect.c).

   Bus discipline: rig NEVER drives M while PC_MAR_MUX=0 (U54/U59 own
   the bus); rig may drive M only at mux=1 (emulating the PC side).
   W is rig-driven whenever needed — nothing here ever drives W.

   Rig-internal probes (in the bundle): LE_MAR_LO (U60.1), LE_MAR_HI
   (U60.4).

   Driven lines: ~{MAR_LO_LOAD} ~{MAR_HI_LOAD} CW14=PC_MAR_MUX CLK
   (series R) + W0 W1 W2 W3 W4 W5 W6 W7 (PORTA, series R).
   Sampled lines: ~{RAM_EN} ~{PC_MAR_MUX} LE_MAR_LO LE_MAR_HI + M0 M1
   M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14 M15=ROM_EN
   (PORTC+PORTL, bidir at mux=1).
   (coverage: every contract signal named). */

static hwpin_t P_IN[4], P_LOG[MRO_COUNT];   /* P_IN order = MRI_* 0..3 */
static hwpin_t P_M[16];
static bool s_bound;
static uint8_t s_gen;

static const char in_names_s0[] PROGMEM = "~{MAR_LO_LOAD}";
static const char in_names_s1[] PROGMEM = "~{MAR_HI_LOAD}";
static const char in_names_s2[] PROGMEM = "PC_MAR_MUX";   /* CW14 alias */
static const char in_names_s3[] PROGMEM = "CLK";
static const char * const IN_NAMES[4] PROGMEM = {
    in_names_s0, in_names_s1, in_names_s2, in_names_s3,
};
static const char log_names_s0[] PROGMEM = "LE_MAR_LO";
static const char log_names_s1[] PROGMEM = "LE_MAR_HI";
static const char log_names_s2[] PROGMEM = "~{PC_MAR_MUX}";
static const char log_names_s3[] PROGMEM = "~{RAM_EN}";
static const char * const LOG_NAMES[MRO_COUNT] PROGMEM = {
    log_names_s0, log_names_s1, log_names_s2, log_names_s3,
};
static const char m_names_s0[] PROGMEM = "M0";
static const char m_names_s1[] PROGMEM = "M1";
static const char m_names_s2[] PROGMEM = "M2";
static const char m_names_s3[] PROGMEM = "M3";
static const char m_names_s4[] PROGMEM = "M4";
static const char m_names_s5[] PROGMEM = "M5";
static const char m_names_s6[] PROGMEM = "M6";
static const char m_names_s7[] PROGMEM = "M7";
static const char m_names_s8[] PROGMEM = "M8";
static const char m_names_s9[] PROGMEM = "M9";
static const char m_names_s10[] PROGMEM = "M10";
static const char m_names_s11[] PROGMEM = "M11";
static const char m_names_s12[] PROGMEM = "M12";
static const char m_names_s13[] PROGMEM = "M13";
static const char m_names_s14[] PROGMEM = "M14";
static const char m_names_s15[] PROGMEM = "M15=ROM_EN";
static const char * const M_NAMES[16] PROGMEM = {
    m_names_s0, m_names_s1, m_names_s2, m_names_s3,
    m_names_s4, m_names_s5, m_names_s6, m_names_s7,
    m_names_s8, m_names_s9, m_names_s10, m_names_s11,
    m_names_s12, m_names_s13, m_names_s14, m_names_s15,
};
static const char w_names_s0[] PROGMEM = "W0";
static const char w_names_s1[] PROGMEM = "W1";
static const char w_names_s2[] PROGMEM = "W2";
static const char w_names_s3[] PROGMEM = "W3";
static const char w_names_s4[] PROGMEM = "W4";
static const char w_names_s5[] PROGMEM = "W5";
static const char w_names_s6[] PROGMEM = "W6";
static const char w_names_s7[] PROGMEM = "W7";
static const char * const W_NAMES[8] PROGMEM = {
    w_names_s0, w_names_s1, w_names_s2, w_names_s3,
    w_names_s4, w_names_s5, w_names_s6, w_names_s7,
};

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];                       /* sig_lookup wants RAM */
    strcpy_P(sig, sig_P);
    if (sig_lookup("mar", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = true;
    hwpin_t w;
    for (uint8_t i = 0; i < 4; i++) ok &= bind1(PN(IN_NAMES, i), &P_IN[i]);
    for (uint8_t i = 0; i < MRO_COUNT; i++)
        ok &= bind1(PN(LOG_NAMES, i), &P_LOG[i]);
    for (uint8_t i = 0; i < 16; i++) ok &= bind1(PN(M_NAMES, i), &P_M[i]);
    for (uint8_t i = 0; i < 8; i++) {
        ok &= bind1(PN(W_NAMES, i), &w);
        /* bus_w_write drives PORTA whole — guard pinmap moves */
        if (ok && (w.port != &PORTA || w.bit != i)) {
            test_check_bool(false, true, PSTR("W_bus_on_PORTA_ascending"));
            return false;
        }
    }
    if (!ok) return false;                  /* never drive a garbage pin */
    if (P_M[0].pinr != &PINC || P_M[8].pinr != &PINL || P_M[15].bit != 7) {
        test_check_bool(false, true, PSTR("M_bus_on_PORTC_PORTL"));
        return false;
    }
    bus_w_release();
    bus_m_release();
    for (uint8_t i = 0; i < MRO_COUNT; i++) rel(&P_LOG[i]);
    for (uint8_t i = 0; i < 4; i++)
        drv(&P_IN[i], (MAR_IDLE >> i) & 1);     /* mux=0: MAR owns M */
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static void mar_set(uint8_t in) {           /* control nibble, MRI_* order */
    for (uint8_t i = 0; i < 4; i++)
        drv(&P_IN[i], (in >> i) & 1);
    settle();
}

static uint8_t log_sample(void) {
    uint8_t v = 0;
    for (uint8_t i = 0; i < MRO_COUNT; i++)
        if (smp(&P_LOG[i])) v |= (uint8_t)(1u << i);
    return v;
}

#define NO_BIT(b) ((uint8_t)~(1u << (b)))

/* latch one half: W = v, strobe the /LOAD while CLK is low */
static void mar_load(uint8_t half_bit, uint8_t v) {
    uint8_t clk_lo_s = MAR_IDLE & NO_BIT(MRI_CLK);
    bus_w_write(v);
    mar_set(clk_lo_s);
    mar_set(clk_lo_s & NO_BIT(half_bit));           /* LE opens  */
    mar_set(clk_lo_s);                              /* LE closes */
    mar_set(MAR_IDLE);
    bus_w_release(); settle();
}

static void load16(uint16_t a) {
    mar_load(MRI_LO_LOAD_N, (uint8_t)a);
    mar_load(MRI_HI_LOAD_N, (uint8_t)(a >> 8));
}

static uint16_t m_read(void) { settle(); return bus_m_read(); }

void t_mar_warmup(void) {
    test_begin(PSTR("mar"), PSTR("warmup"));
    if (!bind()) { test_end(); return; }
    /* readiness probe; 0xC53A / 0x3AC5 are non-palindromes (mirror-
       witness rule) and exercise both halves both ways */
    uint16_t waited_ms = 0;
    uint8_t streak = 0;
    while (streak < 4 && waited_ms < 10000) {
        mar_set(MAR_IDLE);
        bool ok = ((log_sample() & ~(1u << MRO_RAM_EN_N))
                   == (mar_expect(MAR_IDLE) & ~(1u << MRO_RAM_EN_N)));
        load16(0xC53A); ok &= (m_read() == 0xC53A);
        load16(0x3AC5); ok &= (m_read() == 0x3AC5);
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

void t_mar_presence(void) {
    test_begin(PSTR("mar"), PSTR("presence"));
    if (!bind()) { test_end(); return; }
    /* mux=0: latches drive the private bus, the '245s drive M — every
       M line plus all four gate outputs must be driven. FAIL names
       the wire. */
    mar_set(MAR_IDLE);
    for (uint8_t i = 0; i < MRO_COUNT; i++)
        test_check_bool(!floats(&P_LOG[i]), true, PN(LOG_NAMES, i));
    for (uint8_t i = 0; i < 16; i++)
        test_check_bool(!floats(&P_M[i]), true, PN(M_NAMES, i));
    test_end();
}

void t_mar_logic(void) {
    test_begin(PSTR("mar"), PSTR("logic"));
    if (!bind()) { test_end(); return; }
    /* stamp + decode truth, exhaustive: all 16 control states at both
       M15 levels. M15 is set through the latch at mux=0 (proving the
       MAR-side decode) and rig-driven at mux=1 (proving the decode
       follows the BUS — the U60 subtlety). */
    uint16_t bad = 0;
    for (uint8_t m15 = 0; m15 < 2; m15++) {
        uint8_t hb = m15 ? 0x80 : 0x00;
        /* mux=0 rows: latch MAR15 = m15, then HOLD W at the same byte
           for the whole pass — sweep states that re-open the HI latch
           (hi_load+clk low) recapture the SAME value, so the latched
           M15 can never diverge from the expectation. (First cut
           released W here and compared against charge decay — a
           board-dependent test bug.) */
        mar_load(MRI_HI_LOAD_N, hb);
        bus_w_write(hb);
        for (uint8_t c = 0; c < 16; c++) {
            if ((c >> MRI_MUX) & 1) continue;
            mar_set(c);
            uint8_t got = log_sample();
            uint8_t want = mar_expect((uint8_t)(c | (m15 << MRI_M15)));
            if (got == want) continue;
            bad++;
            if (bad <= 8) {
                uart_putsP("     c=0x"); uart_puthex8(c);
                uart_putsP(" m15="); uart_putdec(m15);
                for (uint8_t i = 0; i < MRO_COUNT; i++)
                    if (((got ^ want) >> i) & 1) {
                        uart_putc(' '); uart_puts_p(PN(LOG_NAMES, i));
                        uart_puts_p(((want >> i) & 1) ? PSTR("(want 1)")
                                                      : PSTR("(want 0)"));
                    }
                uart_putsP("\r\n");
            }
        }
        bus_w_release();
        mar_set(MAR_IDLE);
        /* mux=1 rows: rig emulates the PC side on M */
        mar_set(MAR_IDLE | (1u << MRI_MUX));
        bus_m_drive((uint16_t)m15 << 15); settle();
        for (uint8_t c = 0; c < 16; c++) {
            if (!((c >> MRI_MUX) & 1)) continue;
            mar_set(c);
            uint8_t got = log_sample();
            uint8_t want = mar_expect((uint8_t)(c | (m15 << MRI_M15)));
            if (got == want) continue;
            bad++;
            if (bad <= 8) {
                uart_putsP("     c=0x"); uart_puthex8(c);
                uart_putsP(" m15="); uart_putdec(m15);
                uart_putsP(" (mux=1)");
                for (uint8_t i = 0; i < MRO_COUNT; i++)
                    if (((got ^ want) >> i) & 1) {
                        uart_putc(' '); uart_puts_p(PN(LOG_NAMES, i));
                        uart_puts_p(((want >> i) & 1) ? PSTR("(want 1)")
                                                      : PSTR("(want 0)"));
                    }
                uart_putsP("\r\n");
            }
        }
        bus_m_release(); settle();
        mar_set(MAR_IDLE);
    }
    if (bad > 8) uart_putsP("     ... further mismatches suppressed\r\n");
    test_check_u16(bad, 0, PSTR("logic_mismatch_states"));
    test_end();
}

void t_mar_hold(void) {
    test_begin(PSTR("mar"), PSTR("hold"));
    if (!bind()) { test_end(); return; }
    /* both halves from the same W byte, separate LEs: every check
       reads the FULL 16-bit M, so half-independence is baked into
       every assert */
    load16(0xC53A);
    test_check_u16(m_read(), 0xC53A, PSTR("load16"));
    for (uint8_t b = 0; b < 8; b++) {       /* LO walks, HI must hold */
        mar_load(MRI_LO_LOAD_N, (uint8_t)(1u << b));
        test_check_u16(m_read(), (uint16_t)0xC500 | (uint8_t)(1u << b),
                       PSTR("LO_walk1_HI_holds"));
    }
    mar_load(MRI_LO_LOAD_N, 0x3A);
    for (uint8_t b = 0; b < 8; b++) {       /* HI walks, LO must hold */
        mar_load(MRI_HI_LOAD_N, (uint8_t)~(1u << b));
        test_check_u16(m_read(),
                       (uint16_t)((uint16_t)(uint8_t)~(1u << b) << 8) | 0x3A,
                       PSTR("HI_walk0_LO_holds"));
    }
    /* gating: /LOAD strobed with CLK HIGH must NOT land */
    load16(0x1234);
    bus_w_write(0xFF);
    mar_set(MAR_IDLE & NO_BIT(MRI_LO_LOAD_N));      /* CLK stays high */
    mar_set(MAR_IDLE);
    bus_w_release(); settle();
    test_check_u16(m_read(), 0x1234, PSTR("load_gated_by_CLK_low"));
    test_end();
}

void t_mar_mux(void) {
    test_begin(PSTR("mar"), PSTR("mux"));
    if (!bind()) { test_end(); return; }
    load16(0xA5C3);
    test_check_u16(m_read(), 0xA5C3, PSTR("MAR_drives_M_mux_low"));
    test_check_bool(smp(&P_LOG[MRO_PC_MAR_MUX_N]), true,
                    PSTR("~{PC_MAR_MUX}"));
    /* mux=1: U54/U59 off — every M line must float; the PC-side
       enable must assert */
    mar_set(MAR_IDLE | (1u << MRI_MUX));
    for (uint8_t i = 0; i < 16; i++)
        test_check_bool(floats(&P_M[i]), true, PN(M_NAMES, i));
    test_check_bool(smp(&P_LOG[MRO_PC_MAR_MUX_N]), false,
                    PSTR("~{PC_MAR_MUX}"));
    /* back: the latched address survived the excursion */
    mar_set(MAR_IDLE);
    test_check_u16(m_read(), 0xA5C3, PSTR("MAR_redrives_after_mux"));
    test_end();
}

void t_mar_decode(void) {
    test_begin(PSTR("mar"), PSTR("decode"));
    if (!bind()) { test_end(); return; }
    /* the 0x8000 boundary, exactly, via BOTH drivers of M.
       ~RAM_EN is active low; ROM_EN is M15 itself (ROM /CE direct). */
    load16(0x7FFF);                          /* MAR side */
    test_check_bool(smp(&P_LOG[MRO_RAM_EN_N]), true, PSTR("ROM_side_0x7FFF"));
    load16(0x8000);
    test_check_bool(smp(&P_LOG[MRO_RAM_EN_N]), false, PSTR("RAM_side_0x8000"));
    load16(0x0000);
    test_check_bool(smp(&P_LOG[MRO_RAM_EN_N]), true, PSTR("ROM_side_0x0000"));
    /* PC side: decode must follow the BUS, not the latch */
    load16(0x8000);                          /* latch says RAM ...    */
    mar_set(MAR_IDLE | (1u << MRI_MUX));
    bus_m_drive(0x7FFF); settle();           /* ... bus says ROM      */
    test_check_bool(smp(&P_LOG[MRO_RAM_EN_N]), true, PSTR("PC_side_0x7FFF"));
    bus_m_drive(0x8000); settle();
    test_check_bool(smp(&P_LOG[MRO_RAM_EN_N]), false, PSTR("PC_side_0x8000"));
    bus_m_release(); settle();
    mar_set(MAR_IDLE);
    test_end();
}

void t_mar_stability(void) {
    test_begin(PSTR("mar"), PSTR("stability"));
    if (!bind()) { test_end(); return; }
    /* edge stress: gate flicker at two states, then load/read slam.
       Flicker = electrical (bench ledger). */
    uint16_t bad = 0;
    load16(0x0000);
    for (uint8_t i = 0; i < 32; i++) {
        mar_set(MAR_IDLE);
        if (log_sample() != mar_expect(MAR_IDLE)) bad++;
        mar_set(MAR_IDLE & NO_BIT(MRI_CLK) & NO_BIT(MRI_LO_LOAD_N));
        if (log_sample() != mar_expect(MAR_IDLE & NO_BIT(MRI_CLK)
                                       & NO_BIT(MRI_LO_LOAD_N))) bad++;
    }
    mar_set(MAR_IDLE);
    test_check_u16(bad, 0, PSTR("gate_flicker"));
    bad = 0;
    for (uint8_t i = 0; i < 16; i++) {
        load16(0xC53A);
        if (m_read() != 0xC53A) bad++;
        load16(0x3AC5);
        if (m_read() != 0x3AC5) bad++;
    }
    test_check_u16(bad, 0, PSTR("load_read_slam"));
    test_end();
}
