#include <avr/io.h>
#include <util/delay.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"

/* Live-clock guided tests: Y1 SEATED, DUT free-runs at 4.096MHz/4 =
   ~1.024MHz CLK. The rig cannot step-track T at that speed. Two bench
   lessons shape the sampling here:
   1) The T nibble spans two AVR ports — a 4-read composite stitches bits
      from different counts (~1-2 counts apart at 1MHz). Bits that share a
      port are read atomically as a pair instead.
   2) 16MHz rig vs 4.096MHz DUT is EXACTLY 125:32 — a fixed-period poll is
      phase-locked to the counter and revisits the same subset of counts
      forever (bench: deterministic partial masks 0xEC00/0xE780). Every
      coverage check dithers its sample spacing (LFSR) to break the lock;
      counting ORDER is proven on the T3:T2 pair, whose states last 4 CLK
      (~3.9us) — a tight poll advances <4 counts per read and cannot skip
      a state.
   Reset is the physical button — armed-watcher tests print an instruction,
   then watch the RESET line. The RC stretch holds RESET asserted (clock
   gated, T frozen) after release — measured anywhere from ~0.25s to ~2.2s
   — so post-reset checks wait on the LINE, never on a timer. */

/* Pin bindings: contract signals resolved through the generated pinmap
   (sig_lookup walks pinmap_gen.h), so hookup can never drift from
   `pins root`. */
static hwpin_t P_END, P_HALT, P_CLK, P_CLKN, P_RESET, P_RESETN;
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
    ok &= bind1("END",    &P_END);      /* END        (rig drives)  */
    ok &= bind1("HALT",   &P_HALT);     /* HALT       (rig drives)  */
    ok &= bind1("CLK",    &P_CLK);      /* CLK        (rig samples) */
    ok &= bind1("~{CLK}", &P_CLKN);     /* ~{CLK}     (rig samples) */
    ok &= bind1("RESET",  &P_RESET);    /* RESET      (rig samples) */
    ok &= bind1("~{RESET}", &P_RESETN); /* ~{RESET}   (rig samples) */
    ok &= bind1("T0", &P_T[0]);         /* T0         (rig samples) */
    ok &= bind1("T1", &P_T[1]);         /* T1 */
    ok &= bind1("T2", &P_T[2]);         /* T2 */
    ok &= bind1("T3", &P_T[3]);         /* T3 */
    if (!ok) return false;              /* never drive a garbage pin */
    /* atomic pair reads need T1:T0 and T3:T2 each on one port — guard
       against pinmap regeneration splitting them */
    if (P_T[0].pinr != P_T[1].pinr || P_T[2].pinr != P_T[3].pinr) {
        test_check_bool(false, true, "T_pairs_share_ports");
        return false;
    }
    drv(&P_END, false);
    drv(&P_HALT, false);
    s_bound = true;
    return true;
}

/* ---- sampling primitives ---- */

/* 0-6us pseudo-random gap: decorrelates the poll from the 125:32 lock */
static uint16_t s_lfsr = 0xACE1;
static void dither(void) {
    s_lfsr = (uint16_t)((s_lfsr >> 1) ^ ((uint16_t)-(s_lfsr & 1) & 0xB400));
    for (uint8_t j = (uint8_t)(s_lfsr & 0x1F); j; j--)
        __asm__ volatile("nop");
}

/* two T bits sharing a PIN register, one read: no inter-bit skew */
static uint8_t pair2(const hwpin_t *b0, const hwpin_t *b1) {
    uint8_t r = *b0->pinr;
    return (uint8_t)(((r >> b0->bit) & 1) | (((r >> b1->bit) & 1) << 1));
}

static uint8_t t_now(void) {
    return (uint8_t)(pair2(&P_T[0], &P_T[1]) |
                     (pair2(&P_T[2], &P_T[3]) << 2));
}

/* All samples identical -> true, value in *out. Skew-immune: frozen. */
static bool t_frozen(uint8_t *out) {
    uint8_t v = t_now();
    for (uint8_t i = 0; i < 64; i++) {
        _delay_us(37);
        dither();
        if (t_now() != v) return false;
    }
    *out = v;
    return true;
}

/* dithered coverage: all 4 combos of one pair seen */
static bool pair_all4(const hwpin_t *b0, const hwpin_t *b1) {
    uint8_t seen = 0;
    for (uint16_t i = 0; i < 50000 && seen != 0x0F; i++) {
        seen |= (uint8_t)(1 << pair2(b0, b1));
        dither();
    }
    return seen == 0x0F;
}

