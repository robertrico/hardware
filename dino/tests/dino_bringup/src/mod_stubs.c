/* Temporary link stubs — removed when mod_root.c lands (Task 6). */
#include "registry.h"
#include "harness.h"
#define STUB(mod, name) void t_##mod##_##name(void) { \
    test_begin(#mod, #name); test_check_bool(0, 1, "NOT IMPLEMENTED"); test_end(); }
STUB(root, divider)
STUB(root, tstate_walk)
STUB(root, reset_sync)
STUB(root, reset_tclear)
STUB(root, end_clear)
STUB(root, halt_freeze)
