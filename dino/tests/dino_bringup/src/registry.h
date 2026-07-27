#ifndef REGISTRY_H
#define REGISTRY_H
#include <stdint.h>

typedef void (*testfn_t)(void);
/* module/name are FLASH pointers; TESTS itself is PROGMEM — copy
   entries out with memcpy_P before use */
typedef struct { const char *module; const char *name; testfn_t fn; } testcase_t;

#define TEST_TABLE(X) \
    X(selftest, loopback) \
    X(root, clock) \
    X(root, tstates) \
    X(root, reset) \
    X(root, halt) \
    X(root, end) \
    X(pc, warmup) \
    X(pc, presence) \
    X(pc, count) \
    X(pc, carry) \
    X(pc, load) \
    X(pc, clear) \
    X(pc, mux) \
    X(pc, phase) \
    X(pc, precedence) \
    X(microcode, warmup) \
    X(microcode, presence) \
    X(microcode, order) \
    X(microcode, split) \
    X(microcode, crc) \
    X(microcode, taps) \
    X(microcode, stability) \
    X(control_word, warmup) \
    X(control_word, presence) \
    X(control_word, walk) \
    X(control_word, none) \
    X(control_word, truth) \
    X(control_word, sweep) \
    X(control_word, stability) \
    X(mdr, warmup) \
    X(mdr, presence) \
    X(mdr, logic) \
    X(mdr, capture) \
    X(mdr, ir) \
    X(mdr, tristate) \
    X(mdr, bridge) \
    X(mdr, stability) \
    X(registers, warmup) \
    X(registers, presence) \
    X(registers, logic) \
    X(registers, load) \
    X(registers, isolation) \
    X(registers, transfer) \
    X(registers, outreg) \
    X(registers, tristate) \
    X(registers, stability) \
    X(mar, warmup) \
    X(mar, presence) \
    X(mar, logic) \
    X(mar, hold) \
    X(mar, mux) \
    X(mar, decode) \
    X(mar, stability) \
    X(memory, power) \
    X(memory, warmup) \
    X(memory, presence) \
    X(memory, logic) \
    X(memory, romorder) \
    X(memory, romcrc) \
    X(memory, ramrw) \
    X(memory, select) \
    X(memory, window) \
    X(memory, idle) \
    X(memory, stability) \
    X(alu, power) \
    X(alu, warmup) \
    X(alu, presence) \
    X(alu, gates) \
    X(alu, shadow) \
    X(alu, ops) \
    X(alu, flags) \
    X(alu, reset) \
    X(alu, carry) \
    X(alu, stability) \
    X(io, power) \
    X(io, tristate) \
    X(io, isolation) \
    X(io, switches) \
    X(io, leds)

#define X_DECL(mod, name) void t_##mod##_##name(void);
TEST_TABLE(X_DECL)
#undef X_DECL

extern const testcase_t TESTS[];
extern const uint16_t TEST_COUNT;

#endif
