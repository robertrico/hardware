#include <avr/io.h>
#include <util/delay.h>
#include <string.h>
#include "registry.h"
#include "harness.h"
#include "uart.h"

/* I/O board: the 8-switch input port and the 8-LED output display. The
   only module with a human in the loop — switches have to be thrown and
   LEDs have to be looked at, so those two tests prompt and wait.

   Netlist-verified structure (input_output.kicad_sch, 2026-07-26):
     SW1        8-way DIP, one side commoned to GND, other side IS0-7.
     R17-R24    pull-ups from +5V to IS0-7.
                => a CLOSED switch reads 0, an OPEN switch reads 1.
                   That is the opposite of what "switch on" suggests, so
                   every prompt below spells out which to open and close.
     SWITCH-GATE1 '244: A = IS0-7, Y = W0-7, BOTH ~G tied to ~{SW_OUT}.
                So the switches reach W only while ~{SW_OUT} is asserted;
                otherwise the port is high-Z and W belongs to whoever else
                is driving it.
     R9-R16     OB0-7 -> LED anodes; cathodes to GND. LED lights on a
                HIGH, so the rig drives OB directly and you confirm by
                eye. (In the real machine OB comes from the OUT register
                on the registers board — here the rig substitutes for it.)

   Driven lines: ~{SW_OUT} OB0 OB1 OB2 OB3 OB4 OB5 OB6 OB7 (series R).
   Sampled lines: W0 W1 W2 W3 W4 W5 W6 W7.
   (coverage: every contract signal named). */

static hwpin_t P_SWOUT, P_W[8], P_OB[8];
static bool s_bound;
static uint8_t s_gen;

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
static const char ob_s0[] PROGMEM = "OB0";
static const char ob_s1[] PROGMEM = "OB1";
static const char ob_s2[] PROGMEM = "OB2";
static const char ob_s3[] PROGMEM = "OB3";
static const char ob_s4[] PROGMEM = "OB4";
static const char ob_s5[] PROGMEM = "OB5";
static const char ob_s6[] PROGMEM = "OB6";
static const char ob_s7[] PROGMEM = "OB7";
static const char * const OB_NAMES[8] PROGMEM = {
    ob_s0, ob_s1, ob_s2, ob_s3, ob_s4, ob_s5, ob_s6, ob_s7,
};

/* per-pin so the bundle can be re-pinned without touching this file */
static void ob_write(uint8_t v) {
    for (uint8_t i = 0; i < 8; i++) drv(&P_OB[i], (v >> i) & 1);
    settle();
}

static uint8_t w_read(void) {
    settle();
    uint8_t v = 0;
    for (uint8_t i = 0; i < 8; i++)
        if (smp(&P_W[i])) v |= (uint8_t)(1u << i);
    return v;
}

static bool bind1(const char *sig_P, hwpin_t *out) {
    char sig[24];
    strcpy_P(sig, sig_P);
    if (sig_lookup("io", sig, out)) return true;
    uart_putsP("BIND FAIL "); uart_puts(sig); uart_putsP("\r\n");
    test_check_bool(false, true, sig_P);
    return false;
}

static bool bind(void) {
    if (s_bound && s_gen == g_pin_gen) return true;
    s_bound = false;
    bool ok = bind1(PSTR("~{SW_OUT}"), &P_SWOUT);
    for (uint8_t i = 0; i < 8; i++) {
        ok &= bind1(PN(W_NAMES, i), &P_W[i]);
        ok &= bind1(PN(OB_NAMES, i), &P_OB[i]);
    }
    if (!ok) return false;                  /* never drive a garbage pin */
    for (uint8_t i = 0; i < 8; i++) rel(&P_W[i]);
    ob_write(0x00);
    drv(&P_SWOUT, true);                    /* port off the W bus */
    settle();
    s_bound = true;
    s_gen = g_pin_gen;
    return true;
}

static void sw_enable(bool on) { drv(&P_SWOUT, !on); settle(); }

/* Wait for the operator. Returns the first character typed. */
static char prompt(void) {
    char buf[8];
    uart_getline(buf, sizeof buf);
    return buf[0];
}

/* Spell out the switch positions for a target byte, because a closed
   switch reads 0 and getting that backwards wastes a whole run. */
static void say_pattern(uint8_t want) {
    uart_putsP("     set the DIP so W reads 0x");
    uart_puthex8(want);
    uart_putsP("\r\n       OPEN  (reads 1):");
    for (uint8_t i = 0; i < 8; i++)
        if ((want >> i) & 1) { uart_putc(' '); uart_putdec(i); }
    uart_putsP("\r\n       CLOSED(reads 0):");
    for (uint8_t i = 0; i < 8; i++)
        if (!((want >> i) & 1)) { uart_putc(' '); uart_putdec(i); }
    uart_putsP("\r\n     then press Enter\r\n");
}

