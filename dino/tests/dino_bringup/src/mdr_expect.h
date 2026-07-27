#ifndef MDR_EXPECT_H
#define MDR_EXPECT_H
/* Gate-logic model for the MDR board (host-testable, no AVR headers —
   shared by hosttest/test_mdr_expect.c and mod_mdr.c). */
#include <stdbool.h>
#include <stdint.h>

enum {
    /* rig-driven inputs, bit i of the `in` word. Strobe bits carry the
       WIRE level (active-low strobes: bit set = idle high). */
    MDI_MDR_OUT_N,      /* ~{MDR_OUT}  */
    MDI_IR_LOAD_N,      /* ~{IR_LOAD}  */
    MDI_RAM_LOAD_N,     /* ~{RAM_LOAD} */
    MDI_ROM_OUT_N,      /* ~{ROM_OUT}  */
    MDI_RAM_OUT_N,      /* ~{RAM_OUT}  */
    MDI_ALU_OUT_N,      /* ~{ALU_OUT}  */
    MDI_SW_OUT_N,       /* ~{SW_OUT}   */
    MDI_SRC_ACTIVE,     /* SRC_ACTIVE  */
    MDI_CLK,            /* CLK         */
    MDI_COUNT
};

/* strobes idle high, SRC_ACTIVE low, CLK high */
#define MDR_IDLE ((uint16_t)0x007F | (uint16_t)(1u << MDI_CLK))

enum {
    /* sampled logic outputs, bit i of mdr_expect()'s return */
    MDO_WRITE_DIR,      /* contract OUT, U37 pin 4          */
    MDO_BUS_DIR,        /* probe, U39 pin 8 -> U25 pin 1    */
    MDO_MDR_EN_N,       /* probe, U22 pin 4 -> U25 pin 19   */
    MDO_LE_MDR,         /* probe, U39 pin 6 -> U18 pin 11   */
    MDO_LE_IR,          /* probe, U22 pin 1 -> U34 pin 11   */
    MDO_COUNT
};

/* Expected logic level of every sampled gate signal for a driven input
   state. Netlist-verified structure (mdr.kicad_sch, 2026-07-20):
     U37 '04: WRITE_DIR = INV(~RAM_LOAD), MDR_OUT = INV(~MDR_OUT),
              READS_IDLE = INV(U39 gate1) where gate1 = NAND(~ROM_OUT,
              ~RAM_OUT) — high when no memory read strobe is down.
     U39 '00: BUS_DIR = NAND(~ALU_OUT, ~SW_OUT)  (pin 8 -> U25.1)
              LE_MDR  = NAND(~RAM_LOAD, READS_IDLE)  (pin 6 -> U18.11)
     U22 '02: LE_IR   = NOR(CLK, ~IR_LOAD)  (pin 1 -> U34.11)
              ~MDR_EN = NOR(SRC_ACTIVE, MDR_OUT)  (pin 4 -> U25.19) */
static inline uint8_t mdr_expect(uint16_t in) {
    uint8_t mdr_out_n  = (in >> MDI_MDR_OUT_N) & 1;
    uint8_t ir_load_n  = (in >> MDI_IR_LOAD_N) & 1;
    uint8_t ram_load_n = (in >> MDI_RAM_LOAD_N) & 1;
    uint8_t rom_out_n  = (in >> MDI_ROM_OUT_N) & 1;
    uint8_t ram_out_n  = (in >> MDI_RAM_OUT_N) & 1;
    uint8_t alu_out_n  = (in >> MDI_ALU_OUT_N) & 1;
    uint8_t sw_out_n   = (in >> MDI_SW_OUT_N) & 1;
    uint8_t src        = (in >> MDI_SRC_ACTIVE) & 1;
    uint8_t clk        = (in >> MDI_CLK) & 1;

    uint8_t mdr_out    = !mdr_out_n;                 /* U37 gate 5->6  */
    uint8_t reads_idle = rom_out_n && ram_out_n;     /* U39 g1 + U37 g1 */

    uint8_t v = 0;
    if (!ram_load_n)              v |= 1u << MDO_WRITE_DIR;
    if (!(alu_out_n && sw_out_n)) v |= 1u << MDO_BUS_DIR;
    if (!(src || mdr_out))        v |= 1u << MDO_MDR_EN_N;
    if (!(ram_load_n && reads_idle)) v |= 1u << MDO_LE_MDR;
    if (!clk && !ir_load_n)       v |= 1u << MDO_LE_IR;
    return v;
}

/* Rogue state the tests must SKIP: U25 driving MDR (bridge enabled with
   BUS_DIR = W->MDR) while U18 also drives MDR (~MDR_OUT down). MDR_OUT
   forces the bridge on through ~MDR_EN, so the condition reduces to
   "replay strobe down AND a W-side source active". Real microcode never
   encodes it — driving it on the bench would fight U25 against U18. */
static inline bool mdr_fight(uint16_t in) {
    uint8_t v = mdr_expect(in);
    return !((in >> MDI_MDR_OUT_N) & 1) && ((v >> MDO_BUS_DIR) & 1);
}

#endif
