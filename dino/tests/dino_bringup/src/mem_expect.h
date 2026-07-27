#ifndef MEM_EXPECT_H
#define MEM_EXPECT_H
/* Gate-logic model for the memory board (host-testable, no AVR headers —
   shared by hosttest/test_mem_expect.c and mod_memory.c). */
#include <stdbool.h>
#include <stdint.h>

enum {
    /* rig-driven inputs, bit i of the `in` byte (wire levels: active-low
       strobes carry 1 when idle) */
    MEI_WRITE_DIR,      /* WRITE_DIR    (from the MDR sheet) */
    MEI_CLK_N,          /* ~{CLK}       (from root)          */
    MEI_RAM_OUT_N,      /* ~{RAM_OUT}   (control word)       */
    MEI_ROM_OUT_N,      /* ~{ROM_OUT}   (control word)       */
    MEI_ROM_EN,         /* M15=ROM_EN   (ROM ~CE: 0 selects) */
    MEI_RAM_EN_N,       /* ~{RAM_EN}    (RAM ~CE: 0 selects) */
    MEI_COUNT
};

/* strobes idle, WRITE_DIR low, ~CLK low (CLK high), both chips deselected */
#define MEM_IDLE ((uint8_t)((1u << MEI_RAM_OUT_N) | (1u << MEI_ROM_OUT_N) \
                            | (1u << MEI_ROM_EN) | (1u << MEI_RAM_EN_N)))

enum {
    /* sampled probe outputs, bit i of mem_expect()'s return — all four
       are U51 gate outputs, so a FAIL names the lying gate */
    MEO_WRITE_DIR_N,    /* U51.3  -> U21.1  ('245 DIR)  */
    MEO_RAM_WRITE_EN_N, /* U51.6  -> U26.27 (RAM ~WE)   */
    MEO_RAM_MDR_DIS,    /* U51.8  -> U51.12/13 (internal) */
    MEO_RAM_MDR_EN_N,   /* U51.11 -> U21.19 ('245 CE)   */
    MEO_COUNT
};

/* Netlist-verified structure (memory.kicad_sch, 2026-07-23):
     U51 '00, all four gates:
       ~{WRITE_DIR}    = INV(WRITE_DIR)                   (1,2 -> 3)
       ~{RAM_WRITE_EN} = NAND(WRITE_DIR, ~{CLK})          (4,5 -> 6)
       RAM_MDR_DIS     = NAND(~{RAM_OUT}, ~{WRITE_DIR})   (9,10 -> 8)
       ~{RAM_MDR_EN}   = INV(RAM_MDR_DIS)                 (12,13 -> 11)
     giving U21 CE = AND(~{RAM_OUT}, ~{WRITE_DIR}) — schematic bug 2's
     fix in copper (the buffer opens for a RAM read or a RAM write, NOT
     merely because MAR parked on a RAM address). The write window is a
     GATE, not the old '121 one-shot: ~WE asserts only while WRITE_DIR
     is high AND ~CLK is high. */
static inline uint8_t mem_expect(uint8_t in) {
    uint8_t wdir  = (in >> MEI_WRITE_DIR) & 1;
    uint8_t clk_n = (in >> MEI_CLK_N) & 1;
    uint8_t ro_n  = (in >> MEI_RAM_OUT_N) & 1;
    uint8_t v = 0;
    if (!wdir)                v |= 1u << MEO_WRITE_DIR_N;
    if (!(wdir && clk_n))     v |= 1u << MEO_RAM_WRITE_EN_N;
    if (!(ro_n && !wdir))     v |= 1u << MEO_RAM_MDR_DIS;
    if (ro_n && !wdir)        v |= 1u << MEO_RAM_MDR_EN_N;
    return v;
}

/* True when a board buffer drives MDR — the rig must not drive it then.
   U19's DIR is strapped A->B, so it pushes the ROM's I/O pins onto MDR
   whenever ~{ROM_OUT} is low (even with the ROM chip deselected, when
   those pins are floating). U21 reaches MDR only while enabled AND
   pointing RAM->MDR. */
static inline bool mem_mdr_driven(uint8_t in) {
    uint8_t v = mem_expect(in);
    bool rom_drives = !((in >> MEI_ROM_OUT_N) & 1);
    bool ram_drives = !((v >> MEO_RAM_MDR_EN_N) & 1)
                      && !((in >> MEI_WRITE_DIR) & 1);
    return rom_drives || ram_drives;
}

/* Driver-vs-driver states the rig must never provoke; the real machine's
   one-hot source decode and its src!=dst builder assert make them
   unencodable:
     (a) ROM and RAM both onto MDR,
     (b) U21 pushing MDR->RAM while the selected RAM drives its own DQ. */
static inline bool mem_fight(uint8_t in) {
    uint8_t v = mem_expect(in);
    bool rom_drives = !((in >> MEI_ROM_OUT_N) & 1);
    bool wdir       = (in >> MEI_WRITE_DIR) & 1;
    bool ram_drives = !((v >> MEO_RAM_MDR_EN_N) & 1) && !wdir;
    bool dq_fight   = wdir && !((in >> MEI_RAM_OUT_N) & 1)
                      && !((in >> MEI_RAM_EN_N) & 1);
    return (rom_drives && ram_drives) || dq_fight;
}

#endif
