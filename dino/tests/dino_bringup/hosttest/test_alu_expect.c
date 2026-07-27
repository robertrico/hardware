/* Host-side unit test for alu_expect.h — the ALU board's arithmetic and
   gate model. Build with system cc.

   Assertions come from the 74F382 function table + the NETLIST-verified
   wiring (alu.kicad_sch, 2026-07-24), NOT from the model's structure:
     U38/U40 '382 pair, S2:S1:S0 = SA2:SA1:SA0, CRY ripples low->high
       000 CLEAR   001 B-A   010 A-B   011 A+B
       100 A^B     101 A|B   110 A&B   111 PRESET
     ALU_CIN = NAND(SA1, SA0)  [U53 g4 -> U50 g4] — so ADD and SET carry
       0 and every other code carries 1: that is what makes the two
       subtract codes true two's-complement (A-B, not A-B-1).
     FLAG_C = ALU_C (U40 CN+4), FLAG_V = ALU_V (U40 OVR),
     FLAG_N = F7,  FLAG_Z = Z = AND(NOR(F0,F1)..NOR(F6,F7)).
     LE_TMP_x = NOR(~{REG_x_LOAD}, CLK)  [U50 g1/g2] — the house stamp.

   C and V are only architecturally meaningful for the three arithmetic
   codes; the '382 leaves them undefined for the logic codes, so the
   model reports cv_defined and the bench test asserts accordingly. */
#include <assert.h>
#include <stdio.h>
#include "../src/alu_expect.h"

