#ifndef CW_EXPECT_H
#define CW_EXPECT_H
/* Expected-output model for the control_word board (host-testable, no AVR
   headers — shared by hosttest/test_cw_expect.c and mod_control_word.c). */
#include <stdint.h>

enum {
    /* U30 '138 dst group (CW2:CW1:CW0), outputs O1..O7, active low */
    CWO_REG_A_LOAD_N,
    CWO_REG_B_LOAD_N,
    CWO_REG_C_LOAD_N,
    CWO_MAR_LO_LOAD_N,
    CWO_MAR_HI_LOAD_N,
    CWO_IR_LOAD_N,
    CWO_RAM_LOAD_N,
    /* U28 '138 src group (CW5:CW4:CW3): O0 = SRC_ACTIVE, O1..O7 active low */
    CWO_SRC_ACTIVE,
    CWO_ROM_OUT_N,
    CWO_RAM_OUT_N,
    CWO_REG_A_OUT_N,
    CWO_REG_B_OUT_N,
    CWO_REG_C_OUT_N,
    CWO_ALU_OUT_N,
    CWO_SW_OUT_N,
    /* U29 '138 (CW8:CW7:CW6), sampled contract outputs O1/O4/O6 plus
       rig-internal probes on the two U62-bound outputs O2/O3 */
    CWO_PC_CLEAR_N,
    CWO_MDR_OUT_N,
    CWO_REG_OUT_LOAD_N,
    CWO_PC_LOAD_JMP_N,   /* rig-internal probe, U29 pin 13 (O2) */
    CWO_COND_N,          /* rig-internal probe, U29 pin 12 (O3) */
    /* U62 '02 */
    CWO_PC_LOAD_N,
    CWO_COND_TAKEN,      /* rig-internal probe, U62 pin 1 */
    CWO_PC_LOAD_JMP,     /* rig-internal probe, U62 pin 4 */
    CWO_COUNT
};

/* Expected logic level of every sampled signal for a driven CW[8:0] +
   FLAG_Z. Bit i = level of signal i (enum order above). Netlist-verified
   structure (control_word.kicad_sch, 2026-07-17):
     U30/U28/U29 '138s: E1=E2=GND, E3=+5V — always enabled, O0 decodes
     code 000. U28.O0 (pin 15) is the SRC_ACTIVE contract net (bug-4
     bridge fix); U29 O0/O5/O7 and U30 O0 are NC.
     U62 '02: COND_TAKEN  = NOR(~{COND}, FLAG_Z)         (pin 1 <- 2,3)
              PC_LOAD_JMP = INV(~{PC_LOAD_JMP})          (pin 4 <- 5,6)
              ~{PC_LOAD}  = NOR(COND_TAKEN, PC_LOAD_JMP) (pin 10 <- 8,9) */
static inline uint32_t cw_expect(uint16_t cw, uint8_t flag_z) {
    uint8_t dst = cw & 7, src = (cw >> 3) & 7, jmp = (cw >> 6) & 7;
    uint32_t v = 0;
    for (uint8_t c = 1; c < 8; c++) {           /* '138 one-hot, active low */
        if (dst != c) v |= 1UL << (CWO_REG_A_LOAD_N + c - 1);
        if (src != c) v |= 1UL << (CWO_ROM_OUT_N + c - 1);
    }
    if (src != 0)  v |= 1UL << CWO_SRC_ACTIVE;  /* U28.O0: low on NONE only */
    if (jmp != 1)  v |= 1UL << CWO_PC_CLEAR_N;  /* U29.O1 */
    if (jmp != 2)  v |= 1UL << CWO_PC_LOAD_JMP_N;       /* U29.O2 probe */
    if (jmp != 3)  v |= 1UL << CWO_COND_N;              /* U29.O3 probe */
    if (jmp != 4)  v |= 1UL << CWO_MDR_OUT_N;   /* U29.O4 */
    if (jmp != 6)  v |= 1UL << CWO_REG_OUT_LOAD_N;      /* U29.O6 */
    uint8_t cond_taken  = (jmp == 3 && !flag_z);        /* U29.O3 -> U62.1 */
    uint8_t pc_load_jmp = (jmp == 2);                   /* U29.O2 -> U62.4 */
    if (cond_taken)  v |= 1UL << CWO_COND_TAKEN;
    if (pc_load_jmp) v |= 1UL << CWO_PC_LOAD_JMP;
    if (!cond_taken && !pc_load_jmp) v |= 1UL << CWO_PC_LOAD_N;
    return v;
}

#endif
