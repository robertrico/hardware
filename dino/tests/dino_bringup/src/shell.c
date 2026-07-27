#include <string.h>
#include "shell.h"
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "pinmap_gen.h"

static void print_summary(void) {
    uart_putsP("SUMMARY: ");
    uart_putdec(g_pass); uart_putsP(" pass, ");
    uart_putdec(g_fail); uart_putsP(" fail\r\n");
}

static void run_filtered(const char *module, const char *test) {
    /* TESTS lives in flash (registry.c) — copy each entry out; its
       module/name pointers are flash addresses (strcmp_P: ram, flash) */
    g_pass = 0; g_fail = 0;
    uint16_t matched = 0;
    for (uint16_t i = 0; i < TEST_COUNT; i++) {
        testcase_t tc;
        memcpy_P(&tc, &TESTS[i], sizeof tc);
        if (module && strcmp_P(module, tc.module) != 0) continue;
        if (test && strcmp_P(test, tc.name) != 0) continue;
        matched++;
        tc.fn();
    }
    if (!matched) uart_putsP("no matching tests (see: list)\r\n");
    else print_summary();
}

static void print_pins(const char *module) {
    /* MODMAPS/sigpin tables live in flash — copy entries out with memcpy_P;
       the copied pointers are themselves flash addresses (uart_puts_p).
       Slot numbers (slotmap_gen.h) are assigned so the Mega's descending
       pin run maps onto descending slots, so this list IS the ribbon
       order — read it straight down, no cross-referencing. */
    for (uint8_t m = 0; m < MODMAP_COUNT; m++) {
        modmap_t mm;
        memcpy_P(&mm, &MODMAPS[m], sizeof mm);
        if (strcmp_P(module, mm.module) != 0) continue;
        uart_putsP("hookup for "); uart_puts(module);
        uart_putsP(" (GND first, always):\r\n  GND -> module GND rail\r\n");
        for (uint8_t i = 0; i < mm.n; i++) {
            sigpin_t sp;
            char sig[48];
            memcpy_P(&sp, &mm.sig[i], sizeof sp);
            uart_putsP("  ");
            uart_puts_p(sp.megapin);
            uart_putsP(" -> ");
            uart_puts_p(sp.signal);
            uart_puts_p(sp.dir == 'O' ? PSTR("  (rig drives)")
                        : sp.dir == 'I' ? PSTR("  (rig samples)")
                        : PSTR("  (bidir)"));
            strcpy_P(sig, sp.signal);
            uint8_t slot = slot_of(module, sig);
            if (slot) {
                uart_putsP("  slot ");
                uart_putdec(slot);
            }
            uart_putsP("\r\n");
        }
        return;
    }
    uart_putsP("unknown module\r\n");
}

void shell_execute(const cmd_t *c) {
    switch (c->kind) {
    case CMD_LIST: {
        char last[24] = "";
        for (uint16_t i = 0; i < TEST_COUNT; i++) {
            testcase_t tc;
            memcpy_P(&tc, &TESTS[i], sizeof tc);
            if (strcmp_P(last, tc.module) != 0) {
                strcpy_P(last, tc.module);
                uart_puts(last); uart_putsP(":\r\n");
            }
            uart_putsP("  "); uart_puts_p(tc.name); uart_putsP("\r\n");
        }
        break;
    }
    case CMD_RUN_ALL:    run_filtered(0, 0); break;
    case CMD_RUN_MODULE: run_filtered(c->module, 0); break;
    case CMD_RUN_ONE:    run_filtered(c->module, c->test); break;
    case CMD_PINS:       print_pins(c->module); break;
    case CMD_SELFTEST_MOD:
        g_pass = 0; g_fail = 0;
        selftest_module(c->module);
        print_summary();
        break;
    case CMD_IDLE:
        pins_idle();
        uart_putsP("all rig pins released — safe to power-cycle the DUT\r\n");
        break;
    case CMD_HELP:
    case CMD_BAD:
        uart_putsP("commands: list | run all | run <mod> | run <mod>.<test> | pins <mod> | selftest <mod> | idle\r\n");
        break;
    }
}