/* counter alive: both pairs cycle through all 4 combos */
static bool t_alive(void) {
    return pair_all4(&P_T[0], &P_T[1]) && pair_all4(&P_T[2], &P_T[3]);
}

/* Post-reset guard: RC stretch holds RESET (and gates the clock) after
   the button is released — wait on the line, duration varies. */
static bool await_reset_release(void) {
    if (!smp(&P_RESET)) return true;
    uart_puts("     RESET asserted — waiting out RC stretch...\r\n");
    return await_level(&P_RESET, false, 10000);
}

void t_root_clock(void) {
    test_begin("root", "clock");
    if (!bind()) { test_end(); return; }
    test_check_bool(await_reset_release(), true, "RESET_clear_before_gate");
    /* frequency: hardware edge count — needs CLK on PD7 (Timer0 T0 pin).
       Guard against pinmap regeneration moving it. */
    if (P_CLK.pinr != &PIND || P_CLK.bit != 7) {
        test_check_bool(false, true, "CLK_on_PD7_T0_pin");
        test_end(); return;
    }
    uint32_t edges = freq_count_t0(100);            /* 100ms gate */
    uint16_t khz = (uint16_t)(edges / 100);         /* edges*10Hz -> kHz */
    test_check_range(khz, 1003, 1044, "CLK_kHz");   /* 1024 +/-2% */
    /* ~CLK alive: both levels seen (complementarity at 1MHz is async-skew
       territory — scope check, not rig check) */
    bool lo = false, hi = false;
    for (uint16_t i = 0; i < 1000 && !(lo && hi); i++) {
        if (smp(&P_CLKN)) hi = true; else lo = true;
        dither();
    }
    test_check_bool(lo && hi, true, "CLKN_toggles");
    test_end();
}

/* ---- burst capture: the sequence check ----
   Grab both T ports back-to-back into SRAM at ~7 cycles/sample (~440ns) —
   over 2 samples per T state at 1.024MHz — then verify offline that every
   state change is +1 mod 16, rollover included. The two port reads sit one
   cycle apart, so a carry edge can straddle them and forge one bogus
   sample (~16% of edges); the walk drops a single-sample break when the
   following sample resyncs to the expected count. */
#define NCAP 1024
static uint8_t s_capg[NCAP], s_capb[NCAP];

static void capture_burst(void) {
    /* asm keeps it at 7 cycles/sample (437ns — 2.2 samples per T state);
       gcc -Os emits 10 (625ns), and >=2 samples per state is what lets the
       walk below drop straddle glitches safely. X -> s_capg, Z -> s_capb. */
    uint8_t *pg = s_capg, *pb = s_capb;
    uint16_t n = NCAP / 4;
    uint8_t t;
    __asm__ volatile(
        "1:                     \n\t"
        "in  %[t], %[ping]      \n\t"
        "st  X+, %[t]           \n\t"
        "in  %[t], %[pinb]      \n\t"
        "st  Z+, %[t]           \n\t"
        "in  %[t], %[ping]      \n\t"
        "st  X+, %[t]           \n\t"
        "in  %[t], %[pinb]      \n\t"
        "st  Z+, %[t]           \n\t"
        "in  %[t], %[ping]      \n\t"
        "st  X+, %[t]           \n\t"
        "in  %[t], %[pinb]      \n\t"
        "st  Z+, %[t]           \n\t"
        "in  %[t], %[ping]      \n\t"
        "st  X+, %[t]           \n\t"
        "in  %[t], %[pinb]      \n\t"
        "st  Z+, %[t]           \n\t"
        "sbiw %[n], 1           \n\t"
        "brne 1b                \n\t"
        : [t] "=&r" (t), [n] "+w" (n), "+x" (pg), "+z" (pb)
        : [ping] "I" (_SFR_IO_ADDR(PING)), [pinb] "I" (_SFR_IO_ADDR(PINB))
        : "memory");
}

static uint8_t cap_dec(uint16_t i) {
    uint8_t g = s_capg[i], b = s_capb[i];
    return (uint8_t)(((g >> P_T[0].bit) & 1) |
                     (((g >> P_T[1].bit) & 1) << 1) |
                     (((b >> P_T[2].bit) & 1) << 2) |
                     (((b >> P_T[3].bit) & 1) << 3));
}

static void put_nib(uint8_t v) {
    uart_putc(v < 10 ? (char)('0' + v) : (char)('A' + v - 10));
}

