; Cursor Movement Game
; Use WASD keys to move cursor around screen
; Q to quit back to ASSIST09

; ASSIST09 SWI Functions
INCHNP  EQU     0               ; Input character
OUTCH   EQU     1               ; Output character
MONITR  EQU     8               ; Return to monitor

; Game constants
TARGX1  EQU     60              ; Target X position 1
TARGY1  EQU     15              ; Target Y position 1
TARGX2  EQU     20              ; Target X position 2
TARGY2  EQU     8               ; Target Y position 2
TARGX3  EQU     70              ; Target X position 3
TARGY3  EQU     20              ; Target Y position 3
TARGX4  EQU     10              ; Target X position 4
TARGY4  EQU     18              ; Target Y position 4

        ORG     $0100

START   LBSR    INIT            ; Initialize game
        LBSR    CLEAR           ; Clear screen
        LBSR    HIDECUR         ; Hide terminal cursor
        LBSR    SHOWSCORE       ; Show initial score
        LBSR    DRAWTARG        ; Draw target
        LBSR    DRAWCUR         ; Draw initial cursor position

MAIN    LBSR    GETKEY
        LBSR    MOVECUR
        LBSR    CHKCOLL         ; Check collision BEFORE moving target
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
        CLR     GOTHIT          ; Target not collected yet
        CLR     SCORE           ; Start with 0 score
        CLR     MOVECNT         ; Movement counter for message
        CLR     SHOWMSG_FLG     ; Message not showing
        LDA     #1              ; Start with target 1
        STA     TARGNUM
        LBSR    GETTARGPOS      ; Load first target position
        RTS

; Get target position based on TARGNUM
GETTARGPOS LDA  TARGNUM
        CMPA    #1
        BNE     GTP2
        LDA     #TARGX1
        STA     TARGX
        LDA     #TARGY1
        STA     TARGY
        RTS
GTP2    CMPA    #2
        BNE     GTP3
        LDA     #TARGX2
        STA     TARGX
        LDA     #TARGY2
        STA     TARGY
        RTS
GTP3    CMPA    #3
        BNE     GTP4
        LDA     #TARGX3
        STA     TARGX
        LDA     #TARGY3
        STA     TARGY
        RTS
GTP4    LDA     #TARGX4
        STA     TARGX
        LDA     #TARGY4
        STA     TARGY
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
        LBSR    PUTCH
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
ERS2    ; Check if old position was on target
        TST     GOTHIT          ; Target collected?
        BNE     ERS3            ; Yes, just erase with space
        LDA     OLDX
        CMPA    TARGX           ; Was old X on target?
        BNE     ERS3
        LDA     OLDY
        CMPA    TARGY           ; Was old Y on target?
        BNE     ERS3
        LDA     #'0             ; Yes, redraw target
        BSR     PUTCH
        RTS
ERS3    LDA     #32             ; Space to erase
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
        SUBA    #32             ; Convert to uppercase
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

MOVEUP  LDA     CURX            ; Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        CMPA    #2              ; At top?
        BHI     MVUP1           ; No, move up
        LDA     #23             ; Yes, wrap to bottom
        STA     CURY
        LBRA    MVDONE
MVUP1   DECA
        STA     CURY
        LBRA    MVDONE

MOVEDN  LDA     CURX            ; Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        CMPA    #23             ; At bottom?
        BLO     MVDN1           ; No, move down
        LDA     #2              ; Yes, wrap to top
        STA     CURY
        LBRA    MVDONE
MVDN1   INCA
        STA     CURY
        LBRA    MVDONE

MOVELFT LDA     CURX            ; Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        LDA     CURX
        CMPA    #2              ; At left?
        BHI     MVLT1           ; No, move left
        LDA     #79             ; Yes, wrap to right
        STA     CURX
        LBRA    MVDONE
MVLT1   DECA
        STA     CURX
        LBRA    MVDONE

MOVERGT LDA     CURX            ; Save old position
        STA     OLDX
        LDA     CURY
        STA     OLDY
        LDA     CURX
        CMPA    #79             ; At right?
        BLO     MVRT1           ; No, move right
        LDA     #2              ; Yes, wrap to left
        STA     CURX
        LBRA    MVDONE
MVRT1   INCA
        STA     CURX
        LBRA    MVDONE

; Draw target (0 character)
DRAWTARG TST    GOTHIT          ; Already collected?
        BNE     DRGTDN          ; Yes, don't draw
        LDX     #POSSTR
