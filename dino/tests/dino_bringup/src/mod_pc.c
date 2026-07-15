#include <avr/io.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"

/* Program counter: 4x '193 (U1-U4) + load/count gating, rig-clocked
   (Y1 out, standalone board — fully deterministic, no statistics).

   Netlist-verified gating (2026-07-15, program_counter.kicad_sch):
     U10 '02:  CLR = OR(NOR(~PC_CLEAR, CLK), RESET)
               -> decoder clear lands ONLY while CLK low; RESET un-gated.
     U36 '00:  UP pin        = NAND(PC_UP, ~CLK)  -> counts on CLK rising
               ~PC_LOAD_STABLE = NAND(PC_LOAD, ~CLK) -> load lands ONLY
               while CLK low ('193 load is NOT async on this sheet).
     U11/U12 '245 (DIR=+5V, A->B): M -> PCD, CE = ~PC_LOAD
     U13/U14 '245 (DIR=GND, B->A): PC -> M,  CE = ~PC_MAR_MUX
   Protocol rules the vectors below obey:
     - PC_UP changes only while CLK is HIGH (deassert during CLK-low fires
       a spurious UP edge — same rule the real machine's CW timing gives).
     - Rig NEVER drives M while ~PC_MAR_MUX is low (U13/U14 would fight
       through the series resistors): mux high before bus_m_drive, always.
   Sampled lines: M0 M1 M2 M3 M4 M5 M6 M7 M8 M9 M10 M11 M12 M13 M14
   M15=ROM_EN (coverage: every contract signal named here). */

static hwpin_t P_CLRN, P_LOADN, P_MUXN, P_UP, P_RESET, P_CLK, P_CLKN;
static hwpin_t P_M[16];
static bool s_bound;

static const char *M_NAMES[16] = {
    "M0", "M1", "M2",  "M3",  "M4",  "M5",  "M6",  "M7",
    "M8", "M9", "M10", "M11", "M12", "M13", "M14", "M15=ROM_EN",
};

static bool bind1(const char *signal, hwpin_t *out) {
    if (sig_lookup("pc", signal, out)) return true;
    uart_puts("BIND FAIL "); uart_puts(signal); uart_puts("\r\n");
    test_check_bool(false, true, signal);
    return false;
}

static bool bind(void) {
    if (s_bound) return true;
    bool ok = true;
    ok &= bind1("~{PC_CLEAR}",   &P_CLRN);  /* rig drives */
    ok &= bind1("~{PC_LOAD}",    &P_LOADN); /* rig drives */
    ok &= bind1("~{PC_MAR_MUX}", &P_MUXN);  /* rig drives */
    ok &= bind1("CW13=PC_UP",    &P_UP);    /* rig drives */
    ok &= bind1("CLK",           &P_CLK);   /* rig drives */
    ok &= bind1("~{CLK}",        &P_CLKN);  /* rig drives */
    ok &= bind1("RESET",         &P_RESET); /* rig drives */
    for (uint8_t i = 0; i < 16; i++)
        ok &= bind1(M_NAMES[i], &P_M[i]);   /* rig samples */
    if (!ok) return false;                  /* never drive a garbage pin */
    /* bus_m_read/bus_m_drive assume M lands on PORTC(lo)+PORTL(hi) —
       guard against pinmap regeneration moving it */
    if (P_M[0].pinr != &PINC || P_M[0].bit != 0 ||
        P_M[8].pinr != &PINL || P_M[8].bit != 0 ||
        P_M[15].pinr != &PINL || P_M[15].bit != 7) {
        test_check_bool(false, true, "M_bus_on_PORTC_PORTL");
        return false;
    }
    bus_m_release();
    drv(&P_CLRN, true);          /* clear idle       */
    drv(&P_LOADN, true);         /* load idle        */
    drv(&P_UP, false);           /* count disabled   */
    drv(&P_RESET, false);
    drv(&P_MUXN, false);         /* PC on M — rig samples */
    clk_bind(&P_CLK, &P_CLKN);   /* leaves CLK low   */
    clk_hi();                    /* idle HIGH: PC_UP/clear-safe phase */
    settle();
    s_bound = true;
    return true;
}

static uint16_t pc_read(void) { settle(); return bus_m_read(); }

