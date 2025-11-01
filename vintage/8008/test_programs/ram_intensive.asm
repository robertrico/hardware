; Intel 8008 RAM Intensive Test Program
;
; Purpose: Comprehensive RAM testing with multiple operations
;   1. Fill RAM block with incrementing pattern (0-15)
;   2. Read back and accumulate sum
;   3. Write inverted pattern
;   4. Read back and verify
;
; This program exercises:
;   - Sequential RAM writes (16 bytes)
;   - Sequential RAM reads (32 bytes total)
;   - Arithmetic operations
;   - Nested loops
;   - Subroutine calls
;
; Memory Map:
;   ROM: 0x0000-0x07FF
;   RAM: 0x0800-0x0BFF (1KB)
;   Test data: 0x0800-0x080F (16 bytes)
;
; Expected Results (in registers at halt):
;   A: Checksum/verification result
;   B: Inverted first value (should be 0xF0)
;   C: Array length (0x10 = 16)
;   D: Sum of 0-15 (should be 0x78 = 120 decimal)
;   E: Last value read
;   H: RAM base high (0x08)
;   L: Final address offset

.8008

; Reset vector
.org 0x0000
        jmp MAIN

; Main program
.org 0x0100
MAIN:
        ; Initialize array length in C
        mvi c, 0x10         ; C = 16 (array size)

        ; Phase 1: Fill RAM with ascending pattern (0..15)
        call FILL_RAM

        ; Phase 2: Calculate sum of array
        call CALC_SUM
        mov d, a            ; Save sum in D

        ; Phase 3: Write inverted pattern
        call INVERT_RAM

        ; Phase 4: Verify first inverted value
        call VERIFY

        ; Halt with results in registers
        hlt

;-----------------------------------------------------------------------------
; FILL_RAM: Fill RAM[0x0800-0x080F] with ascending values (0..15)
; Inputs: C = array size (16)
; Modifies: A, H, L, E
;-----------------------------------------------------------------------------
FILL_RAM:
        mvi h, 0x08         ; H = RAM base high
        mvi l, 0x00         ; L = RAM base low
        mvi e, 0x00         ; E = current value (start at 0)

FILL_LOOP:
        mov a, e            ; A = current value
        mov m, a            ; Write to RAM[H:L]

        ; Increment value
        inr e               ; E++

        ; Increment address
        inr l               ; Next RAM location

        ; Check if we've written 16 bytes
        mov a, l
        cpi 0x10
        jnz FILL_LOOP       ; Continue if L != 16

        ret

;-----------------------------------------------------------------------------
; CALC_SUM: Calculate sum of all bytes in array
; Inputs: C = array size
; Outputs: A = sum (checksum)
; Modifies: A, H, L, E
;-----------------------------------------------------------------------------
CALC_SUM:
        mvi h, 0x08         ; H = RAM base high
        mvi l, 0x00         ; L = RAM base low
        mvi e, 0x00         ; E = accumulator (sum)

SUM_LOOP:
        mov a, m            ; A = RAM[H:L]
        add e               ; A = A + sum
        mov e, a            ; E = new sum

        inr l               ; Next address

        ; Check if done (L = 16)
        mov a, l
        cpi 0x10
        jnz SUM_LOOP

        mov a, e            ; A = final sum (should be 0x78)
        ret

;-----------------------------------------------------------------------------
; INVERT_RAM: Write inverted pattern to RAM
; Inverts each byte in place (XOR with 0xFF)
; Inputs: C = array size
; Modifies: A, H, L, E
;-----------------------------------------------------------------------------
INVERT_RAM:
        mvi h, 0x08         ; H = RAM base high
        mvi l, 0x00         ; L = RAM base low

INVERT_LOOP:
        mov a, m            ; A = RAM[H:L]
        xri 0xFF            ; A = A XOR 0xFF (invert all bits)
        mov m, a            ; Write back inverted value

        inr l               ; Next address

        ; Check if done (L = 16)
        mov a, l
        cpi 0x10
        jnz INVERT_LOOP

        ret

;-----------------------------------------------------------------------------
; VERIFY: Check first and last inverted values
; Inputs: None
; Outputs: B = first inverted value (should be 0xFF from original 0x00)
;          E = last inverted value (should be 0xF0 from original 0x0F)
; Modifies: A, B, E, H, L
;-----------------------------------------------------------------------------
VERIFY:
        ; Check first inverted value (should be 0xFF)
        mvi h, 0x08
        mvi l, 0x00
        mov a, m            ; A = first value
        mov b, a            ; B = first value

        ; Check last inverted value (should be 0xF0)
        mvi l, 0x0F         ; Point to last element
        mov a, m            ; A = last value
        mov e, a            ; E = last value

        ret

.end