void t_root_tstates(void) {
    test_begin("root", "tstates");
    if (!bind()) { test_end(); return; }
    test_check_bool(await_reset_release(), true, "RESET_clear_before_sample");
    /* burst loop reads PING/PINB directly for speed — guard the pinmap */
    if (P_T[0].pinr != &PING || P_T[2].pinr != &PINB) {
        test_check_bool(false, true, "T_on_PING_PINB");
        test_end(); return;
    }
    capture_burst();
    uint16_t steps = 0, viol = 0;
    uint8_t cur = cap_dec(0), shown = 0;
    uart_puts("     seq: "); put_nib(cur);
    for (uint16_t i = 1; i < NCAP; i++) {
        uint8_t v = cap_dec(i);
        if (v == cur) continue;
        if (v == ((cur + 1) & 0x0F)) {
            cur = v; steps++;
            if (shown < 32) { uart_putc(' '); put_nib(v); shown++; }
            continue;
        }
        /* straddled-carry glitch? next sample must resync */
        uint8_t nxt = (i + 1 < NCAP) ? cap_dec(i + 1) : v;
        if (nxt == cur || nxt == ((cur + 1) & 0x0F)) continue;
        viol++;
        cur = v;                          /* resync and keep walking */
    }
    uart_puts(" ...\r\n");
    /* 1024 samples ~ 447us ~ 458 T states: demand most of them, in order */
    test_check_range(steps, 320, NCAP, "T_seq_steps");
    test_check_u16(viol, 0, "T_seq_violations");
    test_end();
}

void t_root_reset(void) {
    test_begin("root", "reset");
    if (!bind()) { test_end(); return; }
    uint8_t v = 0xFF;
    uart_puts("ARM  press+hold RESET button now (10s)...\r\n");
    if (!await_level(&P_RESET, true, 10000)) {
        test_check_bool(false, true, "RESET_seen");
        test_end(); return;
    }
    uart_puts("SEEN RESET asserted\r\n");
    _delay_ms(50);                       /* ride out contact bounce */
    test_check_bool(smp(&P_RESETN), false, "RESETN_complement_asserted");
    test_check_bool(t_frozen(&v) && v == 0, true, "T_zero_during_hold");
    uart_puts("     release RESET button...\r\n");
    if (!await_level(&P_RESET, false, 10000)) {
        test_check_bool(false, true, "RESET_released");
        test_end(); return;
    }
    uart_puts("SEEN RESET released (RC stretch done)\r\n");
    _delay_ms(50);
    test_check_bool(smp(&P_RESETN), true, "RESETN_complement_released");
    test_check_bool(t_alive(), true, "T_counts_after_release");
    test_end();
}

void t_root_halt(void) {
    test_begin("root", "halt");
    if (!bind()) { test_end(); return; }
    test_check_bool(await_reset_release(), true, "RESET_clear_at_start");
    uint8_t v = 0xFF;
    drv(&P_HALT, true); _delay_ms(1);
    test_check_bool(t_frozen(&v), true, "T_frozen_by_HALT");
    drv(&P_HALT, false); _delay_ms(1);
    test_check_bool(t_alive(), true, "T_resumes");
    /* reset overrides freeze ('163 sync MR beats CET) */
    drv(&P_HALT, true); _delay_ms(1);
    uart_puts("ARM  press+release RESET button now (10s)...\r\n");
    if (!await_level(&P_RESET, true, 10000)) {
        test_check_bool(false, true, "RESET_seen_during_halt");
        drv(&P_HALT, false);
        test_end(); return;
    }
    uart_puts("SEEN RESET asserted\r\n");
    if (!await_level(&P_RESET, false, 10000)) {
        test_check_bool(false, true, "RESET_released_during_halt");
        drv(&P_HALT, false);
        test_end(); return;
    }
    uart_puts("SEEN RESET released (RC stretch done)\r\n");
    _delay_ms(50);
    test_check_bool(t_frozen(&v) && v == 0, true, "reset_beats_halt");
    drv(&P_HALT, false);
    test_end();
}

void t_root_end(void) {
    test_begin("root", "end");
    if (!bind()) { test_end(); return; }
    test_check_bool(await_reset_release(), true, "RESET_clear_at_start");
    uint8_t v = 0xFF;
    drv(&P_END, true); _delay_ms(1);     /* END clears T at every edge */
    test_check_bool(t_frozen(&v) && v == 0, true, "T_cleared_by_END");
    drv(&P_END, false); _delay_ms(1);
    test_check_bool(t_alive(), true, "counting_resumes");
    test_end();
}
