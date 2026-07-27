#ifndef MAR_EXPECT_H
#define MAR_EXPECT_H
/* Gate-logic model for the MAR board (host-testable, no AVR headers —
   shared by hosttest/test_mar_expect.c and mod_mar.c). */
#include <stdbool.h>
#include <stdint.h>

enum {
    /* inputs, bit i of the `in` byte. M15 is the BUS level (latched
       MAR15 when mux=0, rig-driven when mux=1) — ~RAM_EN decodes the
       bus, not the latch. */
    MRI_LO_LOAD_N,      /* ~{MAR_LO_LOAD} */
    MRI_HI_LOAD_N,      /* ~{MAR_HI_LOAD} */
    MRI_MUX,            /* CW14=PC_MAR_MUX (PC=1, MAR=0) */
    MRI_CLK,            /* CLK */
    MRI_M15,            /* M15=ROM_EN bus level */
    MRI_COUNT
};

/* loads high, mux=0 (MAR drives M), CLK high, M15 low */
#define MAR_IDLE ((uint8_t)(1u << MRI_LO_LOAD_N | 1u << MRI_HI_LOAD_N \
                            | 1u << MRI_CLK))

enum {
    MRO_LE_LO,          /* probe, U60.1  -> U55.11 */
    MRO_LE_HI,          /* probe, U60.4  -> U58.11 */
    MRO_PC_MAR_MUX_N,   /* contract OUT, U60.13 -> PC sheet */
    MRO_RAM_EN_N,       /* contract OUT, U60.10 -> Memory sheet */
    MRO_COUNT
};

/* Netlist-verified structure (mar.kicad_sch, 2026-07-22): U60 '02,
   all four gates: LE_MAR_LO = NOR(~{MAR_LO_LOAD}, CLK), LE_MAR_HI =
   NOR(~{MAR_HI_LOAD}, CLK) — the house stamp; ~{RAM_EN} = INV(M15)
   off the BUS (pins 8,9 tied); ~{PC_MAR_MUX} = INV(PC_MAR_MUX)
   (pins 11,12 tied). */
static inline uint8_t mar_expect(uint8_t in) {
    uint8_t clk = (in >> MRI_CLK) & 1;
    uint8_t v = 0;
    if (!clk && !((in >> MRI_LO_LOAD_N) & 1)) v |= 1u << MRO_LE_LO;
    if (!clk && !((in >> MRI_HI_LOAD_N) & 1)) v |= 1u << MRO_LE_HI;
    if (!((in >> MRI_MUX) & 1))               v |= 1u << MRO_PC_MAR_MUX_N;
    if (!((in >> MRI_M15) & 1))               v |= 1u << MRO_RAM_EN_N;
    return v;
}

#endif
