/* Pure parser — must compile on host cc AND avr-gcc (no AVR includes). */
#include <string.h>
#include "shell.h"

static void copy_tok(char *dst, const char *src, unsigned dstsz, unsigned n) {
    if (n >= dstsz) n = dstsz - 1;
    memcpy(dst, src, n);
    dst[n] = '\0';
}

/* True if the n-byte token at s equals the literal lit. */
static int tok_eq(const char *s, unsigned n, const char *lit) {
    return strlen(lit) == n && memcmp(s, lit, n) == 0;
}

cmd_t shell_parse(const char *line) {
    cmd_t c;
    memset(&c, 0, sizeof c);
    c.kind = CMD_BAD;
    while (*line == ' ') line++;
    unsigned len = (unsigned)strlen(line);
    while (len && line[len - 1] == ' ') len--;   /* trim trailing spaces */

    if (tok_eq(line, len, "list")) { c.kind = CMD_LIST; return c; }
    if (tok_eq(line, len, "help")) { c.kind = CMD_HELP; return c; }

    if ((len > 4 && memcmp(line, "run ", 4) == 0) ||
        (len > 5 && memcmp(line, "pins ", 5) == 0)) {
        int is_run = (line[0] == 'r');
        const char *arg = line + (is_run ? 4 : 5);
        const char *end = line + len;
        while (arg < end && *arg == ' ') arg++;
        if (arg == end) return c;
        unsigned argn = (unsigned)(end - arg);
        if (is_run && tok_eq(arg, argn, "all")) { c.kind = CMD_RUN_ALL; return c; }
        const char *dot = memchr(arg, '.', argn);
        if (is_run && dot && dot > arg && dot + 1 < end) {
            copy_tok(c.module, arg, sizeof c.module, (unsigned)(dot - arg));
            copy_tok(c.test, dot + 1, sizeof c.test, (unsigned)(end - dot - 1));
            c.kind = CMD_RUN_ONE;
        } else if (!dot) {
            copy_tok(c.module, arg, sizeof c.module, argn);
            c.kind = is_run ? CMD_RUN_MODULE : CMD_PINS;
        }
        return c;
    }
    return c;
}
