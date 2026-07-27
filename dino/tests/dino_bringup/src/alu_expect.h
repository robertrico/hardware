#ifndef ALU_EXPECT_H
#define ALU_EXPECT_H
/* Arithmetic + gate model for the ALU board (host-testable, no AVR
   headers — shared by hosttest/test_alu_expect.c and mod_alu.c). */
#include <stdbool.h>
#include <stdint.h>

/* SA2:SA1:SA0 codes — identical to microcode_gen.py's SA table and to
   the 74F382 function select. */
enum {
    ALU_CLR = 0,        /* F = 0x00        */
    ALU_BSUB = 1,       /* F = B - A       */
    ALU_SUB = 2,        /* F = A - B       */
    ALU_ADD = 3,        /* F = A + B       */
    ALU_XOR = 4,
    ALU_OR = 5,
    ALU_AND = 6,
    ALU_SET = 7,        /* F = 0xFF        */
    ALU_OPS = 8
};

typedef struct {
    uint8_t f;          /* result byte on F0-7 (and on W when enabled) */
    bool c;             /* ALU_C  = U40 CN+4 (carry out; 1 = no borrow) */
    bool v;             /* ALU_V  = U40 OVR  (signed overflow)          */
    bool n;             /* FLAG_N = F7                                  */
    bool z;             /* Z      = all eight F bits low                */
    bool cv_defined;    /* the '382 only defines C/V for arithmetic     */
} alu_res_t;

/* ALU_CIN = NAND(SA1, SA0) — U53 gate 4 ANDs the two select bits, U50
   gate 4 inverts. Only ADD (011) and SET (111) carry 0; every other
   code carries 1, which is exactly what turns the '382's two subtract
   codes into true two's-complement A-B (not A-B-1). */
static inline uint8_t alu_cin(uint8_t op) {
    return (uint8_t)!(((op >> 1) & 1) && (op & 1));
}

/* One nibble-pair pass of the '382 function table, done 8 bits wide:
   the low chip's CN+4 ripples into the high chip's CN, so the pair
   behaves as a single 8-bit unit. */
static inline alu_res_t alu_eval(uint8_t op, uint8_t a, uint8_t b) {
    alu_res_t r;
    uint8_t x = 0, y = 0;
    bool arith = false;

    switch (op) {
    case ALU_BSUB: x = b; y = (uint8_t)~a; arith = true; break;
    case ALU_SUB:  x = a; y = (uint8_t)~b; arith = true; break;
    case ALU_ADD:  x = a; y = b;           arith = true; break;
    case ALU_XOR:  r.f = (uint8_t)(a ^ b); break;
    case ALU_OR:   r.f = (uint8_t)(a | b); break;
    case ALU_AND:  r.f = (uint8_t)(a & b); break;
    case ALU_SET:  r.f = 0xFF; break;
    default:       r.f = 0x00; break;      /* ALU_CLR */
    }

    if (arith) {
        uint8_t cin = alu_cin(op);
        uint16_t full = (uint16_t)x + (uint16_t)y + cin;
        uint8_t low7 = (uint8_t)(((x & 0x7F) + (y & 0x7F) + cin) >> 7);
        r.f = (uint8_t)full;
        r.c = (full >> 8) & 1;
        r.v = (bool)(r.c ^ low7);          /* carry-out XOR carry-into-MSB */
    } else {
        r.c = false;
        r.v = false;
    }
    r.cv_defined = arith;
    r.n = (r.f & 0x80) != 0;
    r.z = (r.f == 0);
    return r;
}

/* LE_TMP_A = NOR(~{REG_A_LOAD}, CLK), same for B — U50 gates 1 and 2.
   The shadow latches open only while the strobe AND the clock are low,
   the same two-edge stamp the register file and the IR use. */
static inline uint8_t alu_le(uint8_t load_n, uint8_t clk) {
    return (uint8_t)(!load_n && !clk);
}

#endif
