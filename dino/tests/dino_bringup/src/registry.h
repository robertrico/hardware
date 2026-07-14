#ifndef REGISTRY_H
#define REGISTRY_H
#include <stdint.h>

typedef void (*testfn_t)(void);
typedef struct { const char *module; const char *name; testfn_t fn; } testcase_t;

#define TEST_TABLE(X) \
    X(selftest, loopback) \
    X(root, divider) \
    X(root, tstate_walk) \
    X(root, reset_sync) \
    X(root, reset_tclear) \
    X(root, end_clear) \
    X(root, halt_freeze)

#define X_DECL(mod, name) void t_##mod##_##name(void);
TEST_TABLE(X_DECL)
#undef X_DECL

extern const testcase_t TESTS[];
extern const uint16_t TEST_COUNT;

#endif
