#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "mdr_expect.h"

/* MDR board: MDR register + IR + the W<->MDR bridge. No free-running
   clock — CLK is rig-driven and only gates LE_IR.

   Netlist-verified structure (mdr.kicad_sch, 2026-07-20):
     U18 '373  MDR register, D and Q paired on the SAME MDR0-7 nets
               (bus-hold latch): captures the MDR bus while LE_MDR is
               high, re-drives it onto MDR when ~{MDR_OUT} is low.
     U34 '373  IR: D = W0-7, Q = IRB0-7, OE grounded (IRB always
               driven), LE = LE_IR.
     U25 '245  the ONE W<->MDR bridge: A = W, B = MDR, DIR = BUS_DIR
               (high = W->MDR), CE = ~{MDR_EN}.
     U37 '04   WRITE_DIR = INV(~{RAM_LOAD}); MDR_OUT = INV(~{MDR_OUT});
               READS_IDLE = INV(NAND(~{ROM_OUT}, ~{RAM_OUT})).
     U39 '00   BUS_DIR = NAND(~{ALU_OUT}, ~{SW_OUT}) — bug-4 fix: bus
               direction is a property of the SOURCE.
               LE_MDR = NAND(~{RAM_LOAD}, READS_IDLE) — MDR transparent
               during a RAM write or any memory read, latched at idle.
     U22 '02   LE_IR = NOR(CLK, ~{IR_LOAD}) — the register stamp gate.
               ~{MDR_EN} = NOR(SRC_ACTIVE, MDR_OUT) — bug-4 fix: bridge
               on whenever any source drives, or on MDR replay.

   Expected gate values come from mdr_expect.h (host-tested model — see
   hosttest/test_mdr_expect.c). ROGUE-STATE RULE (mdr_fight): ~{MDR_OUT}
   down while a W-side source is active makes U25 and U18 fight on MDR;
   real microcode never encodes it and every test here skips/avoids it.

   Bus discipline (mirror when hand-probing): release the bus the DUT is
   about to drive BEFORE asserting the enable that drives it; never
   rig-drive MDR while U18 or U25 drives it, never rig-drive W while the
   bridge points MDR->W.

   Rig-internal probes (in the bundle): LE_IR (U22.1), ~{MDR_EN}
   (U22.4), LE_MDR (U39.6), BUS_DIR (U39.8) — the four steering nets;
   a FAIL names the lying gate, same trick that carried control_word.

   Driven lines: ~{MDR_OUT} ~{IR_LOAD} ~{RAM_LOAD} ~{ROM_OUT} ~{RAM_OUT}
   ~{ALU_OUT} ~{SW_OUT} SRC_ACTIVE CLK (series R).
   Sampled lines: WRITE_DIR IRB0 IRB1 IRB2 IRB3 IRB4 IRB5 IRB6 IRB7
   + probes LE_IR ~{MDR_EN} LE_MDR BUS_DIR.
   Bidir buses: W0 W1 W2 W3 W4 W5 W6 W7 (PORTA), MDR0 MDR1 MDR2 MDR3
   MDR4 MDR5 MDR6 MDR7 (PORTF).
   (coverage: every contract signal named). */

static hwpin_t P_IN[MDI_COUNT], P_LOG[MDO_COUNT];
static hwpin_t P_W[8], P_MDR[8], P_IRB[8];
static bool s_bound;
static uint8_t s_gen;

