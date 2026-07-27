/* Host-side unit test for mar_expect.h — the MAR board's gate model.
   Build with system cc.

   Assertions from the NETLIST-verified structure (mar.kicad_sch,
   2026-07-22):
     U60 '02 (all 4 gates, zero spares):
       LE_MAR_LO    = NOR(~{MAR_LO_LOAD}, CLK)   (pin 1)
       LE_MAR_HI    = NOR(~{MAR_HI_LOAD}, CLK)   (pin 4)
       ~{RAM_EN}    = INV(M15) — reads the BUS, so the decode is right
                      under either mux source     (pin 10)
       ~{PC_MAR_MUX}= INV(PC_MAR_MUX)             (pin 13)
   NOT from the model's own structure. */
#include <assert.h>
#include <stdio.h>
#include "../src/mar_expect.h"

#define I(b) (1u << (b))
#define O(b) (1u << (b))

int main(void) {
    /* idle: loads high, mux=0 (MAR drives M), CLK high, M15 low */
    assert(MAR_IDLE == (I(MRI_LO_LOAD_N) | I(MRI_HI_LOAD_N) | I(MRI_CLK)));
    assert(mar_expect(MAR_IDLE)
           == (O(MRO_PC_MAR_MUX_N) | O(MRO_RAM_EN_N)));

    /* LE stamps: assert ONLY when own /LOAD low AND CLK low */
    uint8_t lo_ld = MAR_IDLE & (uint8_t)~I(MRI_LO_LOAD_N);
    assert((mar_expect(lo_ld & (uint8_t)~I(MRI_CLK)) & O(MRO_LE_LO)) != 0);
    assert((mar_expect(lo_ld) & O(MRO_LE_LO)) == 0);              /* CLK hi */
    assert((mar_expect(MAR_IDLE & (uint8_t)~I(MRI_CLK)) & O(MRO_LE_LO)) == 0);

    /* mux inversion */
    assert((mar_expect(MAR_IDLE | I(MRI_MUX)) & O(MRO_PC_MAR_MUX_N)) == 0);
    assert((mar_expect(MAR_IDLE) & O(MRO_PC_MAR_MUX_N)) != 0);

    /* RAM decode: ~RAM_EN low exactly when M15 high */
    assert((mar_expect(MAR_IDLE | I(MRI_M15)) & O(MRO_RAM_EN_N)) == 0);
    assert((mar_expect(MAR_IDLE) & O(MRO_RAM_EN_N)) != 0);

    /* exhaustive, all 32 states */
    for (int in = 0; in < (1 << MRI_COUNT); in++) {
        uint8_t v = mar_expect((uint8_t)in);
        int lo_n = !!(in & I(MRI_LO_LOAD_N));
        int hi_n = !!(in & I(MRI_HI_LOAD_N));
        int mux  = !!(in & I(MRI_MUX));
        int clk  = !!(in & I(MRI_CLK));
        int m15  = !!(in & I(MRI_M15));
        assert(!!(v & O(MRO_LE_LO)) == (!clk && !lo_n));
        assert(!!(v & O(MRO_LE_HI)) == (!clk && !hi_n));
        assert(!!(v & O(MRO_PC_MAR_MUX_N)) == !mux);
        assert(!!(v & O(MRO_RAM_EN_N)) == !m15);
    }

    assert(MRI_COUNT == 5);
    assert(MRO_COUNT == 4);
    printf("mar_expect model: OK\n");
    return 0;
}
