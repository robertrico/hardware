#ifndef REGISTRY_H
#define REGISTRY_H
#include <stdint.h>

typedef void (*testfn_t)(void);
typedef struct { const char *module; const char *name; testfn_t fn; } testcase_t;

#define TEST_TABLE(X) \
    X(selftest, loopback) \
    X(root, clock) \
    X(root, tstates) \
    X(root, reset) \
    X(root, halt) \
    X(root, end)

#define X_DECL(mod, name) void t_##mod##_##name(void);
TEST_TABLE(X_DECL)
#undef X_DECL

extern const testcase_t TESTS[];
extern const uint16_t TEST_COUNT;

#endif
