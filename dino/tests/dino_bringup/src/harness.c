#include <avr/io.h>
#include <avr/pgmspace.h>
#include <util/delay.h>
#include <string.h>
#include "harness.h"
#include "pinmap_gen.h"
#include "uart.h"

/* ---- pin resolution: "PA0/D22" -> registers ---- */
typedef struct { char letter; volatile uint8_t *port, *ddr, *pinr; } portdef_t;
static const portdef_t PORTS[] = {
    {'A', &PORTA, &DDRA, &PINA}, {'B', &PORTB, &DDRB, &PINB},
    {'C', &PORTC, &DDRC, &PINC}, {'D', &PORTD, &DDRD, &PIND},
    {'E', &PORTE, &DDRE, &PINE}, {'F', &PORTF, &DDRF, &PINF},
    {'G', &PORTG, &DDRG, &PING}, {'H', &PORTH, &DDRH, &PINH},
    {'J', &PORTJ, &DDRJ, &PINJ}, {'K', &PORTK, &DDRK, &PINK},
    {'L', &PORTL, &DDRL, &PINL},
};

bool pin_lookup(const char *megapin, hwpin_t *out) {
    if (megapin[0] != 'P') return false;
    for (uint8_t i = 0; i < sizeof PORTS / sizeof PORTS[0]; i++) {
        if (PORTS[i].letter == megapin[1]) {
            out->port = PORTS[i].port;
            out->ddr = PORTS[i].ddr;
            out->pinr = PORTS[i].pinr;
            out->bit = (uint8_t)(megapin[2] - '0');
            return out->bit <= 7;
        }
    }
    return false;
}

/* Resolve a contract signal through the generated pinmap so module test
   files never hardcode pool-pin strings. Entries may be alias joins
   ("M15=ROM_EN"); a match is the whole string or any '='-separated part. */
bool modmap_entry(const char *module, uint8_t idx,
                  char *sig, char *megapin, char *dir) {
    for (uint8_t m = 0; m < MODMAP_COUNT; m++) {
        modmap_t mm;
        memcpy_P(&mm, &MODMAPS[m], sizeof mm);
        if (strcmp_P(module, mm.module) != 0) continue;
        if (idx >= mm.n) return false;
        sigpin_t sp;
        memcpy_P(&sp, &mm.sig[idx], sizeof sp);
        strcpy_P(sig, sp.signal);
        strcpy_P(megapin, sp.megapin);
        *dir = sp.dir;
        return true;
    }
    return false;
}

bool sig_lookup(const char *module, const char *signal, hwpin_t *out) {
    for (uint8_t m = 0; m < MODMAP_COUNT; m++) {
        modmap_t mm;
        memcpy_P(&mm, &MODMAPS[m], sizeof mm);
        if (strcmp_P(module, mm.module) != 0) continue;
        for (uint8_t i = 0; i < mm.n; i++) {
            sigpin_t sp;
            char buf[48];
            memcpy_P(&sp, &mm.sig[i], sizeof sp);
            strcpy_P(buf, sp.signal);
            bool match = (strcmp(buf, signal) == 0);
            if (!match) {
                char *tok = buf;
                for (char *p = buf; !match; p++) {
                    if (*p != '=' && *p != '\0') continue;
                    char c = *p;
                    *p = '\0';
                    match = (strcmp(tok, signal) == 0);
                    if (c == '\0') break;
                    tok = p + 1;
                }
            }
            if (match) {
                strcpy_P(buf, sp.megapin);
                return pin_lookup(buf, out);
            }
        }
        return false;   /* module found, signal absent */
    }
    return false;
}

void drv(const hwpin_t *p, bool level) {
    if (level) *p->port |= _BV(p->bit); else *p->port &= (uint8_t)~_BV(p->bit);
    *p->ddr |= _BV(p->bit);
}

void rel(const hwpin_t *p) {
    *p->ddr &= (uint8_t)~_BV(p->bit);
    *p->port &= (uint8_t)~_BV(p->bit);   /* pullup off */
}

bool smp(const hwpin_t *p) { return (*p->pinr & _BV(p->bit)) != 0; }

void settle(void) { _delay_us(5); }

bool floats(const hwpin_t *p) {
    /* charge trick: park a level, release, see if it holds; repeat inverted.
       A driven net snaps to the driver on at least one polarity. */
    drv(p, false); settle(); rel(p);
    _delay_us(1);
    bool held_lo = !smp(p);
    drv(p, true); settle(); rel(p);
    _delay_us(1);
    bool held_hi = smp(p);
    return held_lo && held_hi;
}

/* ---- clock ---- */
static hwpin_t s_clk, s_clkn;
static bool s_have_clkn;

void clk_bind(const hwpin_t *clk, const hwpin_t *clkn) {
    s_clk = *clk;
    s_have_clkn = (clkn != 0);
    if (clkn) s_clkn = *clkn;
    clk_lo();
}

void clk_lo(void) {
    drv(&s_clk, false);
    if (s_have_clkn) drv(&s_clkn, true);
    settle();
}

void clk_hi(void) {
    if (s_have_clkn) drv(&s_clkn, false);   /* never both high */
    drv(&s_clk, true);
    settle();
}

void step(void) { clk_lo(); clk_hi(); }

/* ---- fixed-port buses (allocation per bring-up spec) ---- */
void bus_w_write(uint8_t v)   { PORTA = v; DDRA = 0xFF; }
uint8_t bus_w_read(void)      { DDRA = 0x00; PORTA = 0x00; settle(); return PINA; }
void bus_w_release(void)      { DDRA = 0x00; PORTA = 0x00; }
void bus_mdr_write(uint8_t v) { PORTF = v; DDRF = 0xFF; }
uint8_t bus_mdr_read(void)    { DDRF = 0x00; PORTF = 0x00; settle(); return PINF; }
void bus_mdr_release(void)    { DDRF = 0x00; PORTF = 0x00; }
uint16_t bus_m_read(void) {
    DDRC = 0x00; PORTC = 0x00; DDRL = 0x00; PORTL = 0x00; settle();
    return (uint16_t)PINC | ((uint16_t)PINL << 8);
}
void bus_m_drive(uint16_t v) {
    PORTC = (uint8_t)v; DDRC = 0xFF;
    PORTL = (uint8_t)(v >> 8); DDRL = 0xFF;
}
void bus_m_release(void) { DDRC = 0; PORTC = 0; DDRL = 0; PORTL = 0; }

/* ---- assert machinery ---- */
uint16_t g_pass, g_fail;
static const char *s_mod, *s_name;
static bool s_ok;

void test_begin(const char *module, const char *name) {
    s_mod = module; s_name = name; s_ok = true;
}

static void fail_prefix(const char *label) {
    uart_puts("FAIL ");
    uart_puts(s_mod); uart_putc('.'); uart_puts(s_name);
    uart_putc(' '); uart_puts(label);
}

void test_check_u16(uint16_t got, uint16_t want, const char *label) {
    if (got == want) return;
    s_ok = false;
    fail_prefix(label);
    uart_puts(" want=0x"); uart_puthex16(want);
    uart_puts(" got=0x"); uart_puthex16(got);
    uart_puts("\r\n");
}

void test_check_bool(bool got, bool want, const char *label) {
    test_check_u16(got ? 1 : 0, want ? 1 : 0, label);
}

bool test_end(void) {
    if (s_ok) {
        g_pass++;
        uart_puts("PASS ");
        uart_puts(s_mod); uart_putc('.'); uart_puts(s_name);
        uart_puts("\r\n");
    } else {
        g_fail++;
    }
    return s_ok;
}
