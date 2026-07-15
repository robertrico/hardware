/* Host-side unit test for shell_parse. Build with system cc. */
#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../src/shell.h"

int main(void) {
    cmd_t c;
    c = shell_parse("list");            assert(c.kind == CMD_LIST);
    c = shell_parse("run all");         assert(c.kind == CMD_RUN_ALL);
    c = shell_parse("run mar");         assert(c.kind == CMD_RUN_MODULE);
    assert(strcmp(c.module, "mar") == 0);
    c = shell_parse("run mar.tristate");
    assert(c.kind == CMD_RUN_ONE);
    assert(strcmp(c.module, "mar") == 0);
    assert(strcmp(c.test, "tristate") == 0);
    c = shell_parse("pins control_word");
    assert(c.kind == CMD_PINS);
    assert(strcmp(c.module, "control_word") == 0);
    c = shell_parse("");                assert(c.kind == CMD_BAD);
    c = shell_parse("bogus nonsense");  assert(c.kind == CMD_BAD);
    c = shell_parse("run");             assert(c.kind == CMD_BAD);
    c = shell_parse("help");            assert(c.kind == CMD_HELP);
    /* overlong names must truncate safely, not overflow */
    c = shell_parse("run aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    assert(c.kind == CMD_RUN_MODULE);
    assert(strlen(c.module) < 24);
    /* trailing whitespace must be ignored */
    c = shell_parse("run all ");        assert(c.kind == CMD_RUN_ALL);
    c = shell_parse("list ");           assert(c.kind == CMD_LIST);
    c = shell_parse("run mar.tristate ");
    assert(c.kind == CMD_RUN_ONE);
    assert(strcmp(c.module, "mar") == 0);
    assert(strcmp(c.test, "tristate") == 0);
    /* malformed dotted forms stay rejected */
    c = shell_parse("run mar.");        assert(c.kind == CMD_BAD);
    c = shell_parse("pins mar.foo");    assert(c.kind == CMD_BAD);
    printf("shell parser: OK\n");
    return 0;
}
