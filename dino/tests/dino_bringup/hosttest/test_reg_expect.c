/* Host-side unit test for reg_expect.h — the registers board's gate
   model. Build with system cc.

   Assertions from the NETLIST-verified structure (registers_a_b, 2026-07-20):
     U57 '02 (all 4 gates, post-U66-consolidation):
       ~{REG_x_LE}  = NOR(~{REG_x_LOAD}, CLK)   x = A,B,C,OUT
       (active HIGH despite the bar in the net name — the '373 LE pin)
     U5 '08:
       ~{x_EN} = AND(~{REG_x_LOAD}, ~{REG_x_OUT})   x = A,B,C
       ('245 CE: enabled LOW when load OR out is asserted)
   NOT from the model's own structure. */
#include <assert.h>
#include <stdio.h>
#include "../src/reg_expect.h"

#define I(b) (1u << (b))
#define O(b) (1u << (b))

int main(void) {
    /* idle: strobes high, CLK high — latches closed, '245s disabled */
    assert(REG_IDLE == 0x00FF);
    assert(reg_expect(REG_IDLE)
           == (O(RGO_A_EN_N) | O(RGO_B_EN_N) | O(RGO_C_EN_N)));

    /* LE stamp truth (A row; all four gates share the shape):
       asserts ONLY when /LOAD low AND CLK low */
    uint16_t a_ld = REG_IDLE & (uint16_t)~I(RGI_A_LOAD_N);
    assert((reg_expect(a_ld & (uint16_t)~I(RGI_CLK)) & O(RGO_A_LE)) != 0);
    assert((reg_expect(a_ld) & O(RGO_A_LE)) == 0);                /* CLK hi */
    assert((reg_expect(REG_IDLE & (uint16_t)~I(RGI_CLK)) & O(RGO_A_LE)) == 0);
    assert((reg_expect(REG_IDLE) & O(RGO_A_LE)) == 0);

    /* EN truth (A row): '245 on (low) for load OR out, off (high) idle */
    assert((reg_expect(a_ld) & O(RGO_A_EN_N)) == 0);
    assert((reg_expect(REG_IDLE & (uint16_t)~I(RGI_A_OUT_N)) & O(RGO_A_EN_N)) == 0);
    assert((reg_expect(REG_IDLE) & O(RGO_A_EN_N)) != 0);

    /* exhaustive invariants, all 256 states */
    for (int in = 0; in < (1 << RGI_COUNT); in++) {
        uint8_t v = reg_expect((uint16_t)in);
        int clk = !!(in & I(RGI_CLK));
        int ld[4] = {!!(in & I(RGI_A_LOAD_N)), !!(in & I(RGI_B_LOAD_N)),
                     !!(in & I(RGI_C_LOAD_N)), !!(in & I(RGI_OUT_LOAD_N))};
        int ot[3] = {!!(in & I(RGI_A_OUT_N)), !!(in & I(RGI_B_OUT_N)),
                     !!(in & I(RGI_C_OUT_N))};
        static const int le[4] = {RGO_A_LE, RGO_B_LE, RGO_C_LE, RGO_OUT_LE};
        static const int en[3] = {RGO_A_EN_N, RGO_B_EN_N, RGO_C_EN_N};
        for (int r = 0; r < 4; r++)
            assert(!!(v & O(le[r])) == (!clk && !ld[r]));
        for (int r = 0; r < 3; r++)
            assert(!!(v & O(en[r])) == (ld[r] && ot[r]));

        /* fight: two registers reading onto MDR at once — the rig must
           never drive it, and the sweep must skip it */
        int outs = !ot[0] + !ot[1] + !ot[2];
        assert(reg_fight((uint16_t)in) == (outs >= 2));
    }

    assert(RGI_COUNT == 8);
    assert(RGO_COUNT == 7);
    printf("reg_expect model: OK\n");
    return 0;
}