int main(void) {
    /* ---- op encodings match the microcode SA table ---- */
    assert(ALU_CLR == 0 && ALU_BSUB == 1 && ALU_SUB == 2 && ALU_ADD == 3);
    assert(ALU_XOR == 4 && ALU_OR == 5 && ALU_AND == 6 && ALU_SET == 7);
    assert(ALU_OPS == 8);

    /* ---- ALU_CIN = NAND(SA1, SA0): only ADD and SET carry 0 ---- */
    assert(alu_cin(ALU_ADD) == 0);
    assert(alu_cin(ALU_SET) == 0);
    assert(alu_cin(ALU_SUB) == 1);
    assert(alu_cin(ALU_BSUB) == 1);
    assert(alu_cin(ALU_CLR) == 1);
    assert(alu_cin(ALU_XOR) == 1);
    assert(alu_cin(ALU_OR) == 1);
    assert(alu_cin(ALU_AND) == 1);

    /* ---- the milestone itself: 5 + 3 = 8 ---- */
    alu_res_t r = alu_eval(ALU_ADD, 5, 3);
    assert(r.f == 8 && !r.c && !r.v && !r.n && !r.z && r.cv_defined);

    /* ---- ADD edges ---- */
    r = alu_eval(ALU_ADD, 0xFF, 0x01);
    assert(r.f == 0x00 && r.c && r.z && !r.n);       /* carry + zero      */
    r = alu_eval(ALU_ADD, 0x7F, 0x01);
    assert(r.f == 0x80 && r.v && r.n && !r.c);       /* signed overflow   */
    r = alu_eval(ALU_ADD, 0x80, 0x80);
    assert(r.f == 0x00 && r.c && r.v && r.z);        /* -128 + -128       */
    r = alu_eval(ALU_ADD, 0x00, 0x00);
    assert(r.f == 0x00 && !r.c && !r.v && r.z);

    /* ---- SUB = A - B. The CIN rule is what makes 5-3 equal 2, not 1;
       C is the '382's carry, so C=1 means NO borrow. ---- */
    r = alu_eval(ALU_SUB, 5, 3);
    assert(r.f == 2 && r.c && !r.v && !r.n && !r.z);
    r = alu_eval(ALU_SUB, 3, 5);
    assert(r.f == 0xFE && !r.c && r.n);              /* borrow            */
    r = alu_eval(ALU_SUB, 7, 7);
    assert(r.f == 0x00 && r.z && r.c);               /* zero, no borrow   */
    r = alu_eval(ALU_SUB, 0x80, 0x01);
    assert(r.f == 0x7F && r.v);                      /* signed overflow   */

    /* ---- BSUB = B - A (the operands the other way round) ---- */
    r = alu_eval(ALU_BSUB, 3, 5);
    assert(r.f == 2 && r.c && !r.z);
    r = alu_eval(ALU_BSUB, 5, 3);
    assert(r.f == 0xFE && !r.c && r.n);

    /* ---- logic codes: F, N, Z defined; C and V are not ---- */
    r = alu_eval(ALU_XOR, 0xAA, 0x55);
    assert(r.f == 0xFF && r.n && !r.z && !r.cv_defined);
    r = alu_eval(ALU_XOR, 0xC3, 0xC3);
    assert(r.f == 0x00 && r.z);
    r = alu_eval(ALU_OR, 0xA0, 0x0A);
    assert(r.f == 0xAA && !r.cv_defined);
    r = alu_eval(ALU_AND, 0xAA, 0x0F);
    assert(r.f == 0x0A);
    r = alu_eval(ALU_CLR, 0xFF, 0xFF);
    assert(r.f == 0x00 && r.z && !r.n && !r.cv_defined);
    r = alu_eval(ALU_SET, 0x00, 0x00);
    assert(r.f == 0xFF && r.n && !r.z && !r.cv_defined);

    /* ---- exhaustive invariants over every op and a wide operand grid ---- */
    for (int op = 0; op < ALU_OPS; op++) {
        for (int a = 0; a < 256; a += 5) {
            for (int b = 0; b < 256; b += 7) {
                r = alu_eval((uint8_t)op, (uint8_t)a, (uint8_t)b);
                /* N and Z are pure functions of F, always */
                assert(r.n == ((r.f & 0x80) != 0));
                assert(r.z == (r.f == 0));
                /* C/V defined exactly for the arithmetic codes */
                assert(r.cv_defined ==
                       (op == ALU_ADD || op == ALU_SUB || op == ALU_BSUB));
                /* the logic codes are their C operators */
                if (op == ALU_XOR) assert(r.f == ((a ^ b) & 0xFF));
                if (op == ALU_OR)  assert(r.f == ((a | b) & 0xFF));
                if (op == ALU_AND) assert(r.f == ((a & b) & 0xFF));
                if (op == ALU_CLR) assert(r.f == 0x00);
                if (op == ALU_SET) assert(r.f == 0xFF);
                /* arithmetic agrees with plain C arithmetic, and C is the
                   true 9th bit of the operation the '382 performs */
                if (op == ALU_ADD) {
                    assert(r.f == (uint8_t)(a + b));
                    assert(r.c == (a + b > 0xFF));
                }
                if (op == ALU_SUB) {
                    assert(r.f == (uint8_t)(a - b));
                    assert(r.c == (a >= b));        /* carry = no borrow */
                }
                if (op == ALU_BSUB) {
                    assert(r.f == (uint8_t)(b - a));
                    assert(r.c == (b >= a));
                }
            }
        }
    }

    /* ---- signed-overflow definition, checked independently of the model:
       V is set exactly when both operands share a sign and the result
       does not (for the effective addition the '382 performs) ---- */
    for (int a = 0; a < 256; a++) {
        for (int b = 0; b < 256; b += 3) {
            r = alu_eval(ALU_ADD, (uint8_t)a, (uint8_t)b);
            int sa = a & 0x80, sb = b & 0x80, sf = r.f & 0x80;
            assert(r.v == ((sa == sb) && (sf != sa)));
            r = alu_eval(ALU_SUB, (uint8_t)a, (uint8_t)b);
            int nb = (~b) & 0xFF;
            sa = a & 0x80; sb = nb & 0x80; sf = r.f & 0x80;
            assert(r.v == ((sa == sb) && (sf != sa)));
        }
    }

    /* ---- LE_TMP_x = NOR(~{REG_x_LOAD}, CLK): asserts only with the
       strobe low AND the clock low (the house stamp) ---- */
    assert(alu_le(0, 0) == 1);      /* strobe asserted, CLK low  */
    assert(alu_le(0, 1) == 0);      /* CLK high blocks           */
    assert(alu_le(1, 0) == 0);      /* no strobe                 */
    assert(alu_le(1, 1) == 0);

    printf("alu_expect model: OK\n");
    return 0;
}
