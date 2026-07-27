/* Host-side unit test for mem_expect.h — the memory board's gate model.
   Build with system cc.

   Assertions from the NETLIST-verified structure (memory.kicad_sch,
   2026-07-23):
     U51 '00 (all four gates):
       ~{WRITE_DIR}    = INV(WRITE_DIR)                   (1,2 -> 3)
       ~{RAM_WRITE_EN} = NAND(WRITE_DIR, ~{CLK})          (4,5 -> 6)
       RAM_MDR_DIS     = NAND(~{RAM_OUT}, ~{WRITE_DIR})   (9,10 -> 8)
       ~{RAM_MDR_EN}   = INV(RAM_MDR_DIS)                 (12,13 -> 11)
     i.e. U21 CE = AND(~{RAM_OUT}, ~{WRITE_DIR}) — SCHEMATIC BUG 2's fix
     in copper: the RAM<->MDR buffer opens only for a RAM read or a RAM
     write, never merely because MAR parked on a RAM address.
   NOT from the model's own structure. */
#include <assert.h>
#include <stdio.h>
#include "../src/mem_expect.h"

#define I(b) (1u << (b))
#define O(b) (1u << (b))

int main(void) {
    /* idle: no strobes, WRITE_DIR low, CLK high (~CLK low) */
    assert(MEM_IDLE == (I(MEI_RAM_OUT_N) | I(MEI_ROM_OUT_N)
                        | I(MEI_ROM_EN) | I(MEI_RAM_EN_N)));
    uint8_t idle = mem_expect(MEM_IDLE);
    assert((idle & O(MEO_WRITE_DIR_N)) != 0);      /* DIR: RAM -> MDR   */
    assert((idle & O(MEO_RAM_WRITE_EN_N)) != 0);   /* no write          */
    assert((idle & O(MEO_RAM_MDR_EN_N)) != 0);     /* U21 OFF <- the fix */

    /* ~{WRITE_DIR} = INV(WRITE_DIR) */
    assert((mem_expect(MEM_IDLE | I(MEI_WRITE_DIR)) & O(MEO_WRITE_DIR_N)) == 0);

    /* ~{RAM_WRITE_EN} = NAND(WRITE_DIR, ~{CLK}) — the write WINDOW.
       Retires the '121 one-shot: the pulse is a gate, not an RC. */
    assert((mem_expect(MEM_IDLE | I(MEI_WRITE_DIR) | I(MEI_CLK_N))
            & O(MEO_RAM_WRITE_EN_N)) == 0);                 /* in window */
    assert((mem_expect(MEM_IDLE | I(MEI_WRITE_DIR))
            & O(MEO_RAM_WRITE_EN_N)) != 0);                 /* ~CLK low  */
    assert((mem_expect(MEM_IDLE | I(MEI_CLK_N))
            & O(MEO_RAM_WRITE_EN_N)) != 0);                 /* no write  */

    /* U21 CE opens for a RAM read ... */
    assert((mem_expect(MEM_IDLE & (uint8_t)~I(MEI_RAM_OUT_N))
            & O(MEO_RAM_MDR_EN_N)) == 0);
    /* ... and for a RAM write ... */
    assert((mem_expect(MEM_IDLE | I(MEI_WRITE_DIR))
            & O(MEO_RAM_MDR_EN_N)) == 0);
    /* ... and for nothing else (the bug-2 condition: MAR parked on a RAM
       address with no RAM op in flight must NOT open the buffer) */
    assert((mem_expect(MEM_IDLE & (uint8_t)~I(MEI_RAM_EN_N))
            & O(MEO_RAM_MDR_EN_N)) != 0);

    /* exhaustive invariants, all 64 states */
    for (int in = 0; in < (1 << MEI_COUNT); in++) {
        uint8_t v = mem_expect((uint8_t)in);
        int wdir  = !!(in & I(MEI_WRITE_DIR));
        int clk_n = !!(in & I(MEI_CLK_N));
        int ro_n  = !!(in & I(MEI_RAM_OUT_N));
        int oo_n  = !!(in & I(MEI_ROM_OUT_N));
        int ren_n = !!(in & I(MEI_RAM_EN_N));

        assert(!!(v & O(MEO_WRITE_DIR_N)) == !wdir);
        assert(!!(v & O(MEO_RAM_WRITE_EN_N)) == !(wdir && clk_n));
        assert(!!(v & O(MEO_RAM_MDR_DIS)) == !(ro_n && !wdir));
        assert(!!(v & O(MEO_RAM_MDR_EN_N)) == (ro_n && !wdir));

        /* who drives MDR: U19 whenever ~ROM_OUT is low (DIR strapped
           A->B); U21 only when enabled AND pointing RAM->MDR */
        int rom_drives = !oo_n;
        int ram_drives = !(v & O(MEO_RAM_MDR_EN_N)) && !wdir;
        assert(mem_mdr_driven((uint8_t)in) == (rom_drives || ram_drives));

        /* fights the rig must never provoke: both buffers onto MDR, or
           U21 pushing MDR->RAM while the RAM itself drives its DQ */
        int dq_fight = wdir && !ro_n && !ren_n;
        assert(mem_fight((uint8_t)in)
               == ((rom_drives && ram_drives) || dq_fight));
    }

    assert(MEI_COUNT == 6);
    assert(MEO_COUNT == 4);
    printf("mem_expect model: OK\n");
    return 0;
}
