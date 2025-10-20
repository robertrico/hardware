; Minimal 6809 Template
; Project: [YOUR_PROJECT_NAME]
; Description: [DESCRIBE YOUR PROJECT]

; =========================================
; Constants
; =========================================
STACK   EQU     $0200           ; Stack pointer location

; =========================================
; Code Start
; =========================================
        ORG     $C000           ; ROM starts here

START   LDS     #STACK          ; Initialize stack pointer

; =========================================
; Your code goes here
; =========================================

MAIN    NOP                     ; Replace with your code
        BRA     MAIN            ; Loop forever

; =========================================
; Subroutines
; =========================================

; Add your subroutines here

; =========================================
; Data Section
; =========================================

; Add your data definitions here

; =========================================
; Interrupt Vectors
; =========================================
        ORG     $FFF0
        FDB     START           ; Reserved
        FDB     START           ; SWI3
        FDB     START           ; SWI2
        FDB     START           ; FIRQ
        FDB     START           ; IRQ
        FDB     START           ; SWI
        FDB     START           ; NMI
        FDB     START           ; RESET (power-on entry point)

        END
