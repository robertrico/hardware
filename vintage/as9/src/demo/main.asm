; Minimal 6809 Template
; Project: demo
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
        LDA     #$01

; =========================================
; Your code goes here
; =========================================

MAIN    NOP                     ; Replace with your code
        STA     $4000           ; Send to output port
        BSR     DELAY           ; Wait
        EORA    #$01            ; Toggle bit 0
        BRA     MAIN            ; Loop forever

; =========================================
; Subroutines
; =========================================

; Add your subroutines here
DELAY   PSHS    X               ; Save X
        LDX     #$FFFF          ; Max
DLOOP   LEAX    -1,X            ; X--
        BNE     DLOOP           ; Loop if !0
        PULS    X               ; Restore X
        RTS                     ;

; =========================================
; Data Section
; =========================================

; Add your data definitions here

; =========================================
; Interrupt Vectors
; =========================================
        ORG     $FFFE           ; Reset Vector
        FDB     START           ; Reserved
        FDB     START           ; SWI3
        FDB     START           ; SWI2
        FDB     START           ; FIRQ
        FDB     START           ; IRQ
        FDB     START           ; SWI
        FDB     START           ; NMI
        FDB     START           ; RESET (power-on entry point)

        END