static void reset_pulse(void) {
    drv(&P_RESET, true); settle();       /* CLR leg un-gated: any phase */
    drv(&P_RESET, false); settle();
}

/* CLK-gated load: mux PC off M, rig drives vector, strobe ~PC_LOAD while
   CLK is LOW (the only phase ~PC_LOAD_STABLE can assert), restore. */
static void load16(uint16_t v) {
    drv(&P_MUXN, true); settle();        /* PC off bus BEFORE rig drives */
    bus_m_drive(v); settle();
    clk_lo();
    drv(&P_LOADN, false); settle();
    drv(&P_LOADN, true); settle();
    clk_hi();
    bus_m_release(); settle();
    drv(&P_MUXN, false); settle();
}

/* n CLK rising edges with PC_UP asserted; PC_UP toggled only at CLK-high */
static void count_n(uint8_t n) {
    drv(&P_UP, true); settle();
    while (n--) step();                  /* lo -> hi: count on the rise */
    drv(&P_UP, false); settle();
}

void t_pc_presence(void) {
    test_begin("pc", "presence");
    if (!bind()) { test_end(); return; }
    reset_pulse();
    test_check_u16(pc_read(), 0, "PC_zero_after_reset");
    count_n(1);
    test_check_u16(pc_read(), 1, "PC_counts");
    test_end();
}

void t_pc_count(void) {
    test_begin("pc", "count");
    if (!bind()) { test_end(); return; }
    reset_pulse();
    uart_puts("     seq:");
    drv(&P_UP, true); settle();
    bool ok = true;
    for (uint16_t i = 1; i <= 16; i++) {
        step();
        uint16_t v = pc_read();
        uart_putc(' '); uart_puthex16(v);
        if (v != i) ok = false;
    }
    drv(&P_UP, false); settle();
    uart_puts("\r\n");
    test_check_bool(ok, true, "PC_increments_each_step");
    /* hold: PC_UP low, clock keeps running, no creep */
    for (uint8_t i = 0; i < 8; i++) step();
    test_check_u16(pc_read(), 16, "PC_holds_UP_low");
    test_end();
}

void t_pc_carry(void) {
    test_begin("pc", "carry");
    if (!bind()) { test_end(); return; }
    static const uint16_t from[] = {0x00FF, 0x0FFF, 0x7FFF, 0xFFFF};
    static const uint16_t to[]   = {0x0100, 0x1000, 0x8000, 0x0000};
    for (uint8_t i = 0; i < 4; i++) {
        load16(from[i]);
        count_n(1);
        test_check_u16(pc_read(), to[i], "carry_chain");
    }
    /* M15 doubles as ROM_EN: flips exactly at the 0x8000 boundary */
    load16(0x7FFF);
    test_check_bool((pc_read() & 0x8000) != 0, false, "ROM_EN_low_below");
    count_n(1);
    test_check_bool((pc_read() & 0x8000) != 0, true, "ROM_EN_high_at_0x8000");
    test_end();
}

void t_pc_load(void) {
    test_begin("pc", "load");
    if (!bind()) { test_end(); return; }
    static const uint16_t pat[] = {0x0000, 0xFFFF, 0xAAAA, 0x5555};
    for (uint8_t i = 0; i < 4; i++) {
        load16(pat[i]);
        test_check_u16(pc_read(), pat[i], "load_pattern");
    }
    for (uint8_t i = 0; i < 16; i++) {
        load16((uint16_t)1 << i);
        test_check_u16(pc_read(), (uint16_t)1 << i, "load_walk1");
        load16((uint16_t)~((uint16_t)1 << i));
        test_check_u16(pc_read(), (uint16_t)~((uint16_t)1 << i), "load_walk0");
    }
    /* gating: ~PC_LOAD strobed with CLK HIGH must not land (U36 gate3) */
    load16(0x1234);
    drv(&P_MUXN, true); settle();
    bus_m_drive(0x4321); settle();       /* CLK stays high */
    drv(&P_LOADN, false); settle();
    drv(&P_LOADN, true); settle();
    bus_m_release(); settle();
    drv(&P_MUXN, false); settle();
    test_check_u16(pc_read(), 0x1234, "load_gated_by_CLK_low");
    test_end();
}

