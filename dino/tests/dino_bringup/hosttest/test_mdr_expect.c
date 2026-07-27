/* Host-side unit test for mdr_expect.h — the MDR board's gate-logic
   model. Build with system cc.

   Assertions below are written from the NETLIST-verified gate structure
   (mdr.kicad_sch, 2026-07-20):
     U37 '04: WRITE_DIR = INV(~RAM_LOAD), MDR_OUT = INV(~MDR_OUT),
              READS_IDLE = INV(NAND(~ROM_OUT, ~RAM_OUT))  [via U39 gate1]
     U39 '00: BUS_DIR = NAND(~ALU_OUT, ~SW_OUT)
              LE_MDR  = NAND(~RAM_LOAD, READS_IDLE)
     U22 '02: LE_IR   = NOR(CLK, ~IR_LOAD)
              ~MDR_EN = NOR(SRC_ACTIVE, MDR_OUT)
   NOT from the model's own structure — the model must agree with the
   documented hardware, not with itself. */
#include <assert.h>
#include <stdio.h>
#include "../src/mdr_expect.h"

#define I(b) (1u << (b))
#define O(b) (1u << (b))

/* build an input word from asserted-strobe flags (strobes are active
   LOW: pass 1 to ASSERT the strobe) */
static uint16_t in_word(int mdr_out, int ir_load, int ram_load,
                        int rom_out, int ram_out, int alu_out, int sw_out,
                        int src_active, int clk) {
    uint16_t v = 0;
    if (!mdr_out)  v |= I(MDI_MDR_OUT_N);
    if (!ir_load)  v |= I(MDI_IR_LOAD_N);
    if (!ram_load) v |= I(MDI_RAM_LOAD_N);
    if (!rom_out)  v |= I(MDI_ROM_OUT_N);
    if (!ram_out)  v |= I(MDI_RAM_OUT_N);
    if (!alu_out)  v |= I(MDI_ALU_OUT_N);
    if (!sw_out)   v |= I(MDI_SW_OUT_N);
    if (src_active) v |= I(MDI_SRC_ACTIVE);
    if (clk)        v |= I(MDI_CLK);
    return v;
}

int main(void) {
    /* --- idle: strobes high, SRC_ACTIVE low, CLK high. Latches closed,
       bridge off, MDR->W direction at rest. */
    assert(MDR_IDLE == in_word(0,0,0,0,0,0,0,0,1));
    assert(mdr_expect(MDR_IDLE) == O(MDO_MDR_EN_N));

    /* --- WRITE_DIR = INV(~RAM_LOAD) */
    assert((mdr_expect(in_word(0,0,1,0,0,0,0,0,1)) & O(MDO_WRITE_DIR)) != 0);
    assert((mdr_expect(MDR_IDLE) & O(MDO_WRITE_DIR)) == 0);

    /* --- BUS_DIR = NAND(~ALU_OUT, ~SW_OUT): high (W->MDR) iff a W-side
       source is active */
    assert((mdr_expect(in_word(0,0,0,0,0,1,0,1,1)) & O(MDO_BUS_DIR)) != 0);
    assert((mdr_expect(in_word(0,0,0,0,0,0,1,1,1)) & O(MDO_BUS_DIR)) != 0);
    assert((mdr_expect(in_word(0,0,0,0,0,1,1,1,1)) & O(MDO_BUS_DIR)) != 0);
    assert((mdr_expect(MDR_IDLE) & O(MDO_BUS_DIR)) == 0);

    /* --- ~MDR_EN = NOR(SRC_ACTIVE, MDR_OUT): bridge enabled (low) iff
       any source is active OR the MDR replay strobe is down */
    assert((mdr_expect(in_word(0,0,0,0,0,0,0,1,1)) & O(MDO_MDR_EN_N)) == 0);
    assert((mdr_expect(in_word(1,0,0,0,0,0,0,0,1)) & O(MDO_MDR_EN_N)) == 0);
    assert((mdr_expect(MDR_IDLE) & O(MDO_MDR_EN_N)) != 0);

    /* --- LE_MDR = NAND(~RAM_LOAD, READS_IDLE): MDR latch transparent
       during a RAM write OR any memory read strobe; closed at idle */
    assert((mdr_expect(in_word(0,0,1,0,0,0,0,0,1)) & O(MDO_LE_MDR)) != 0);
    assert((mdr_expect(in_word(0,0,0,1,0,0,0,1,1)) & O(MDO_LE_MDR)) != 0);
    assert((mdr_expect(in_word(0,0,0,0,1,0,0,1,1)) & O(MDO_LE_MDR)) != 0);
    assert((mdr_expect(MDR_IDLE) & O(MDO_LE_MDR)) == 0);

    /* --- LE_IR = NOR(CLK, ~IR_LOAD): 4-row stamp truth */
    assert((mdr_expect(in_word(0,1,0,0,0,0,0,0,0)) & O(MDO_LE_IR)) != 0);
    assert((mdr_expect(in_word(0,1,0,0,0,0,0,0,1)) & O(MDO_LE_IR)) == 0);
    assert((mdr_expect(in_word(0,0,0,0,0,0,0,0,0)) & O(MDO_LE_IR)) == 0);
    assert((mdr_expect(in_word(0,0,0,0,0,0,0,0,1)) & O(MDO_LE_IR)) == 0);

    /* --- exhaustive invariants, all 512 input states */
    for (int in = 0; in < (1 << MDI_COUNT); in++) {
        uint8_t v = mdr_expect((uint16_t)in);
        int mdr_out_n = !!(in & I(MDI_MDR_OUT_N));
        int ir_load_n = !!(in & I(MDI_IR_LOAD_N));
        int ram_load_n = !!(in & I(MDI_RAM_LOAD_N));
        int rom_out_n = !!(in & I(MDI_ROM_OUT_N));
        int ram_out_n = !!(in & I(MDI_RAM_OUT_N));
        int alu_out_n = !!(in & I(MDI_ALU_OUT_N));
        int sw_out_n  = !!(in & I(MDI_SW_OUT_N));
        int src       = !!(in & I(MDI_SRC_ACTIVE));
        int clk       = !!(in & I(MDI_CLK));

        int mdr_out = !mdr_out_n;
        int reads_idle = rom_out_n && ram_out_n;

        assert(!!(v & O(MDO_WRITE_DIR)) == !ram_load_n);
        assert(!!(v & O(MDO_BUS_DIR)) == !(alu_out_n && sw_out_n));
        assert(!!(v & O(MDO_MDR_EN_N)) == !(src || mdr_out));
        assert(!!(v & O(MDO_LE_MDR)) == !(ram_load_n && reads_idle));
        assert(!!(v & O(MDO_LE_IR)) == (!clk && !ir_load_n));

        /* rogue-state fight: U25 driving MDR (bridge on, W->MDR) while
           U18 also drives MDR (replay strobe down). Real microcode
           never encodes it; the rig must skip these states. */
        assert(mdr_fight((uint16_t)in)
               == (mdr_out && !(alu_out_n && sw_out_n)));
    }

    assert(MDI_COUNT == 9);
    assert(MDO_COUNT == 5);

    printf("mdr_expect model: OK\n");
    return 0;
}
