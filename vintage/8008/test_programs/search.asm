; Intel 8008 Character Search Program
; Source: Intel 8008 User's Manual
;
; Purpose: Searches memory for a period character ('.')
; Tests memory read operations and character comparison
; Uses H:L register pair for memory addressing
;
; Test data: "Hello, world. I am an 8008" stored starting at location 200
;

.8008

; Start at address 0x0000 to execute from reset
.org 0x0000
        jmp MAIN            ; Jump to main program

; Test string data at location 200 (0xC8)
; Search range is 200-220, so max 20 characters
.org 0x00C8
STRING: .ascii "Hello, world. 8008!!"

; Main program
.org 0x0100
MAIN:

; Location 100 (decimal): Load L with 200
        mvi l, 200          ; LLI 200

; Location 102: Load H with 0
        mvi h, 0            ; LHI 0

; Loop: Fetch character from memory
LOOP:   mov a, m            ; LAM - Load A from memory[H:L]

; Location 105: Compare with period ('.')
        cpi 0x2E            ; CPI "." - Compare immediate with '.'

; Location 107: If equal, go to return
        jz FOUND            ; JZ Found - Jump if Zero flag set

; Location 110: Call increment H&L subroutine
        call INCR           ; CALL INCR - Increment H:L pointer

; Location 113: Load L to A
        mov a, l            ; LAL - Load L to A

; Location 114: Compare with 220
        cpi 220             ; CPI 220 - Check if past end

; Location 116: If unequal, go to loop
        jnz LOOP            ; JNZ Loop - Jump if Not Zero

; Found: Save location and Halt
FOUND:  mov h, l            ; Copy L (address where period was found) to H for verification
        hlt                 ; HLT - Found the period!

; INCR: Increment H&L subroutine (at location 60 decimal = 0x003C)
.org 0x003C
INCR:   inr l               ; INR L - Increment L

; Location 61: Return if not zero
        rnz                 ; RNZ - Return if Not Zero (L didn't wrap to 0)

; Location 62: Increment H
        inr h               ; INH - Increment H

; Location 63: Return
        ret                 ; RET - Return

.end