/* enum order of mdr_expect.h */
static const char in_names_s0[] PROGMEM = "~{MDR_OUT}";
static const char in_names_s1[] PROGMEM = "~{IR_LOAD}";
static const char in_names_s2[] PROGMEM = "~{RAM_LOAD}";
static const char in_names_s3[] PROGMEM = "~{ROM_OUT}";
static const char in_names_s4[] PROGMEM = "~{RAM_OUT}";
static const char in_names_s5[] PROGMEM = "~{ALU_OUT}";
static const char in_names_s6[] PROGMEM = "~{SW_OUT}";
static const char in_names_s7[] PROGMEM = "SRC_ACTIVE";
static const char in_names_s8[] PROGMEM = "CLK";
static const char * const IN_NAMES[MDI_COUNT] PROGMEM = { in_names_s0, in_names_s1, in_names_s2, in_names_s3, in_names_s4, in_names_s5, in_names_s6, in_names_s7, in_names_s8 };
static const char log_names_s0[] PROGMEM = "WRITE_DIR";
static const char log_names_s1[] PROGMEM = "BUS_DIR";
static const char log_names_s2[] PROGMEM = "~{MDR_EN}";
static const char log_names_s3[] PROGMEM = "LE_MDR";
static const char log_names_s4[] PROGMEM = "LE_IR";
static const char * const LOG_NAMES[MDO_COUNT] PROGMEM = { log_names_s0, log_names_s1, log_names_s2, log_names_s3, log_names_s4 };
static const char w_names_s0[] PROGMEM = "W0";
static const char w_names_s1[] PROGMEM = "W1";
static const char w_names_s2[] PROGMEM = "W2";
static const char w_names_s3[] PROGMEM = "W3";
static const char w_names_s4[] PROGMEM = "W4";
static const char w_names_s5[] PROGMEM = "W5";
static const char w_names_s6[] PROGMEM = "W6";
static const char w_names_s7[] PROGMEM = "W7";
static const char * const W_NAMES[8] PROGMEM = { w_names_s0, w_names_s1, w_names_s2, w_names_s3, w_names_s4, w_names_s5, w_names_s6, w_names_s7 };
static const char mdr_names_s0[] PROGMEM = "MDR0";
static const char mdr_names_s1[] PROGMEM = "MDR1";
static const char mdr_names_s2[] PROGMEM = "MDR2";
static const char mdr_names_s3[] PROGMEM = "MDR3";
static const char mdr_names_s4[] PROGMEM = "MDR4";
static const char mdr_names_s5[] PROGMEM = "MDR5";
static const char mdr_names_s6[] PROGMEM = "MDR6";
static const char mdr_names_s7[] PROGMEM = "MDR7";
static const char * const MDR_NAMES[8] PROGMEM = { mdr_names_s0, mdr_names_s1, mdr_names_s2, mdr_names_s3, mdr_names_s4, mdr_names_s5, mdr_names_s6, mdr_names_s7 };
static const char irb_names_s0[] PROGMEM = "IRB0";
static const char irb_names_s1[] PROGMEM = "IRB1";
static const char irb_names_s2[] PROGMEM = "IRB2";
static const char irb_names_s3[] PROGMEM = "IRB3";
static const char irb_names_s4[] PROGMEM = "IRB4";
static const char irb_names_s5[] PROGMEM = "IRB5";
static const char irb_names_s6[] PROGMEM = "IRB6";
static const char irb_names_s7[] PROGMEM = "IRB7";
static const char * const IRB_NAMES[8] PROGMEM = { irb_names_s0, irb_names_s1, irb_names_s2, irb_names_s3, irb_names_s4, irb_names_s5, irb_names_s6, irb_names_s7 };

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];                       /* sig_lookup wants RAM */
    strcpy_P(sig, sig_P);
    if (sig_lookup("mdr", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = true;
    for (uint8_t i = 0; i < MDI_COUNT; i++) ok &= bind1(PN(IN_NAMES, i), &P_IN[i]);
    for (uint8_t i = 0; i < MDO_COUNT; i++) ok &= bind1(PN(LOG_NAMES, i), &P_LOG[i]);
    for (uint8_t i = 0; i < 8; i++) {
        ok &= bind1(PN(W_NAMES, i), &P_W[i]);
        ok &= bind1(PN(MDR_NAMES, i), &P_MDR[i]);
        ok &= bind1(PN(IRB_NAMES, i), &P_IRB[i]);
    }
    if (!ok) return false;                  /* never drive a garbage pin */
    /* byte helpers assume the fixed bus ports — guard pinmap moves */
    if (P_W[0].pinr != &PINA || P_W[0].bit != 0 ||
        P_W[7].pinr != &PINA || P_W[7].bit != 7) {
        test_check_bool(false, true, PSTR("W_bus_on_PORTA_ascending"));
        return false;
    }
    if (P_MDR[0].pinr != &PINF || P_MDR[7].bit != 7 ||
        P_IRB[0].pinr != &PINK || P_IRB[7].bit != 7) {
        test_check_bool(false, true, PSTR("MDR_on_PORTF_IRB_on_PORTK"));
        return false;
    }
    bus_w_release();
    bus_mdr_release();
    DDRK = 0x00; PORTK = 0x00;              /* IRB sampled */
    for (uint8_t i = 0; i < MDO_COUNT; i++) rel(&P_LOG[i]);
    for (uint8_t i = 0; i < MDI_COUNT; i++)
        drv(&P_IN[i], (MDR_IDLE >> i) & 1);
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static void mdr_set(uint16_t in) {
    for (uint8_t i = 0; i < MDI_COUNT; i++)
        drv(&P_IN[i], (in >> i) & 1);
    settle();
}

static uint8_t log_sample(void) {
    uint8_t v = 0;
    for (uint8_t i = 0; i < MDO_COUNT; i++)
        if (smp(&P_LOG[i])) v |= (uint8_t)(1u << i);
    return v;
}

static uint8_t irb_read(void) { settle(); return PINK; }

/* IR load: W = v, strobe ~IR_LOAD while CLK is low (the only phase
   LE_IR can open), close latch, release W. */
static void ir_load(uint8_t v) {
    bus_w_write(v);
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_CLK));           /* CLK low */
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_CLK)
                     & (uint16_t)~(1u << MDI_IR_LOAD_N));     /* LE opens */
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_CLK));           /* latch    */
    mdr_set(MDR_IDLE);
    bus_w_release(); settle();
}

