#include <avr/io.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"

static const char *POOL_PAIRS[][2] = {
    {"PD7/D38", "PG2/D39"}, {"PG1/D40", "PG0/D41"}, {"PB3/D50", "PB2/D51"},
    {"PB1/D52", "PB0/D53"}, {"PE4/D2", "PE5/D3"},   {"PG5/D4", "PE3/D5"},
    {"PH3/D6", "PH4/D7"},   {"PH5/D8", "PH6/D9"},   {"PJ1/D14", "PJ0/D15"},
    {"PH1/D16", "PH0/D17"}, {"PD3/D18", "PD2/D19"},
};

static void byte_loop(const char *label,
                      void (*wr)(uint8_t), uint8_t (*rd)(void),
                      void (*wrb)(uint8_t), uint8_t (*rdb)(void),
                      void (*rel_a)(void), void (*rel_b)(void)) {
    static const uint8_t pat[] = {0x00, 0xFF, 0xAA, 0x55, 0x01, 0x80};
    for (uint8_t i = 0; i < sizeof pat; i++) {
        rel_b();                 /* B side passive before A drives */
        wr(pat[i]); settle();
        test_check_u16(rdb(), pat[i], label);   /* rdb releases B (no-op here) */
        rel_a();                 /* A side passive before B drives */
        wrb(pat[i] ^ 0xFF); settle();
        test_check_u16(rd(), pat[i] ^ 0xFF, label);
        rel_b();
    }
    rel_a(); rel_b();
}

static void m_wr_lo(uint8_t v) { PORTC = v; DDRC = 0xFF; }
static uint8_t m_rd_lo(void)   { DDRC = 0; PORTC = 0; settle(); return PINC; }
static void m_rel_lo(void)     { DDRC = 0; PORTC = 0; }
static void m_wr_hi(uint8_t v) { PORTL = v; DDRL = 0xFF; }
static uint8_t m_rd_hi(void)   { DDRL = 0; PORTL = 0; settle(); return PINL; }
static void m_rel_hi(void)     { DDRL = 0; PORTL = 0; }

void t_selftest_loopback(void) {
    test_begin("selftest", "loopback");
    uart_puts("jumpers: PA<->PF bytewise, PC<->PL bytewise, pool pairs:\r\n");
    for (uint8_t i = 0; i < 11; i++) {
        uart_puts("  "); uart_puts(POOL_PAIRS[i][0]);
        uart_puts(" <-> "); uart_puts(POOL_PAIRS[i][1]); uart_puts("\r\n");
    }

    byte_loop("PA<->PF", bus_w_write, bus_w_read, bus_mdr_write, bus_mdr_read,
              bus_w_release, bus_mdr_release);
    byte_loop("PC<->PL", m_wr_lo, m_rd_lo, m_wr_hi, m_rd_hi,
              m_rel_lo, m_rel_hi);

    for (uint8_t i = 0; i < 11; i++) {
        hwpin_t a, b;
        pin_lookup(POOL_PAIRS[i][0], &a);
        pin_lookup(POOL_PAIRS[i][1], &b);
        for (uint8_t lv = 0; lv < 2; lv++) {
            rel(&b); drv(&a, lv); settle();
            test_check_bool(smp(&b), lv, POOL_PAIRS[i][1]);
            rel(&a); drv(&b, lv); settle();
            test_check_bool(smp(&a), lv, POOL_PAIRS[i][0]);
        }
        rel(&a); rel(&b);
    }
    test_end();
}

/* ---- per-module selftest: jumper only the pins THIS module's rig bundle
   uses, paired consecutively (bundle order = `pins <module>` order), plus
   any rig-side extras. Workflow: selftest <mod> with pair-jumpers ->
   remove jumpers -> wire the DUT per `pins <mod>` -> run <mod>. ---- */

typedef struct { const char *module; const char *pin; const char *name; } extra_t;
static const extra_t EXTRAS[] = {
    {"root", "PD3/D18", "CLKIN"},
    {"root", "PD2/D19", "RST_FORCE"},
};
#define N_EXTRAS (sizeof EXTRAS / sizeof EXTRAS[0])

static void pair_check(const hwpin_t *a, const hwpin_t *b, const char *label) {
    for (uint8_t lv = 0; lv < 2; lv++) {
        rel(b); drv(a, lv); settle();
        test_check_bool(smp(b), lv, label);
        rel(a); drv(b, lv); settle();
        test_check_bool(smp(a), lv, label);
    }
    rel(a); rel(b);
}

void selftest_module(const char *module) {
    hwpin_t pins[36];
    char names[36][16];
    uint8_t n = 0;

    for (uint8_t i = 0; n < 36; i++) {
        char sig[48], megapin[16], dir;
        if (!modmap_entry(module, i, sig, megapin, &dir)) break;
        if (!pin_lookup(megapin, &pins[n])) continue;
        uint8_t k = 0;
        while (megapin[k] && k < 15) { names[n][k] = megapin[k]; k++; }
        names[n][k] = '\0';
        n++;
    }
    if (n == 0) { uart_puts("unknown module or empty bundle\r\n"); return; }
    for (uint8_t e = 0; e < N_EXTRAS && n < 36; e++) {
        if (strcmp(EXTRAS[e].module, module) != 0) continue;
        if (!pin_lookup(EXTRAS[e].pin, &pins[n])) continue;
        uint8_t k = 0;
        while (EXTRAS[e].pin[k] && k < 15) { names[n][k] = EXTRAS[e].pin[k]; k++; }
        names[n][k] = '\0';
        n++;
    }

    uart_puts("jumper these pairs (rig-only, no DUT, plain wire):\r\n");
    for (uint8_t i = 0; i + 1 < n; i += 2) {
        uart_puts("  "); uart_puts(names[i]);
        uart_puts(" <-> "); uart_puts(names[i + 1]); uart_puts("\r\n");
    }
    if (n & 1) {
        uart_puts("  ("); uart_puts(names[n - 1]);
        uart_puts(" unpaired: odd bundle — verified only for stuck-driver, not continuity)\r\n");
    }

    test_begin("selftest", module);
    for (uint8_t i = 0; i + 1 < n; i += 2)
        pair_check(&pins[i], &pins[i + 1], names[i]);
    if (n & 1) {
        /* lone pin: at least prove nothing external drives it */
        test_check_bool(floats(&pins[n - 1]), true, names[n - 1]);
    }
    test_end();
}
