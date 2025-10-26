; Cursor Movement Game
; Use WASD keys to move cursor around screen
; Q to quit back to ASSIST09

; ASSIST09 SWI Functions
INCHNP  EQU     0               ; Input character
OUTCH   EQU     1               ; Output character
MONITR  EQU     8               ; Return to monitor

        ORG     $0100

START   BSR     INIT            ; Initialize game
        BSR     CLEAR           ; Clear screen
        BSR     HIDECUR         ; Hide terminal cursor

MAIN    LBSR    GETKEY
        LBSR    MOVECUR
        LBSR    ERASECUR
        LBSR    DRAWCUR
        BRA     MAIN

; Initialize
INIT    LDA     #40             ; Center X
        STA     CURX
        STA     OLDX
        LDA     #12             ; Center Y
        STA     CURY
        STA     OLDY
        RTS

; Clear screen (ANSI ESC[2J ESC[H)
CLEAR   LDX     #CLRSTR
CLRLP   LDA     ,X+
        BEQ     CLRDN
        LBSR    PUTCH
        BRA     CLRLP
CLRDN   RTS

CLRSTR  FCB     27,'[,'2,'J,27,'[,'H,0

; Hide terminal cursor (ANSI ESC[?25l)
HIDECUR LDX     #HIDSTR
HIDLP   LDA     ,X+
        BEQ     HIDDN
        BSR     PUTCH
        BRA     HIDLP
HIDDN   RTS

HIDSTR  FCB     27,'[,'?,'2,'5,'l,0

; Show terminal cursor (ANSI ESC[?25h)
SHOWCUR LDX     #SHWSTR
SHWLP   LDA     ,X+
        BEQ     SHWDN
        BSR     PUTCH
        BRA     SHWLP
SHWDN   RTS

SHWSTR  FCB     27,'[,'?,'2,'5,'h,0

; Draw cursor at position
DRAWCUR LDX     #POSSTR
DRWLP   LDA     ,X+
        BEQ     DRW2
        CMPA    #'Y
        BNE     DRW1
        LDA     CURY
        BSR     PUTNUM
        BRA     DRWLP
DRW1    CMPA    #'X
        BNE     DRW1A
        LDA     CURX
        BSR     PUTNUM
        BRA     DRWLP
DRW1A   BSR     PUTCH
        BRA     DRWLP
DRW2    LDA     #'@
        BSR     PUTCH
        RTS

POSSTR  FCB     27,'[,'Y,';,'X,'H,0

; Erase cursor at old position
ERASECUR LDX    #POSSTR
ERSLP   LDA     ,X+
        BEQ     ERS2
        CMPA    #'Y
        BNE     ERS1
        LDA     OLDY
        BSR     PUTNUM
        BRA     ERSLP
ERS1    CMPA    #'X
        BNE     ERS1A
        LDA     OLDX
        BSR     PUTNUM
        BRA     ERSLP
ERS1A   BSR     PUTCH
        BRA     ERSLP
ERS2    LDA     #32             ; Space to erase
        BSR     PUTCH
        RTS

; Output char in A
PUTCH   SWI
        FCB     OUTCH
        RTS

; Output decimal number in A (0-99)
PUTNUM  PSHS    A,B
        LDB     #'0-1
PTN1    INCB
        SUBA    #10
        BCC     PTN1
        ADDA    #10
        PSHS    A
        TFR     B,A
        BSR     PUTCH
        PULS    A
        ADDA    #'0
        BSR     PUTCH
        PULS    B,A
        RTS

; Get key (and erase echo)
GETKEY  SWI
        FCB     INCHNP
        STA     LASTKEY
        ; Erase the echoed character
        PSHS    A
        LDA     #8              ; Backspace
        LBSR    PUTCH
        LDA     #32             ; Space
        LBSR    PUTCH
        LDA     #8              ; Backspace again
        LBSR    PUTCH
        PULS    A
        RTS

; Move cursor based on key
MOVECUR LDA     LASTKEY
        ; Convert to uppercase
        CMPA    #'a
        BLO     MVCHK
        CMPA    #'z
        BHI     MVCHK
        SUBA    #32             ;Convert to uppercase
MVCHK   CMPA    #'W
        BEQ     MOVEUP
        CMPA    #'S
        BEQ     MOVEDN
        CMPA    #'A
        BEQ     MOVELFT
        CMPA    #'D
        BEQ     MOVERGT
        CMPA    #'Q
        LBEQ    QUIT
        RTS

MOVEUP  LDA     CURX            ;Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        CMPA    #2
        BLS     MVDONE
        DECA
        STA     CURY
        BRA     MVDONE

MOVEDN  LDA     CURX            ;Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        CMPA    #23
        BHS     MVDONE
        INCA
        STA     CURY
        BRA     MVDONE

MOVELFT LDA     CURX            ;Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        LDA     CURX
        CMPA    #2
        BLS     MVDONE
        DECA
        STA     CURX
        BRA     MVDONE

MOVERGT LDA     CURX            ;Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        LDA     CURX
        CMPA    #79
        BHS     MVDONE
        INCA
        STA     CURX
        BRA     MVDONE

QUIT    LBSR    SHOWCUR         ; Show cursor again
        LBSR    CLEAR
        LDA     #1
        SWI
        FCB     MONITR

MVDONE  RTS

; Game state variables (after code)
CURX    RMB     1               ; Cursor X position (1-80)
CURY    RMB     1               ; Cursor Y position (1-24)
OLDX    RMB     1               ; Previous X position
OLDY    RMB     1               ; Previous Y position
LASTKEY RMB     1               ; Last key pressed

        END
