#include <avr/pgmspace.h>
#include "registry.h"

/* Whole registry lives in flash — module/name strings AND the table.
   Readers copy entries out with memcpy_P (see shell.c). */
#define X_STRS(mod, name) \
    static const char sm_##mod##_##name[] PROGMEM = #mod; \
    static const char sn_##mod##_##name[] PROGMEM = #name;
TEST_TABLE(X_STRS)
#undef X_STRS

#define X_ENTRY(mod, name) { sm_##mod##_##name, sn_##mod##_##name, t_##mod##_##name },
const testcase_t TESTS[] PROGMEM = { TEST_TABLE(X_ENTRY) };
#undef X_ENTRY
const uint16_t TEST_COUNT = sizeof TESTS / sizeof TESTS[0];
