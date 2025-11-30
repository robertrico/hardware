; Minimal 6809 Template
; Project: input_game
; Description: Interactive text adventure game using ASSIST09

; =========================================
; Constants
; =========================================
STACK   equ     $0400           ; Stack pointer location
ROOM    equ     $0100

INCH    equ     0

; ASSIST09 SWI Functions
OUTCH   equ     1               ; Output character from A
PDATA   equ     3               ; Output CR/LF then string
; =========================================
; Code Start
; =========================================
        org     $0250           ; ROM starts here

START   lds     #STACK          ; Initialize stack pointer
        clr     ROOM

; =========================================
; Your code goes here
; =========================================
MAIN    lda     ROOM
        cmpa    #0
        beq     GSTART
        bra     PATH            ; Loop forever

GSTART  ldx     #MSG_START
        inc     ROOM
        jsr     PRINT_STR

PATH    ldx     #MSG_CHOICE
        jsr     PRINT_STR
        swi
        fcb     INCH

        cmpa    #'1'
        beq     GO_DEEPER

        cmpa    #'2'
        beq     TURN_BACK

        bra     MAIN    ; Default to main loop


; =========================================
; Subroutines
; =========================================

; Print null-terminated string via ASSIST09
; Input: X = pointer to string
PRINT_STR
        pshs    a               ; Save A
PLOOP   lda     ,x+             ; Get character
        beq     PDONE           ; If null, done
        swi                     ; Call ASSIST09
        fcb     OUTCH           ; Output character
        bra     PLOOP           ; Next character
PDONE   puls    a,pc            ; Restore and return

DECIDE
        ldx     #GET_MSG
        jsr     PRINT_STR

        swi
        fcb     INCH

        cmpa    #'1'
        beq     MSG_CAVE

        cmpa    #'2'
        beq     MSG_CLEARING

        cmpa    #'3'
        beq     MSG_PATH

        bra     DECIDE
GO_DEEPER
        ldx     #NEW_LINE
        jsr     PRINT_STR
        bra     DECIDE
TURN_BACK
        dec     ROOM
        ldx     #TURNED_BACK
        jsr     PRINT_STR
        bra     MAIN
NEW_LINE
        fcb     $0D,$0A
        fcb     0
TURNED_BACK
        fcc     "You head back."
        fcb     $0D,$0A         ; CR, LF
        fcb     0
GET_MSG
        fcc     "You see a cave(1), a clearing(2), or another path(3). Where do you want to go?"
        fcb     $0D,$0A
        fcb     0
MSG_START
        fcc     "You stand at the edge of a dark forest."
        fcb     $0D,$0A         ; CR, LF
        fcb     0
MSG_PATH
        fcc     "You walk deeper into the forest. The trees grow thick."
        fcb     $0D,$0A
        fcb     0
MSG_CLEARING
        fcc     "You come to a clearing."
        fcb     $0D,$0A
        fcb     0
MSG_CAVE
        fcc     "You've entered a cave."
        fcb     $0D,$0A
        fcb     0

MSG_CHOICE
        fcc     "What do you do? (1) Go deeper? (2) Turn back."
        fcb     $0D,$0A
        fcb     0

; =========================================
; Data Section
; =========================================

MSG_TABLE
        fdb     MSG_START       ; Room 0
        fdb     MSG_PATH        ; Room 1
        fdb     MSG_CLEARING    ; Room 2
        fdb     MSG_CAVE        ; Room 3
        end     START
