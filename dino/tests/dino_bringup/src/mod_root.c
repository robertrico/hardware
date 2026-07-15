#include "registry.h"
#include "harness.h"
#include "uart.h"

/* Pin bindings: contract signals resolved through the generated pinmap
   (sig_lookup walks pinmap_gen.h), so hookup can never drift from
   `pins root`. Only the two rig-side extras are fixed. */
static hwpin_t P_CLKIN, P_END, P_HALT, P_RSTF, P_CLK, P_CLKN, P_RESET;
static hwpin_t P_RESETN;
static hwpin_t P_T[4];
static bool s_bound;

static bool bind1(const char *signal, hwpin_t *out) {
    if (sig_lookup("root", signal, out)) return true;
    uart_puts("BIND FAIL "); uart_puts(signal); uart_puts("\r\n");
    test_check_bool(false, true, signal);
    return false;
}

static bool bind(void) {
    if (s_bound) return true;
    bool ok = true;
    ok &= bind1("END",    &P_END);     /* END        (rig drives)  */
    ok &= bind1("HALT",   &P_HALT);    /* HALT       (rig drives)  */
    ok &= bind1("CLK",    &P_CLK);     /* CLK        (rig samples) */
    ok &= bind1("~{CLK}", &P_CLKN);    /* ~{CLK}     (rig samples) */
    ok &= bind1("RESET",  &P_RESET);   /* RESET      (rig samples) */
    ok &= bind1("~{RESET}", &P_RESETN); /* ~{RESET}  (rig samples) */
    ok &= bind1("T0", &P_T[0]);        /* T0         (rig samples) */
    ok &= bind1("T1", &P_T[1]);        /* T1 */
    ok &= bind1("T2", &P_T[2]);        /* T2 */
    ok &= bind1("T3", &P_T[3]);        /* T3 */
    /* rig-side extras — NOT contract signals; fixed free pool pins */
    pin_lookup("PD3/D18", &P_CLKIN);   /* rig-side: Y1-socket injection */
    pin_lookup("PD2/D19", &P_RSTF);    /* rig-side: RC-node force-low  */
    if (!ok) return false;             /* never drive a garbage pin */
    drv(&P_END, false);
    drv(&P_HALT, false);
    rel(&P_RSTF);                      /* released = RC charges = no reset */
    s_bound = true;
    return true;
}

static void pulse_clkin(uint16_t n) {
    while (n--) { drv(&P_CLKIN, true); settle(); drv(&P_CLKIN, false); settle(); }
}

static uint8_t t_now(void) {
    return (uint8_t)(smp(&P_T[0]) | smp(&P_T[1]) << 1 |
                     smp(&P_T[2]) << 2 | smp(&P_T[3]) << 3);
}

/* one full system-CLK cycle = 4 CLKIN pulses (Y1/4 divider) */
static void sysclk_step(void) { pulse_clkin(4); }

static void do_reset(void) {
    drv(&P_RSTF, false); settle();
    sysclk_step();                       /* let synchronizer assert */
    rel(&P_RSTF); settle();
    sysclk_step(); sysclk_step();        /* sync release */
}

void t_root_divider(void) {
    test_begin("root", "divider");
    if (!bind()) { test_end(); return; }
    /* count CLK edges over 64 injected pulses: expect 16 full CLK cycles */
    uint8_t rises = 0;
    bool last = smp(&P_CLK);
    for (uint16_t i = 0; i < 64; i++) {
        pulse_clkin(1);
        bool now = smp(&P_CLK);
        if (now && !last) rises++;
        last = now;
    }
    test_check_u16(rises, 16, "CLK_rises_per_64_in");
    /* complementarity */
    test_check_bool(smp(&P_CLKN), !smp(&P_CLK), "CLKN_complement");
    test_end();
}

void t_root_tstate_walk(void) {
    test_begin("root", "tstate_walk");
    if (!bind()) { test_end(); return; }
    do_reset();
    uint8_t t0 = t_now();
    test_check_u16(t0, 0, "T_after_reset");
    for (uint8_t i = 1; i <= 17; i++) {
        sysclk_step();
        test_check_u16(t_now(), i & 0x0F, "T_walk");
    }
    test_end();
}

void t_root_reset_sync(void) {
    test_begin("root", "reset_sync");
    if (!bind()) { test_end(); return; }
    drv(&P_RSTF, false); settle();
    sysclk_step();
    test_check_bool(smp(&P_RESET), true, "RESET_asserted");
    test_check_bool(smp(&P_RESETN), false, "RESETN_complement_asserted");
    rel(&P_RSTF); settle();
    /* release is synchronous: still high before an edge... */
    test_check_bool(smp(&P_RESET), true, "RESET_held_before_edge");
    sysclk_step(); sysclk_step();
    test_check_bool(smp(&P_RESET), false, "RESET_released_after_edge");
    test_check_bool(smp(&P_RESETN), true, "RESETN_complement_released");
    test_end();
}

void t_root_reset_tclear(void) {
    test_begin("root", "reset_tclear");
    if (!bind()) { test_end(); return; }
    do_reset();
    sysclk_step(); sysclk_step(); sysclk_step();   /* T=3 */
    do_reset();
    test_check_u16(t_now(), 0, "T_cleared_by_reset");
    test_end();
}

void t_root_end_clear(void) {
    test_begin("root", "end_clear");
    if (!bind()) { test_end(); return; }
    do_reset();
    sysclk_step(); sysclk_step();                  /* T=2 */
    drv(&P_END, true); settle();
    sysclk_step();                                 /* END high at edge */
    drv(&P_END, false); settle();
    test_check_u16(t_now(), 0, "T_cleared_by_END");
    sysclk_step();
    test_check_u16(t_now(), 1, "counting_resumes");
    test_end();
}

void t_root_halt_freeze(void) {
    test_begin("root", "halt_freeze");
    if (!bind()) { test_end(); return; }
    do_reset();
    sysclk_step();                                 /* T=1 */
    drv(&P_HALT, true); settle();
    sysclk_step(); sysclk_step(); sysclk_step();
    test_check_u16(t_now(), 1, "T_frozen_by_HALT");
    drv(&P_HALT, false); settle();
    sysclk_step();
    test_check_u16(t_now(), 2, "T_resumes");
    /* reset overrides freeze ('163 sync MR beats CET) */
    drv(&P_HALT, true); settle();
    do_reset();
    test_check_u16(t_now(), 0, "reset_beats_halt");
    drv(&P_HALT, false);
    test_end();
}
