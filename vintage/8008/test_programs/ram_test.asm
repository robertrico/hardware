; Intel 8008 Comprehensive RAM Test
;
; Purpose:
;   1. Read a string from ROM
;   2. Write it to RAM
;   3. Read it back from RAM
;   4. Verify the first character matches
;   5. Store verification data in registers before halt
;
; Memory Map:
;   ROM: 0x0000-0x07FF
;   RAM: 0x0800-0x0BFF
;
; Test string at ROM 0x00C8: "TEST"
; Write to RAM at 0x0800
;
; Final Register Values (for verification):
;   A (reg 0): First char read back from RAM (should be 'T' = 0x54)
;   B (reg 1): Second char read back from RAM (should be 'E' = 0x45)
;   C (reg 2): Number of bytes written (should be 0x04)
;   H (reg 5): High byte of RAM address (should be 0x08)
;   L (reg 6): Low byte of RAM address (should be 0x04 - end position)
;

.8008

; Start at address 0x0000 to execute from reset
.org 0x0000
        jmp MAIN            ; Jump to main program

; Test string data at ROM location 200 (0xC8)
.org 0x00C8
TEST_STRING: .ascii "TEST"

; Main program
.org 0x0100
MAIN:
        ; Initialize source pointer (ROM) - H:L = 0x00C8
        mvi h, 0x00         ; H = 0x00
        mvi l, 0xC8         ; L = 0xC8 (200 decimal)

        ; Initialize destination pointer (RAM) - B:C will be 0x0800
        ; But we need to use H:L for memory operations, so we'll do this in steps

        ; Initialize counter in register C
        mvi c, 0x00         ; C = 0 (will count bytes written)

COPY_LOOP:
        ; Read from ROM at H:L (0x00C8 + offset)
        mov a, m            ; A = ROM[H:L]

        ; Save the ROM address temporarily
        mov d, h            ; D = H (save ROM high byte)
        mov e, l            ; E = L (save ROM low byte)

        ; Set H:L to RAM address (0x0800 + counter)
        mvi h, 0x08         ; H = 0x08 (RAM base high byte)
        mov l, c            ; L = C (offset/counter)

        ; Write to RAM at H:L
        mov m, a            ; RAM[H:L] = A

        ; Restore ROM address and increment
        mov h, d            ; H = D (restore ROM high byte)
        mov l, e            ; L = E (restore ROM low byte)
        inr l               ; L++ (next ROM address)

        ; Increment counter
        inr c               ; C++

        ; Check if we've copied 4 bytes
        mov a, c
        cpi 0x04            ; Compare C with 4
        jnz COPY_LOOP       ; If C != 4, continue loop

VERIFY:
        ; Now read back from RAM and verify
        ; Read first character from RAM[0x0800]
        mvi h, 0x08         ; H = 0x08
        mvi l, 0x00         ; L = 0x00
        mov a, m            ; A = RAM[0x0800] (should be 'T' = 0x54)

        ; Save first char to A (already there)
        ; Read second character for additional verification
        inr l               ; L = 0x01
        mov b, m            ; B = RAM[0x0801] (should be 'E' = 0x45)

        ; Set final register values for verification
        mvi l, 0x04         ; L = 4 (end position)
        ; C already has 0x04 (byte count)
        ; H already has 0x08 (RAM high byte)
        ; B has second character
        ; A has first character

        hlt                 ; Halt with verification data in registers

.end
