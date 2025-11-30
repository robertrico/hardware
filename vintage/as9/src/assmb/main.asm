; Tiny Assembler Test Program
; Project: assmb
; Description: Test program with single instruction to assemble

; =========================================
; Constants
; =========================================
STACK   EQU     $0400           ; Stack pointer location
ACIA    EQU     $BE00           ; ACIA base address
ACIACTL EQU     ACIA            ; Control/Status register
ACIADAT EQU     ACIA+1          ; Data register

; =========================================
; Code Start
; =========================================
        ORG     $0400           ; RAM starts here

START   LDS     #STACK          ; Initialize stack pointer

; =========================================
; The test program we want to assemble
; =========================================
; This is the assembly source we'll feed to our assembler:
;   LDA #45
;
; Expected output: 86 2D (opcode 86 = LDA immediate, 2D = hex 45)

MAIN    LDA     #45             ; This is what we want to assemble!

        ; For testing, let's output the value
        STA     ACIADAT         ; Send to ACIA

        ; Infinite loop
LOOP    BRA     LOOP

        END