DRGTLP  LDA     ,X+
        BEQ     DRGT2
        CMPA    #'Y
        BNE     DRGT1
        LDA     TARGY
        LBSR    PUTNUM
        BRA     DRGTLP
DRGT1   CMPA    #'X
        BNE     DRGT1A
        LDA     TARGX
        LBSR    PUTNUM
        BRA     DRGTLP
DRGT1A  LBSR    PUTCH
        BRA     DRGTLP
DRGT2   LDA     #'0             ; Draw 0 character
        LBSR    PUTCH
DRGTDN  RTS

; Check collision with target (adjacent or on top)
CHKCOLL TST     GOTHIT          ; Already collected?
        BNE     CHKDN           ; Yes, skip
        ; Check if X is within 1 (CURX-1 <= TARGX <= CURX+1)
        LDA     CURX
        DECA                    ; A = CURX - 1
        CMPA    TARGX
        BHI     CHKDN           ; TARGX < CURX-1, too far left
        LDA     CURX
        INCA                    ; A = CURX + 1
        CMPA    TARGX
        BLO     CHKDN           ; TARGX > CURX+1, too far right
        ; Check if Y is within 1 (CURY-1 <= TARGY <= CURY+1)
        LDA     CURY
        DECA                    ; A = CURY - 1
        CMPA    TARGY
        BHI     CHKDN           ; TARGY < CURY-1, too far up
        LDA     CURY
        INCA                    ; A = CURY + 1
        CMPA    TARGY
        BLO     CHKDN           ; TARGY > CURY+1, too far down
        ; Got it!
        INC     SCORE           ; Increment score
        INC     GOTHIT          ; Mark as collected
        LBSR    SHOWSCORE       ; Update score display
        LDA     #1
        STA     SHOWMSG_FLG     ; Set message flag
        CLR     MOVECNT         ; Reset movement counter
        LBSR    SHOWMSG         ; Show "Got it!" message
        ; Erase old target
        LBSR    ERASETARG
        ; Spawn next target
        LDA     TARGNUM
        INCA
        CMPA    #5              ; Cycle through 4 targets
        BLO     CHK1
        LDA     #1              ; Wrap to target 1
CHK1    STA     TARGNUM
        CLR     GOTHIT          ; Clear collected flag for new target
        LBSR    GETTARGPOS      ; Get new target position
        LBSR    DRAWTARG        ; Draw new target
        LBSR    DRAWCUR         ; Redraw cursor at collection point
CHKDN   RTS

; Erase target
ERASETARG LDX   #POSSTR
ERSTLP  LDA     ,X+
        BEQ     ERST2
        CMPA    #'Y
        BNE     ERST1
        LDA     #TARGY
        LBSR    PUTNUM
        BRA     ERSTLP
ERST1   CMPA    #'X
        BNE     ERST1A
        LDA     #TARGX
        LBSR    PUTNUM
        BRA     ERSTLP
ERST1A  LBSR    PUTCH
        BRA     ERSTLP
ERST2   LDA     #32             ; Space to erase
        LBSR    PUTCH
        RTS

; Show "Got it!" message at top center
SHOWMSG LDX     #MSGSTR
MSGLP   LDA     ,X+
        BEQ     MSGDN
        CMPA    #'Y
        BNE     MSG1
        LDA     #1              ; Row 1 (top)
        LBSR    PUTNUM
        BRA     MSGLP
MSG1    CMPA    #'X
        BNE     MSG1A
        LDA     #35             ; Column 35 (center-ish)
        LBSR    PUTNUM
        BRA     MSGLP
MSG1A   LBSR    PUTCH
        BRA     MSGLP
MSGDN   RTS

MSGSTR  FCB     27,'[,'Y,';,'X,'H,'G,'o,'t,32,'i,'t,'!,0

; Hide "Got it!" message
HIDEMSG LDX     #MSGSTR
HMLP    LDA     ,X+
        BEQ     HM2
        CMPA    #'Y
        BNE     HM1
        LDA     #1              ; Row 1
        LBSR    PUTNUM
        BRA     HMLP
HM1     CMPA    #'X
        BNE     HM1A
        LDA     #35             ; Column 35
        LBSR    PUTNUM
        BRA     HMLP
HM1A    LBSR    PUTCH
        BRA     HMLP
HM2     ; Clear the message with spaces
        LDX     #CLRMSGSTR
