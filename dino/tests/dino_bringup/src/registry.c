#include "registry.h"

#define X_ENTRY(mod, name) { #mod, #name, t_##mod##_##name },
const testcase_t TESTS[] = { TEST_TABLE(X_ENTRY) };
#undef X_ENTRY
const uint16_t TEST_COUNT = sizeof TESTS / sizeof TESTS[0];