/* MDR latch capture: v onto the MDR bus, open LE via `strobe_bit`
   (~RAM_LOAD or a memory read strobe), close, release the bus. */
static void mdr_latch(uint8_t v, uint8_t strobe_bit) {
    bus_mdr_write(v);
    mdr_set(MDR_IDLE & (uint16_t)~(1u << strobe_bit));        /* LE opens */
    mdr_set(MDR_IDLE);                                        /* latch    */
    bus_mdr_release(); settle();
}

/* U18 replay: ~MDR_OUT down drives the latched byte onto MDR (and
   across the bridge to W — MDR_OUT forces the bridge on, MDR->W). */
static uint8_t mdr_replay_read(void) {
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_MDR_OUT_N));
    uint8_t v = bus_mdr_read();
    mdr_set(MDR_IDLE);
    return v;
}

void t_mdr_warmup(void) {
    test_begin(PSTR("mdr"), PSTR("warmup"));
    if (!bind()) { test_end(); return; }
    /* power-on readiness probe (bench lesson from pc/microcode/
       control_word): idle gate state + an IR load + an MDR capture until
       stable 4x, print the settle time. */
    uint16_t waited_ms = 0;
    uint8_t streak = 0;
    while (streak < 4 && waited_ms < 10000) {
        mdr_set(MDR_IDLE);
        bool ok = (log_sample() == mdr_expect(MDR_IDLE));
        ir_load(0xA5); ok &= (irb_read() == 0xA5);
        mdr_latch(0x5A, MDI_RAM_LOAD_N);
        ok &= (mdr_replay_read() == 0x5A);
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

void t_mdr_presence(void) {
    test_begin(PSTR("mdr"), PSTR("presence"));
    if (!bind()) { test_end(); return; }
    /* always-driven lines: the 5 gate outputs (totem-pole) and IRB0-7
       (U34 OE grounded). A float = missing chip or dead jumper — the
       FAIL names the wire. W/MDR are checked by `tristate` instead. */
    mdr_set(MDR_IDLE);
    for (uint8_t i = 0; i < MDO_COUNT; i++)
        test_check_bool(!floats(&P_LOG[i]), true, PN(LOG_NAMES, i));
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(!floats(&P_IRB[i]), true, PN(IRB_NAMES, i));
    test_end();
}

void t_mdr_logic(void) {
    test_begin(PSTR("mdr"), PSTR("logic"));
    if (!bind()) { test_end(); return; }
    /* dir.logic, exhaustive: all 512 input states, all 5 gate signals
       compared to the host-tested model each time. Rogue fight states
       (U25 vs U18 on MDR — see header) are skipped and counted. */
    uint16_t bad = 0, skipped = 0;
    for (uint16_t in = 0; in < (1u << MDI_COUNT); in++) {
        if (mdr_fight(in)) { skipped++; continue; }
        mdr_set(in);
        uint8_t got = log_sample(), want = mdr_expect(in);
        if (got == want) continue;
        bad++;
        if (bad <= 4) {
            uart_putsP("     in=0x"); uart_puthex16(in);
            for (uint8_t i = 0; i < MDO_COUNT; i++)
                if (((got ^ want) >> i) & 1) {
                    uart_putc(' '); uart_puts_p(PN(LOG_NAMES, i));
                    uart_puts(((want >> i) & 1) ? "(want 1)" : "(want 0)");
                }
            uart_putsP("\r\n");
        }
    }
    if (bad > 4) uart_putsP("     ... further mismatches suppressed\r\n");
    uart_putsP("     skipped ");
    uart_putdec(skipped);
    uart_putsP(" U25-vs-U18 fight states (by design)\r\n");
    mdr_set(MDR_IDLE);
    test_check_u16(bad, 0, PSTR("logic_mismatch_states"));
    test_end();
}

void t_mdr_capture(void) {
    test_begin(PSTR("mdr"), PSTR("capture"));
    if (!bind()) { test_end(); return; }
    /* MDR '373 through all three LE paths (RAM write, ROM read, RAM
       read), then hold-against-overwrite, then U18 replay readback. */
    static const uint8_t strobe[3] =
        {MDI_RAM_LOAD_N, MDI_ROM_OUT_N, MDI_RAM_OUT_N};
    static const char lbl_s0[] PROGMEM = "via_~{RAM_LOAD}";
    static const char lbl_s1[] PROGMEM = "via_~{ROM_OUT}";
    static const char lbl_s2[] PROGMEM = "via_~{RAM_OUT}";
    static const char * const lbl[3] PROGMEM = {lbl_s0, lbl_s1, lbl_s2};
    static const uint8_t pat[4] = {0x00, 0xFF, 0xAA, 0x55};
    for (uint8_t s = 0; s < 3; s++)
        for (uint8_t i = 0; i < 4; i++) {
            mdr_latch(pat[i], strobe[s]);
            bus_mdr_write((uint8_t)~pat[i]);    /* LE closed: must NOT land */
            bus_mdr_release(); settle();
            test_check_u16(mdr_replay_read(), pat[i], PN(lbl, s));
        }
    /* per-bit walk through the primary (RAM write) path */
    for (uint8_t b = 0; b < 8; b++) {
        mdr_latch((uint8_t)(1u << b), MDI_RAM_LOAD_N);
        test_check_u16(mdr_replay_read(), (uint8_t)(1u << b), PSTR("walk1"));
        mdr_latch((uint8_t)~(1u << b), MDI_RAM_LOAD_N);
        test_check_u16(mdr_replay_read(), (uint8_t)~(1u << b), PSTR("walk0"));
    }
    test_end();
}

void t_mdr_ir(void) {
    test_begin(PSTR("mdr"), PSTR("ir"));
    if (!bind()) { test_end(); return; }
    /* ir.snoop: IR captures W under LE_IR = NOR(CLK, ~IR_LOAD). */
    static const uint8_t pat[4] = {0x00, 0xFF, 0xAA, 0x55};
    for (uint8_t i = 0; i < 4; i++) {
        ir_load(pat[i]);
        test_check_u16(irb_read(), pat[i], PSTR("load_pattern"));
    }
    for (uint8_t b = 0; b < 8; b++) {
        ir_load((uint8_t)(1u << b));
        test_check_u16(irb_read(), (uint8_t)(1u << b), PSTR("load_walk1"));
        ir_load((uint8_t)~(1u << b));
        test_check_u16(irb_read(), (uint8_t)~(1u << b), PSTR("load_walk0"));
    }
    /* hold: W changes with the latch closed — IRB must not move */
    ir_load(0x3C);
    bus_w_write(0xC3); settle();
    bus_w_release(); settle();
    test_check_u16(irb_read(), 0x3C, PSTR("holds_after_W_changes"));
    /* gating: ~IR_LOAD strobed with CLK HIGH must not land (U22 gate 1) */
    bus_w_write(0xC3);
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_IR_LOAD_N));   /* CLK high */
    mdr_set(MDR_IDLE);
    bus_w_release(); settle();
    test_check_u16(irb_read(), 0x3C, PSTR("load_gated_by_CLK_low"));
    /* transparency: latch open, IRB follows W live */
    bus_w_write(0x81);
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_CLK)
                     & (uint16_t)~(1u << MDI_IR_LOAD_N));
    test_check_u16(irb_read(), 0x81, PSTR("transparent_follows_W"));
    bus_w_write(0x42); settle();
    test_check_u16(irb_read(), 0x42, PSTR("transparent_tracks_change"));
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_CLK));
    mdr_set(MDR_IDLE);
    bus_w_release(); settle();
    test_end();
}

