/* Temporary link stubs — removed when mod_selftest.c / mod_root.c land. */
#include "registry.h"
#include "harness.h"
#define STUB(mod, name) void t_##mod##_##name(void) { \
    test_begin(#mod, #name); test_check_bool(0, 1, "NOT IMPLEMENTED"); test_end(); }
TEST_TABLE(STUB)
