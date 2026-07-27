/* Host-side unit test for cw_expect.h — the control_word board's expected-
   output model. Build with system cc.

   Assertions below are written from the CONTROL WORD BIT MAP + U62 COND
   truth table in docs/notes/dino_session_state.md (netlist-verified
   2026-07-17), NOT from the model's own structure — the model must agree
   with the documented hardware, not with itself. */
#include <assert.h>
#include <stdio.h>
#include "../src/cw_expect.h"

#define B(i) (1UL << (i))

int main(void) {
    /* --- NONE state (all three codes 000): every active-low output rests
       HIGH; SRC_ACTIVE is U28.O0, the src NONE decode, so it rests LOW;
       both U62 probes rest LOW; ~PC_LOAD rests HIGH. Z is a don't-care. */
    const uint32_t none = (B(CWO_COUNT) - 1)
        & ~B(CWO_SRC_ACTIVE) & ~B(CWO_COND_TAKEN) & ~B(CWO_PC_LOAD_JMP);
    assert(cw_expect(0x000, 0) == none);
    assert(cw_expect(0x000, 1) == none);

    /* --- U30 dst walk (CW[2:0]): codes 001..111 pull exactly the named
       output low; nothing else moves (src stays NONE -> SRC_ACTIVE low). */
    static const int dst_out[8] = {
        -1, CWO_REG_A_LOAD_N, CWO_REG_B_LOAD_N, CWO_REG_C_LOAD_N,
        CWO_MAR_LO_LOAD_N, CWO_MAR_HI_LOAD_N, CWO_IR_LOAD_N, CWO_RAM_LOAD_N,
    };
    for (int c = 1; c < 8; c++)
        assert(cw_expect((uint16_t)c, 1) == (none & ~B(dst_out[c])));

    /* --- U28 src walk (CW[5:3]): named output low AND SRC_ACTIVE rises
       (a source is active) — the bug-4 bridge fix contract signal. */
    static const int src_out[8] = {
        -1, CWO_ROM_OUT_N, CWO_RAM_OUT_N, CWO_REG_A_OUT_N,
        CWO_REG_B_OUT_N, CWO_REG_C_OUT_N, CWO_ALU_OUT_N, CWO_SW_OUT_N,
    };
    for (int c = 1; c < 8; c++)
        assert(cw_expect((uint16_t)(c << 3), 1)
               == ((none | B(CWO_SRC_ACTIVE)) & ~B(src_out[c])));

    /* --- U29 walk (CW[8:6]) with Z=1 (JNZ-not-taken side):
       001 /PC_CLEAR   010 /PC_LOAD_JMP (probed: decoder out low, U62
       INV out high, ~PC_LOAD low)   011 /COND (probed: decoder out low;
       Z=1 -> COND_TAKEN stays low, ~PC_LOAD stays high)
       100 /MDR_OUT    101 NC    110 /REG_OUT_LOAD    111 NC */
    assert(cw_expect(1 << 6, 1) == (none & ~B(CWO_PC_CLEAR_N)));
    assert(cw_expect(2 << 6, 1)
           == ((none | B(CWO_PC_LOAD_JMP))
               & ~B(CWO_PC_LOAD_JMP_N) & ~B(CWO_PC_LOAD_N)));
    assert(cw_expect(3 << 6, 1) == (none & ~B(CWO_COND_N)));
    assert(cw_expect(4 << 6, 1) == (none & ~B(CWO_MDR_OUT_N)));
    assert(cw_expect(5 << 6, 1) == none);                    /* NC code */
    assert(cw_expect(6 << 6, 1) == (none & ~B(CWO_REG_OUT_LOAD_N)));
    assert(cw_expect(7 << 6, 1) == none);                    /* NC code */

    /* --- U62 COND truth table (the 4 documented rows):
       (/COND, Z=0) taken; (/COND, Z=1) not; (PC_LOAD_JMP code) load
       regardless of Z; (idle) no load. */
    uint32_t v;
    v = cw_expect(3 << 6, 0);                       /* JNZ taken */
    assert((v & B(CWO_COND_TAKEN)) != 0);
    assert((v & B(CWO_PC_LOAD_JMP)) == 0);
    assert((v & B(CWO_PC_LOAD_N)) == 0);            /* load asserted */
    v = cw_expect(3 << 6, 1);                       /* JNZ not taken */
    assert((v & B(CWO_COND_TAKEN)) == 0);
    assert((v & B(CWO_PC_LOAD_N)) != 0);
    v = cw_expect(2 << 6, 0);                       /* JMP, Z=0 */
    assert((v & B(CWO_PC_LOAD_JMP)) != 0);
    assert((v & B(CWO_PC_LOAD_N)) == 0);
    v = cw_expect(2 << 6, 1);                       /* JMP, Z=1 */
    assert((v & B(CWO_PC_LOAD_JMP)) != 0);
    assert((v & B(CWO_PC_LOAD_N)) == 0);
    v = cw_expect(0, 0);                            /* idle */
    assert((v & B(CWO_PC_LOAD_N)) != 0);

    /* --- exhaustive invariants, all 512 codes x both Z: */
    for (int cw = 0; cw < 512; cw++) {
        for (int z = 0; z < 2; z++) {
            v = cw_expect((uint16_t)cw, (uint8_t)z);
            int dst = cw & 7, src = (cw >> 3) & 7, jmp = (cw >> 6) & 7;

            /* one-hot per '138: at most one sampled output low per group */
            int lo = 0;
            for (int i = CWO_REG_A_LOAD_N; i <= CWO_RAM_LOAD_N; i++)
                lo += !(v & B(i));
            assert(lo == (dst != 0));
            lo = 0;
            for (int i = CWO_ROM_OUT_N; i <= CWO_SW_OUT_N; i++)
                lo += !(v & B(i));
            assert(lo == (src >= 1 && src <= 7));

            /* SRC_ACTIVE == "some source selected" (U28.O0 inverted-sense) */
            assert(!!(v & B(CWO_SRC_ACTIVE)) == (src != 0));

            /* ~PC_LOAD low exactly on JMP code or taken-JNZ code */
            int load = (jmp == 2) || (jmp == 3 && z == 0);
            assert(!!(v & B(CWO_PC_LOAD_N)) == !load);
            assert(!!(v & B(CWO_PC_LOAD_JMP)) == (jmp == 2));
            assert(!!(v & B(CWO_COND_TAKEN)) == (jmp == 3 && z == 0));

            /* U29 probe outputs: plain decoder one-hots */
            assert(!!(v & B(CWO_PC_LOAD_JMP_N)) == (jmp != 2));
            assert(!!(v & B(CWO_COND_N)) == (jmp != 3));

            /* U62 gates must agree with their probed inputs:
               gate1 NOR(~COND, Z), gate2 INV(~PC_LOAD_JMP) */
            assert(!!(v & B(CWO_COND_TAKEN))
                   == (!(v & B(CWO_COND_N)) && !z));
            assert(!!(v & B(CWO_PC_LOAD_JMP)) == !(v & B(CWO_PC_LOAD_JMP_N)));

            /* group independence: a group's bits depend only on its own
               code (compare against the code-isolated state) */
            const uint32_t dst_mask =
                B(CWO_RAM_LOAD_N + 1) - B(CWO_REG_A_LOAD_N);
            const uint32_t src_mask =
                B(CWO_SW_OUT_N + 1) - B(CWO_SRC_ACTIVE);
            assert(((v ^ cw_expect((uint16_t)dst, (uint8_t)z))
                    & dst_mask) == 0);
            assert(((v ^ cw_expect((uint16_t)(src << 3), (uint8_t)z))
                    & src_mask) == 0);
        }
    }

    /* --- 19 contract signals + 4 rig probes */
    assert(CWO_COUNT == 23);

    printf("cw_expect model: OK\n");
    return 0;
}