void t_pc_clear(void) {
    test_begin("pc", "clear");
    if (!bind()) { test_end(); return; }
    /* row 1: ~PC_CLEAR low while CLK high -> blocked (NOR gate) */
    load16(0x0BAD);
    drv(&P_CLRN, false); settle();       /* CLK idle high */
    test_check_u16(pc_read(), 0x0BAD, "clear_blocked_CLK_high");
    /* row 2: same, CLK low -> clears */
    clk_lo();
    test_check_u16(pc_read(), 0x0000, "clear_lands_CLK_low");
    drv(&P_CLRN, true); settle();
    clk_hi();
    /* rows 3+4: RESET leg is NOT CLK-gated — either phase clears */
    load16(0x00AA);
    reset_pulse();                        /* CLK high */
    test_check_u16(pc_read(), 0x0000, "RESET_clears_CLK_high");
    load16(0x0055);
    clk_lo();
    reset_pulse();
    test_check_u16(pc_read(), 0x0000, "RESET_clears_CLK_low");
    clk_hi();
    test_end();
}

void t_pc_mux(void) {
    test_begin("pc", "mux");
    if (!bind()) { test_end(); return; }
    load16(0x5A5A);
    test_check_u16(pc_read(), 0x5A5A, "PC_drives_M_mux_low");
    /* mux high: U13/U14 disabled, U11/U12 idle (~PC_LOAD high) —
       every M line must float */
    drv(&P_MUXN, true); settle();
    for (uint8_t i = 0; i < 16; i++)
        test_check_bool(floats(&P_M[i]), true, M_NAMES[i]);
    drv(&P_MUXN, false); settle();
    test_check_u16(pc_read(), 0x5A5A, "PC_redrives_M_mux_low");
    test_end();
}

void t_pc_phase(void) {
    test_begin("pc", "phase");
    if (!bind()) { test_end(); return; }
    load16(0x0100);
    /* PC_UP toggled during CLK-high: UP pin pinned high, no edge */
    for (uint8_t i = 0; i < 4; i++) {
        drv(&P_UP, true); settle();
        drv(&P_UP, false); settle();
    }
    test_check_u16(pc_read(), 0x0100, "no_count_UP_toggle_CLK_high");
    /* count fires on the rising CLK edge, not the falling one */
    drv(&P_UP, true); settle();
    clk_lo();
    test_check_u16(pc_read(), 0x0100, "no_count_on_CLK_fall");
    clk_hi();
    test_check_u16(pc_read(), 0x0101, "count_on_CLK_rise");
    drv(&P_UP, false); settle();
    test_end();
}

void t_pc_precedence(void) {
    test_begin("pc", "precedence");
    if (!bind()) { test_end(); return; }
    /* clear + load both asserted (CLK low): '193 CLR dominates ~LOAD.
       M is rig-driven throughout, so checks read back after restore. */
    load16(0x0777);
    drv(&P_MUXN, true); settle();
    bus_m_drive(0xAAAA); settle();
    clk_lo();
    drv(&P_LOADN, false); drv(&P_CLRN, false); settle();
    drv(&P_LOADN, true); settle();        /* load off first, clear holds */
    drv(&P_CLRN, true); settle();
    clk_hi();
    bus_m_release(); settle();
    drv(&P_MUXN, false); settle();
    test_check_u16(pc_read(), 0x0000, "clear_beats_load");
    /* release order flipped: clear off first, load still asserted lands */
    drv(&P_MUXN, true); settle();
    bus_m_drive(0xAAAA); settle();
    clk_lo();
    drv(&P_LOADN, false); drv(&P_CLRN, false); settle();
    drv(&P_CLRN, true); settle();         /* clear off, load wins now */
    drv(&P_LOADN, true); settle();
    clk_hi();
    bus_m_release(); settle();
    drv(&P_MUXN, false); settle();
    test_check_u16(pc_read(), 0xAAAA, "load_after_clear_release");
    /* RESET mid-count, then count resumes from zero */
    count_n(3);
    reset_pulse();
    test_check_u16(pc_read(), 0x0000, "RESET_beats_count");
    count_n(2);
    test_check_u16(pc_read(), 0x0002, "count_from_reset");
    /* count continues from a loaded value (JMP-then-fetch seam) */
    load16(0x1234);
    count_n(2);
    test_check_u16(pc_read(), 0x1236, "count_from_loaded");
    test_end();
}
