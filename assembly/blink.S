.syntax unified
.cpu cortex-m0plus
.thumb

.section .vectors, "a", %progbits
.word  0x20001000         @ initial SP
.word  _start + 1         @ reset handler (+1 for Thumb mode)

.section .text
.global _start
_start:
    LDR r0, =0x40014000      @ SIO base
    LDR r1, =0x02000000      @ 1 << 19, Bitmask for GPIO25

    STR r1, [r0, #0x08]      @ GPIO_OE = enable output for GPIO25

loop:
    STR r1, [r0, #0x1C]      @ GPIO_OUT_SET = high
    BL delay
    STR r1, [r0, #0x28]      @ GPIO_OUT_CLR = low
    BL delay
    B loop

delay:
    LDR r2, =0x1FF           @ Outer loop count
d1: LDR r3, =0xFF            @ Inner loop count
d2: SUBS r3, r3, #1
    BNE d2
    SUBS r2, r2, #1
    BNE d1
    BX lr
