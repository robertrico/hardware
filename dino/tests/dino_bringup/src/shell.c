#include <string.h>
#include "shell.h"
#include "registry.h"
#include "harness.h"
#include "uart.h"
#include "pinmap_gen.h"

static void print_summary(void) {
    uart_puts("SUMMARY: ");
    uart_putdec(g_pass); uart_puts(" pass, ");
    uart_putdec(g_fail); uart_puts(" fail\r\n");
}

static void run_filtered(const char *module, const char *test) {
    g_pass = 0; g_fail = 0;
    uint16_t matched = 0;
    for (uint16_t i = 0; i < TEST_COUNT; i++) {
        if (module && strcmp(TESTS[i].module, module) != 0) continue;
        if (test && strcmp(TESTS[i].name, test) != 0) continue;
        matched++;
        TESTS[i].fn();
    }
    if (!matched) uart_puts("no matching tests (see: list)\r\n");
    else print_summary();
}

static void print_pins(const char *module) {
    for (uint8_t m = 0; m < MODMAP_COUNT; m++) {
        if (strcmp(MODMAPS[m].module, module) != 0) continue;
        uart_puts("hookup for "); uart_puts(module);
        uart_puts(" (GND first, always):\r\n  GND -> module GND rail\r\n");
        for (uint8_t i = 0; i < MODMAPS[m].n; i++) {
            uart_puts("  ");
            uart_puts(MODMAPS[m].sig[i].megapin);
            uart_puts(" -> ");
            uart_puts(MODMAPS[m].sig[i].signal);
            uart_puts(MODMAPS[m].sig[i].dir == 'O' ? "  (rig drives)"
                      : MODMAPS[m].sig[i].dir == 'I' ? "  (rig samples)"
                      : "  (bidir)");
            uart_puts("\r\n");
        }
        return;
    }
    uart_puts("unknown module\r\n");
}

void shell_execute(const cmd_t *c) {
    switch (c->kind) {
    case CMD_LIST: {
        const char *last = "";
        for (uint16_t i = 0; i < TEST_COUNT; i++) {
            if (strcmp(TESTS[i].module, last) != 0) {
                last = TESTS[i].module;
                uart_puts(last); uart_puts(":\r\n");
            }
            uart_puts("  "); uart_puts(TESTS[i].name); uart_puts("\r\n");
        }
        break;
    }
    case CMD_RUN_ALL:    run_filtered(0, 0); break;
    case CMD_RUN_MODULE: run_filtered(c->module, 0); break;
    case CMD_RUN_ONE:    run_filtered(c->module, c->test); break;
    case CMD_PINS:       print_pins(c->module); break;
    case CMD_HELP:
    case CMD_BAD:
        uart_puts("commands: list | run all | run <mod> | run <mod>.<test> | pins <mod>\r\n");
        break;
    }
}