void t_mdr_tristate(void) {
    test_begin(PSTR("mdr"), PSTR("tristate"));
    if (!bind()) { test_end(); return; }
    /* nothing enabled, SRC_ACTIVE low: bridge off, U18 quiet — every W
       and MDR line must float (bug-4's quiescent contract). */
    mdr_set(MDR_IDLE);
    for (uint8_t i = 0; i < 8; i++) {
        test_check_bool(floats(&P_W[i]), true, PN(W_NAMES, i));
        test_check_bool(floats(&P_MDR[i]), true, PN(MDR_NAMES, i));
    }
    test_end();
}

void t_mdr_bridge(void) {
    test_begin(PSTR("mdr"), PSTR("bridge"));
    if (!bind()) { test_end(); return; }
    /* bridge.route — retires schematic bug 4. One row per source class,
       walking-1 so a stuck '245 bit names itself. */
    /* (a) W-side source: SRC_ACTIVE + ~ALU_OUT -> W crosses to MDR */
    uint16_t in_a = (MDR_IDLE | (1u << MDI_SRC_ACTIVE))
                    & (uint16_t)~(1u << MDI_ALU_OUT_N);
    bus_mdr_release();
    mdr_set(in_a);
    for (uint8_t b = 0; b < 8; b++) {
        bus_w_write((uint8_t)(1u << b)); settle();
        test_check_u16(bus_mdr_read(), (uint8_t)(1u << b), PSTR("W_to_MDR_alu"));
    }
    bus_w_release();
    /* same route via the other W-side source, ~SW_OUT */
    mdr_set((MDR_IDLE | (1u << MDI_SRC_ACTIVE))
            & (uint16_t)~(1u << MDI_SW_OUT_N));
    bus_w_write(0xA5); settle();
    test_check_u16(bus_mdr_read(), 0xA5, PSTR("W_to_MDR_sw"));
    bus_w_release();
    mdr_set(MDR_IDLE);
    /* (b) MDR-side source: SRC_ACTIVE, no W strobe -> MDR crosses to W */
    bus_w_release();
    mdr_set(MDR_IDLE | (1u << MDI_SRC_ACTIVE));
    for (uint8_t b = 0; b < 8; b++) {
        bus_mdr_write((uint8_t)(1u << b)); settle();
        test_check_u16(bus_w_read(), (uint8_t)(1u << b), PSTR("MDR_to_W"));
    }
    bus_mdr_release();
    mdr_set(MDR_IDLE);
    /* (c) replay: latched byte crosses to W with SRC_ACTIVE low */
    mdr_latch(0x69, MDI_RAM_LOAD_N);
    mdr_set(MDR_IDLE & (uint16_t)~(1u << MDI_MDR_OUT_N));
    test_check_u16(bus_w_read(), 0x69, PSTR("replay_to_W"));
    mdr_set(MDR_IDLE);
    /* (d) bridge off: SRC_ACTIVE low, no replay — rig drives MDR and W
       must stay floating on every bit */
    bus_mdr_write(0xFF); settle();
    bool w_floats = true;
    for (uint8_t i = 0; i < 8; i++) w_floats &= floats(&P_W[i]);
    bus_mdr_release(); settle();
    test_check_bool(w_floats, true, PSTR("bridge_off_W_floats"));
    test_end();
}

