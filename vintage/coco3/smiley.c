/*
 * smiley.c - Draw a smiley face on CoCo 3
 *
 * Uses 32x16 text/semigraphics mode (default BASIC screen).
 * Screen memory starts at 0x0400.
 *
 * Build: cmoc --coco -o smiley.bin smiley.c
 * Load:  LOADM"SMILEY" / EXEC
 */

#include <coco.h>

/* CoCo text screen base address (32x16) */
#define SCREEN_BASE 0x0400
#define COLS    32
#define ROWS    16

/* Semigraphics-4 block characters:
 * Bit layout: 1CCCDDDD
 *   C = color (3 bits), D = quadrant dots (4 bits)
 *   Quadrants: bit3=BL, bit2=BR, bit1=TL, bit0=TR
 */
#define SG4(color, tl, tr, bl, br) \
    (0x80 | ((color) << 4) | ((bl) << 3) | ((br) << 2) | ((tl) << 1) | (tr))

/* SG4 color codes (actual CoCo VDG color table) */
#define GREEN    0
#define YELLOW   1
#define BLUE     2
#define RED      3
#define BUFF     4
#define CYAN     5
#define MAGENTA  6
#define ORANGE   7

/*
 * Fast screen fill using 6309's TFM (block transfer) instruction.
 * TFM is a 6309-only opcode that fills/copies memory blocks
 * much faster than a 6809 loop.
 */
void fast_clear(unsigned int dest, byte val, unsigned int count)
{
    asm {
        ldx     :dest       ; X = destination address
        lda     :val        ; A = fill value
        sta     ,x          ; write first byte
        leay    1,x         ; Y = dest + 1
        ldw     :count      ; W = byte count for TFM
        decw                ; already wrote 1 byte
        tfm     x,y+        ; fill: X stays put, Y increments
    }
}

/* Plot a semigraphics character at text row/col */
void plot(byte row, byte col, byte ch)
{
    byte *screen = (byte *)SCREEN_BASE;
    screen[row * COLS + col] = ch;
}

/* Draw the smiley face */
void draw_smiley(void)
{
    byte r, c;

    /* Clear screen to spaces (fast, using 6309 TFM) */
    fast_clear(SCREEN_BASE, ' ', COLS * ROWS);

    /* --- Fill head with yellow first --- */
    for (r = 4; r <= 10; r++)
        for (c = 12; c <= 19; c++)
            plot(r, c, SG4(YELLOW, 1, 1, 1, 1));

    /* --- Head outline (yellow on black edges) --- */
    /* Top of head */
    for (c = 12; c <= 19; c++)
        plot(3, c, SG4(YELLOW, 0, 0, 1, 1));
    /* Bottom of head */
    for (c = 12; c <= 19; c++)
        plot(11, c, SG4(YELLOW, 1, 1, 0, 0));
    /* Left side */
    for (r = 4; r <= 10; r++)
        plot(r, 11, SG4(YELLOW, 0, 1, 0, 1));
    /* Right side */
    for (r = 4; r <= 10; r++)
        plot(r, 20, SG4(YELLOW, 1, 0, 1, 0));
    /* Corners */
    plot(3,  11, SG4(YELLOW, 0, 0, 0, 1));
    plot(3,  20, SG4(YELLOW, 0, 0, 1, 0));
    plot(11, 11, SG4(YELLOW, 0, 1, 0, 0));
    plot(11, 20, SG4(YELLOW, 1, 0, 0, 0));

    /* --- Eyes (blue dots on yellow face) --- */
    plot(9, 14, SG4(BLUE, 1, 1, 1, 1));
    plot(9, 17, SG4(BLUE, 1, 1, 1, 1));

    /* --- Mouth (red smile curve) --- */
    plot(5, 13, SG4(RED, 0, 0, 0, 1));
    plot(5, 14, SG4(RED, 0, 0, 1, 1));
    plot(6, 14, SG4(RED, 1, 0, 0, 0));
    plot(6, 15, SG4(RED, 1, 1, 0, 0));
    plot(6, 16, SG4(RED, 1, 1, 0, 0));
    plot(6, 17, SG4(RED, 0, 1, 0, 0));
    plot(5, 17, SG4(RED, 0, 0, 1, 1));
    plot(5, 18, SG4(RED, 0, 0, 1, 0));
}

int main(void)
{
    draw_smiley();

    /* Wait for keypress */
    asm {
wait_key:
        lda     $FF00       ; read PIA keyboard column
        cmpa    #$FF        ; any key pressed? (not all 1s)
        beq     wait_key    ; no, keep polling
    }

    /* Return to BASIC */
    return 0;
}