HM3     LDA     ,X+
        BEQ     HM4
        LBSR    PUTCH
        BRA     HM3
HM4     RTS

CLRMSGSTR FCB    32,32,32,32,32,32,32,32,0  ; 8 spaces

; Show score at top left
SHOWSCORE LDX   #SCORESTR
SSLP    LDA     ,X+
        BEQ     SS2
        CMPA    #'Y
        BNE     SS1
        LDA     #1              ; Row 1
        LBSR    PUTNUM
        BRA     SSLP
SS1     CMPA    #'X
        BNE     SS1A
        LDA     #2              ; Column 2
        LBSR    PUTNUM
        BRA     SSLP
SS1A    LBSR    PUTCH
        BRA     SSLP
SS2     LDA     SCORE
        LBSR    PUTNUM
        RTS

SCORESTR FCB    27,'[,'Y,';,'X,'H,'S,'c,'o,'r,'e,':,32,0

QUIT    LBSR    SHOWCUR         ; Show cursor again
        LBSR    CLEAR
        LDA     #1
        SWI
        FCB     MONITR

MVDONE  ; Check if we need to clear the message
        TST     SHOWMSG_FLG     ; Is message showing?
        BEQ     MVD1            ; No, skip
        INC     MOVECNT         ; Increment movement counter
        LDA     MOVECNT
        CMPA    #5              ; 5 movements since collection?
        BLO     MVD1            ; Not yet
        ; Clear the message
        CLR     SHOWMSG_FLG
        LBSR    HIDEMSG
MVD1    ; Move target (use low bits of CURX as random direction)
        TST     GOTHIT          ; Target already collected?
        BNE     MVD2            ; Yes, skip movement
        LBSR    MOVETARG        ; Move the target
MVD2    RTS

; Move target in pseudo-random direction
MOVETARG LDA    TARGX           ; Save old position
        STA     OLDTX
        LDA     TARGY
        STA     OLDTY
        ; Use CURX low 2 bits for direction (0-3)
        LDA     CURX
        ANDA    #$03            ; Mask to 0-3
        BEQ     MTUP            ; 0 = up
        CMPA    #1
        BEQ     MTDN            ; 1 = down
        CMPA    #2
        BEQ     MTLT            ; 2 = left
        BRA     MTRT            ; 3 = right

MTUP    LDA     TARGY
        CMPA    #2              ; At top?
        BLS     MTDN            ; Yes, go down instead
        DECA
        STA     TARGY
        BRA     MTDONE

MTDN    LDA     TARGY
        CMPA    #23             ; At bottom?
        BHS     MTUP            ; Yes, go up instead
        INCA
        STA     TARGY
        BRA     MTDONE

MTLT    LDA     TARGX
        CMPA    #2              ; At left?
        BLS     MTRT            ; Yes, go right instead
        DECA
        STA     TARGX
        BRA     MTDONE

MTRT    LDA     TARGX
        CMPA    #79             ; At right?
        BHS     MTLT            ; Yes, go left instead
        INCA
        STA     TARGX
        BRA     MTDONE

MTDONE  ; Erase target at old position
        LDX     #POSSTR
MTLP1   LDA     ,X+
        BEQ     MT2
        CMPA    #'Y
        BNE     MT1
        LDA     OLDTY
        LBSR    PUTNUM
        BRA     MTLP1
MT1     CMPA    #'X
        BNE     MT1A
        LDA     OLDTX
        LBSR    PUTNUM
        BRA     MTLP1
MT1A    LBSR    PUTCH
        BRA     MTLP1
MT2     LDA     #32             ; Erase with space
        LBSR    PUTCH
        ; Draw target at new position
        LBSR    DRAWTARG
        RTS

; Game state variables (after code)
CURX    RMB     1               ; Cursor X position (1-80)
CURY    RMB     1               ; Cursor Y position (1-24)
OLDX    RMB     1               ; Previous X position
OLDY    RMB     1               ; Previous Y position
LASTKEY RMB     1               ; Last key pressed
GOTHIT  RMB     1               ; Target collected flag
SCORE   RMB     1               ; Score counter
MOVECNT RMB     1               ; Movement counter for message
SHOWMSG_FLG RMB 1               ; Message showing flag
TARGNUM RMB     1               ; Current target number (1-4)
TARGX   RMB     1               ; Current target X
TARGY   RMB     1               ; Current target Y
OLDTX   RMB     1               ; Previous target X
OLDTY   RMB     1               ; Previous target Y

        END