void t_mdr_stability(void) {
    test_begin(PSTR("mdr"), PSTR("stability"));
    if (!bind()) { test_end(); return; }
    /* edge stress: repeated gate reads, then capture/replay slam. Any
       flicker is electrical (seating, supply/ground — bench ledger). */
    uint16_t bad = 0;
    uint16_t in_active = (MDR_IDLE | (1u << MDI_SRC_ACTIVE))
                         & (uint16_t)~(1u << MDI_ALU_OUT_N);
    for (uint8_t i = 0; i < 32; i++) {
        mdr_set(MDR_IDLE);
        if (log_sample() != mdr_expect(MDR_IDLE)) bad++;
        mdr_set(in_active);
        if (log_sample() != mdr_expect(in_active)) bad++;
    }
    mdr_set(MDR_IDLE);
    test_check_u16(bad, 0, PSTR("gate_flicker"));
    bad = 0;
    for (uint8_t i = 0; i < 16; i++) {
        mdr_latch(0xAA, MDI_RAM_LOAD_N);
        if (mdr_replay_read() != 0xAA) bad++;
        mdr_latch(0x55, MDI_RAM_LOAD_N);
        if (mdr_replay_read() != 0x55) bad++;
    }
    test_check_u16(bad, 0, PSTR("capture_replay_slam"));
    test_end();
}
