; ROM Hello World (Standalone - no ASSIST09)
; Demonstrates ROM-based program with direct hardware I/O

; =========================================
; Hardware Addresses
; =========================================
ACIA_STATUS  EQU     $BE00           ; ACIA status register
ACIA_DATA    EQU     $BE01           ; ACIA data register
TDRE         EQU     $02             ; Transmit Data Register Empty bit

; =========================================
; Code Start (ROM)
; =========================================
        ORG     $C000               ; ROM starts here

START   LDS     #$0200              ; Initialize stack pointer
        LDX     #MSG                ; Point to message

LOOP    LDA     ,X+                 ; Load character
        BEQ     DONE                ; If zero, done
        BSR     PUTCHAR             ; Output character
        BRA     LOOP                ; Next character

DONE    BRA     DONE                ; Loop forever (or jump to main program)

; =========================================
; I/O Subroutines (Your own!)
; =========================================

; PUTCHAR - Output character in A to ACIA
; Input: A = character to output
; Destroys: B
PUTCHAR PSHS    A                   ; Save character
WAIT    LDB     ACIA_STATUS         ; Check ACIA status
        ANDB    #TDRE               ; Test transmit ready
        BEQ     WAIT                ; Wait until ready
        PULS    A                   ; Restore character
        STA     ACIA_DATA           ; Send to ACIA
        RTS

; =========================================
; Data Section
; =========================================

MSG     FCC     "HELLO WORLD"
        FCB     $0D,$0A             ; CR, LF
        FCB     0                   ; Null terminator

; =========================================
; Interrupt Vectors (Required for ROM!)
; =========================================
        ORG     $FFF0
        FDB     START               ; Reserved
        FDB     START               ; SWI3
        FDB     START               ; SWI2
        FDB     START               ; FIRQ
        FDB     START               ; IRQ
        FDB     START               ; SWI
        FDB     START               ; NMI
        FDB     START               ; RESET (power-on entry)

        END
