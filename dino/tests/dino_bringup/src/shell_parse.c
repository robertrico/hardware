/* Pure parser — must compile on host cc AND avr-gcc (no AVR includes). */
#include <string.h>
#include "shell.h"

static void copy_tok(char *dst, const char *src, unsigned dstsz, unsigned n) {
    if (n >= dstsz) n = dstsz - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

cmd_t shell_parse(const char *line) {
    cmd_t c;
    memset(&c, 0, sizeof c);
    c.kind = CMD_BAD;
    while (*line == ' ') line++;

    if (strcmp(line, "list") == 0) { c.kind = CMD_LIST; return c; }
    if (strcmp(line, "help") == 0) { c.kind = CMD_HELP; return c; }

    if (strncmp(line, "run ", 4) == 0 || strncmp(line, "pins ", 5) == 0) {
        int is_run = (line[0] == 'r');
        const char *arg = line + (is_run ? 4 : 5);
        while (*arg == ' ') arg++;
        if (!*arg) return c;
        if (is_run && strcmp(arg, "all") == 0) { c.kind = CMD_RUN_ALL; return c; }
        const char *dot = strchr(arg, '.');
        const char *end = arg + strlen(arg);
        if (is_run && dot && dot > arg && dot + 1 < end) {
            copy_tok(c.module, arg, sizeof c.module, (unsigned)(dot - arg));
            copy_tok(c.test, dot + 1, sizeof c.test, (unsigned)(end - dot - 1));
            c.kind = CMD_RUN_ONE;
        } else if (!dot) {
            copy_tok(c.module, arg, sizeof c.module, (unsigned)(end - arg));
            c.kind = is_run ? CMD_RUN_MODULE : CMD_PINS;
        }
        return c;
    }
    return c;
}