void t_io_power(void) {
    test_begin(PSTR("io"), PSTR("power"));
    if (!bind()) { test_end(); return; }
    /* PHANTOM-POWER CHECK (house rule). With the port enabled the '244
       drives all eight W lines from the pull-ups, whatever the switches
       say. An unpowered board cannot drive them at all, so a total float
       here means no supply — and unlike the other modules this one needs
       no signal to be at any particular level, only present. */
    ob_write(0x00);
    sw_enable(true);
    uint8_t floating = 0;
    for (uint8_t i = 0; i < 8; i++)
        if (floats(&P_W[i])) floating++;
    if (floating == 8)
        uart_putsP("     DUT looks UNPOWERED: with ~{SW_OUT} asserted the\r\n"
                   "     '244 must drive every W line. Check bench 5V.\r\n");
    else if (floating)
        uart_putsP("     PARTIAL float — board is powered, this is WIRING\r\n");
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(!floats(&P_W[i]), true, PN(W_NAMES, i));
    sw_enable(false);
    test_end();
}

void t_io_tristate(void) {
    test_begin(PSTR("io"), PSTR("tristate"));
    if (!bind()) { test_end(); return; }
    /* sw.tristate: ~{SW_OUT} released -> the port lets go of W entirely.
       This is the contract that lets the ALU, MAR and MDR share the bus;
       a '244 stuck enabled would fight every other source. */
    sw_enable(false);
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(floats(&P_W[i]), true, PN(W_NAMES, i));
    /* and it comes back when asserted */
    sw_enable(true);
    for (uint8_t i = 0; i < 8; i++)
        test_check_bool(!floats(&P_W[i]), true, PN(W_NAMES, i));
    sw_enable(false);
    test_end();
}

void t_io_switches(void) {
    test_begin(PSTR("io"), PSTR("switches"));
    if (!bind()) { test_end(); return; }
    /* sw.read, guided. Four patterns: all-low and all-high prove every
       line carries both levels and that the pull-up and the ground path
       both work; 0xC5 and 0x3A are non-palindromic (mirror-witness rule),
       so a reversed IS harness cannot slip through. */
    static const uint8_t PAT[4] = {0x00, 0xFF, 0xC5, 0x3A};
    for (uint8_t i = 0; i < 4; i++) {
        say_pattern(PAT[i]);
        (void)prompt();
        sw_enable(true);
        uint8_t got = w_read();
        sw_enable(false);
        if (got != PAT[i]) {
            uart_putsP("     got 0x"); uart_puthex8(got);
            uart_putsP(" — differing bits:");
            for (uint8_t b = 0; b < 8; b++)
                if (((got ^ PAT[i]) >> b) & 1) { uart_putc(' '); uart_putdec(b); }
            uart_putsP("\r\n");
        }
        test_check_u16(got, PAT[i], PSTR("switch_pattern"));
    }
    test_end();
}

void t_io_leds(void) {
    test_begin(PSTR("io"), PSTR("leds"));
    if (!bind()) { test_end(); return; }
    /* led.show, guided. A walking 1 down the row, slow enough to follow,
       then one question. Eyes are the only instrument for this one. */
    sw_enable(false);
    uart_putsP("     walking a single LED from OB0 to OB7, 500ms each —\r\n"
               "     watch the row now\r\n");
    for (uint8_t pass = 0; pass < 2; pass++)
        for (uint8_t b = 0; b < 8; b++) {
            ob_write((uint8_t)(1u << b));
            _delay_ms(500);
        }
    ob_write(0x00);
    uart_putsP("     did exactly one LED light at a time, in order,\r\n"
               "     with none dark and none stuck on? (y/n) ");
    char c = prompt();
    test_check_bool(c == 'y' || c == 'Y', true, PSTR("walking_LED_in_order"));
    /* all on, so a dim or dead LED shows up against its neighbours */
    ob_write(0xFF);
    uart_putsP("     all eight now driven — are all eight lit and even? (y/n) ");
    c = prompt();
    ob_write(0x00);
    test_check_bool(c == 'y' || c == 'Y', true, PSTR("all_LEDs_lit"));
    test_end();
}

void t_io_isolation(void) {
    test_begin(PSTR("io"), PSTR("isolation"));
    if (!bind()) { test_end(); return; }
    /* The LED side and the switch side share no nets. Driving OB must not
       disturb W — if it does, something is bridged between the display
       and the input port. */
    sw_enable(true);
    uint8_t base = w_read();
    ob_write(0xFF);
    test_check_u16(w_read(), base, PSTR("W_unchanged_by_OB_high"));
    ob_write(0x00);
    test_check_u16(w_read(), base, PSTR("W_unchanged_by_OB_low"));
    sw_enable(false);
    uart_putsP("     (switches read 0x"); uart_puthex8(base);
    uart_putsP(" throughout)\r\n");
    test_end();
}
