#ifndef REG_EXPECT_H
#define REG_EXPECT_H
/* Gate-logic model for the registers board (host-testable, no AVR
   headers — shared by hosttest/test_reg_expect.c and mod_registers.c). */
#include <stdbool.h>
#include <stdint.h>

enum {
    /* rig-driven inputs, bit i of the `in` word (wire levels:
       active-low strobes, bit set = idle high) */
    RGI_A_LOAD_N,       /* ~{REG_A_LOAD}    */
    RGI_B_LOAD_N,       /* ~{REG_B_LOAD}    */
    RGI_C_LOAD_N,       /* ~{REG_C_LOAD}    */
    RGI_OUT_LOAD_N,     /* ~{REG_OUT_LOAD}  */
    RGI_A_OUT_N,        /* ~{REG_A_OUT}     */
    RGI_B_OUT_N,        /* ~{REG_B_OUT}     */
    RGI_C_OUT_N,        /* ~{REG_C_OUT}     */
    RGI_CLK,            /* CLK              */
    RGI_COUNT
};

/* strobes idle high, CLK high */
#define REG_IDLE ((uint16_t)0x00FF)

enum {
    /* sampled probe outputs, bit i of reg_expect()'s return */
    RGO_A_LE,           /* U57.1  -> U31.11 ('373 LE, active HIGH) */
    RGO_B_LE,           /* U57.4  -> U32.11 */
    RGO_C_LE,           /* U57.10 -> U33.11 */
    RGO_OUT_LE,         /* U57.13 -> U35.11 */
    RGO_A_EN_N,         /* U5.3   -> U41.19 ('245 CE, active LOW)  */
    RGO_B_EN_N,         /* U5.6   -> U42.19 */
    RGO_C_EN_N,         /* U5.8   -> U43.19 */
    RGO_COUNT
};

/* Netlist-verified structure (registers_a_b.kicad_sch, 2026-07-20,
   post-U66-consolidation):
     U57 '02: ~{REG_x_LE} = NOR(~{REG_x_LOAD}, CLK), x = A,B,C,OUT —
              active HIGH despite the bar in the net name ('373 LE).
     U5 '08:  ~{x_EN} = AND(~{REG_x_LOAD}, ~{REG_x_OUT}), x = A,B,C —
              the register-file '245 CE: enabled LOW on load OR out.
              DIR rides ~{REG_x_OUT} directly: load = MDR->reg bus,
              out = reg bus->MDR. OUT register has no EN gate (U44 CE
              is ~{REG_OUT_LOAD} itself, DIR strapped MDR->D). */
static inline uint8_t reg_expect(uint16_t in) {
    uint8_t clk = (in >> RGI_CLK) & 1;
    uint8_t v = 0;
    if (!clk && !((in >> RGI_A_LOAD_N) & 1))   v |= 1u << RGO_A_LE;
    if (!clk && !((in >> RGI_B_LOAD_N) & 1))   v |= 1u << RGO_B_LE;
    if (!clk && !((in >> RGI_C_LOAD_N) & 1))   v |= 1u << RGO_C_LE;
    if (!clk && !((in >> RGI_OUT_LOAD_N) & 1)) v |= 1u << RGO_OUT_LE;
    if (((in >> RGI_A_LOAD_N) & 1) && ((in >> RGI_A_OUT_N) & 1))
        v |= 1u << RGO_A_EN_N;
    if (((in >> RGI_B_LOAD_N) & 1) && ((in >> RGI_B_OUT_N) & 1))
        v |= 1u << RGO_B_EN_N;
    if (((in >> RGI_C_LOAD_N) & 1) && ((in >> RGI_C_OUT_N) & 1))
        v |= 1u << RGO_C_EN_N;
    return v;
}

/* Two registers reading onto MDR at once — never encodable by the
   one-hot src decoder in the real machine; the rig must skip it. */
static inline bool reg_fight(uint16_t in) {
    uint8_t outs = (uint8_t)(!((in >> RGI_A_OUT_N) & 1)
                           + !((in >> RGI_B_OUT_N) & 1)
                           + !((in >> RGI_C_OUT_N) & 1));
    return outs >= 2;
}

#endif
