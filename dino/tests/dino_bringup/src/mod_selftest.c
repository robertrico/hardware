#include <avr/io.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"

/* Pool-pair table lives in flash; copy a pin name into `buf` (>=16B)
   before pin_lookup (which wants RAM). The flash pointers themselves
   are valid test labels (labels are flash by convention). */
static const char pp0a[] PROGMEM = "PD7/D38"; static const char pp0b[] PROGMEM = "PG2/D39";
static const char pp1a[] PROGMEM = "PG1/D40"; static const char pp1b[] PROGMEM = "PG0/D41";
static const char pp2a[] PROGMEM = "PB3/D50"; static const char pp2b[] PROGMEM = "PB2/D51";
static const char pp3a[] PROGMEM = "PB1/D52"; static const char pp3b[] PROGMEM = "PB0/D53";
static const char pp4a[] PROGMEM = "PE4/D2";  static const char pp4b[] PROGMEM = "PE5/D3";
static const char pp5a[] PROGMEM = "PG5/D4";  static const char pp5b[] PROGMEM = "PE3/D5";
static const char pp6a[] PROGMEM = "PH3/D6";  static const char pp6b[] PROGMEM = "PH4/D7";
static const char pp7a[] PROGMEM = "PH5/D8";  static const char pp7b[] PROGMEM = "PH6/D9";
static const char pp8a[] PROGMEM = "PJ1/D14"; static const char pp8b[] PROGMEM = "PJ0/D15";
static const char pp9a[] PROGMEM = "PH1/D16"; static const char pp9b[] PROGMEM = "PH0/D17";
static const char ppAa[] PROGMEM = "PD3/D18"; static const char ppAb[] PROGMEM = "PD2/D19";
static const char * const POOL_PAIRS[][2] PROGMEM = {
    {pp0a, pp0b}, {pp1a, pp1b}, {pp2a, pp2b}, {pp3a, pp3b}, {pp4a, pp4b},
    {pp5a, pp5b}, {pp6a, pp6b}, {pp7a, pp7b}, {pp8a, pp8b}, {pp9a, pp9b},
    {ppAa, ppAb},
};
#define POOL_PIN(i, side) ((const char *)pgm_read_word(&POOL_PAIRS[i][side]))

static bool pool_pin(uint8_t i, uint8_t side, hwpin_t *out) {
    char buf[16];
    strcpy_P(buf, POOL_PIN(i, side));
    return pin_lookup(buf, out);
}

static void byte_loop(const char *label_P,
                      void (*wr)(uint8_t), uint8_t (*rd)(void),
                      void (*wrb)(uint8_t), uint8_t (*rdb)(void),
                      void (*rel_a)(void), void (*rel_b)(void)) {
    static const uint8_t pat[] = {0x00, 0xFF, 0xAA, 0x55, 0x01, 0x80};
    for (uint8_t i = 0; i < sizeof pat; i++) {
        rel_b();                 /* B side passive before A drives */
        wr(pat[i]); settle();
        test_check_u16(rdb(), pat[i], label_P);   /* rdb releases B (no-op here) */
        rel_a();                 /* A side passive before B drives */
        wrb(pat[i] ^ 0xFF); settle();
        test_check_u16(rd(), pat[i] ^ 0xFF, label_P);
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
    test_begin(PSTR("selftest"), PSTR("loopback"));
    uart_putsP("jumpers: PA<->PF bytewise, PC<->PL bytewise, pool pairs:\r\n");
    for (uint8_t i = 0; i < 11; i++) {
        uart_putsP("  "); uart_puts_p(POOL_PIN(i, 0));
        uart_putsP(" <-> "); uart_puts_p(POOL_PIN(i, 1)); uart_putsP("\r\n");
    }

    byte_loop(PSTR("PA<->PF"), bus_w_write, bus_w_read, bus_mdr_write,
              bus_mdr_read, bus_w_release, bus_mdr_release);
    byte_loop(PSTR("PC<->PL"), m_wr_lo, m_rd_lo, m_wr_hi, m_rd_hi,
              m_rel_lo, m_rel_hi);

    for (uint8_t i = 0; i < 11; i++) {
        hwpin_t a, b;
        pool_pin(i, 0, &a);
        pool_pin(i, 1, &b);
        for (uint8_t lv = 0; lv < 2; lv++) {
            rel(&b); drv(&a, lv); settle();
            test_check_bool(smp(&b), lv, POOL_PIN(i, 1));
            rel(&a); drv(&b, lv); settle();
            test_check_bool(smp(&a), lv, POOL_PIN(i, 0));
        }
        rel(&a); rel(&b);
    }
    test_end();
}

/* ---- per-module selftest: jumper only the pins THIS module's rig bundle
   uses, paired consecutively (bundle order = `pins <module>` order), plus
   any rig-side extras. Workflow: selftest <mod> with pair-jumpers ->
   remove jumpers -> wire the DUT per `pins <mod>` -> run <mod>. ---- */

static const char ex_root[] PROGMEM = "root";
static const char ex_p18[] PROGMEM = "PD3/D18";
static const char ex_p19[] PROGMEM = "PD2/D19";
typedef struct { const char *module; const char *pin; } extra_t;
static const extra_t EXTRAS[] PROGMEM = {
    {ex_root, ex_p18},   /* CLKIN */
    {ex_root, ex_p19},   /* RST_FORCE */
    /* control_word/mdr probes live in their generated bundles
       (PIN_PROBES) — no extras needed */
};
#define N_EXTRAS (sizeof EXTRAS / sizeof EXTRAS[0])

/* runtime RAM labels -> the _r check variants */
static void pair_check(const hwpin_t *a, const hwpin_t *b, const char *label) {
    for (uint8_t lv = 0; lv < 2; lv++) {
        rel(b); drv(a, lv); settle();
        test_check_bool_r(smp(b), lv, label);
        rel(a); drv(b, lv); settle();
        test_check_bool_r(smp(a), lv, label);
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
    if (n == 0) { uart_putsP("unknown module or empty bundle\r\n"); return; }
    for (uint8_t e = 0; e < N_EXTRAS && n < 36; e++) {
        extra_t ex;
        memcpy_P(&ex, &EXTRAS[e], sizeof ex);
        if (strcmp_P(module, ex.module) != 0) continue;
        strcpy_P(names[n], ex.pin);
        if (!pin_lookup(names[n], &pins[n])) continue;
        n++;
    }

    uart_putsP("jumper these pairs (rig-only, no DUT, plain wire):\r\n");
    for (uint8_t i = 0; i + 1 < n; i += 2) {
        uart_putsP("  "); uart_puts(names[i]);
        uart_putsP(" <-> "); uart_puts(names[i + 1]); uart_putsP("\r\n");
    }
    if (n & 1) {
        uart_putsP("  ("); uart_puts(names[n - 1]);
        uart_putsP(" unpaired: odd bundle — verified only for stuck-driver, not continuity)\r\n");
    }

    test_begin(PSTR("selftest"), modmap_name_P(module));
    for (uint8_t i = 0; i + 1 < n; i += 2)
        pair_check(&pins[i], &pins[i + 1], names[i]);
    if (n & 1) {
        /* lone pin: at least prove nothing external drives it */
        test_check_bool_r(floats(&pins[n - 1]), true, names[n - 1]);
    }
    test_end();
}
