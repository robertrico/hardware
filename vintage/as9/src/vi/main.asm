; VI Screen Editor for 6809
; A simple visual editor with hjkl navigation
; ESC for command mode, i/a for insert mode
; :w to save, :q to quit

; =========================================
; Constants
; =========================================
; Memory Map:
; $0000-$0178  BASIC variables
; $0179-$6FCF  Free user RAM (~28KB)
; $6FD0-$6FDC  DISASSEMBLER variables
; $6FE0-$6FFC  TRACE variables
; $7000-$7051  ASSIST09 variables
; $C000-$FFFF  ROM (BASIC, DISASM, TRACE, ASSIST09)

STACK   EQU     $6FCF           ; Stack just below DISASM vars
ACIA    EQU     $BE00           ; ACIA base address
ACIACTL EQU     ACIA            ; Control/Status register
ACIADAT EQU     ACIA+1          ; Data register

; ASCII codes
CR      EQU     $0D             ; Carriage return
LF      EQU     $0A             ; Line feed
BS      EQU     $08             ; Backspace
ESC     EQU     $1B             ; Escape character
DEL     EQU     $7F             ; Delete key

; Screen dimensions
COLS    EQU     80              ; Screen width
ROWS    EQU     24              ; Screen height (standard terminal)

; Memory allocation in user RAM ($0179-$6FCF)
TEXTBUF EQU     $0200           ; Text buffer: 80x24 = 1920 bytes ($0200-$09BF)
BUFEND  EQU     TEXTBUF+(COLS*ROWS)

; Editor state (after text buffer)
CURX    EQU     $09C0           ; Cursor X position (0-79)
CURY    EQU     $09C1           ; Cursor Y position (0-79)
MODE    EQU     $09C2           ; 0=command, 1=insert
CMDBUF  EQU     $09D0           ; Command buffer for : commands (16 bytes)

; Modes
CMDMODE EQU     0               ; Command mode
INSMODE EQU     1               ; Insert mode

; =========================================
; Code Start
; =========================================
        ORG     $0400           ; ROM starts here

START   LDS     #STACK          ; Initialize stack pointer

        ; Initialize editor
        LBSR    INITBUF         ; Initialize text buffer
        LBSR    CLRSCR          ; Clear screen
        LBSR    LOADBUF         ; Load saved text if any
        ; Don't redraw on startup - buffer is already cleared
        CLR     CURX            ; Start at (0,0)
        CLR     CURY
        LBSR    SETCMD          ; Start in command mode
        LBSR    UPDCUR          ; Position cursor

; Main editor loop
MAIN    LBSR    GETCHR          ; Get character

        LDB     MODE            ; Check mode
        BNE     INSMODE_        ; In insert mode?

; Command mode handling
CMDMODE_ CMPA   #'h             ; Left
        LBEQ    MOVELEFT
        CMPA    #'j             ; Down
        LBEQ    MOVEDOWN
        CMPA    #'k             ; Up
        LBEQ    MOVEUP
        CMPA    #'l             ; Right
        LBEQ    MOVERIGHT
        CMPA    #'i             ; Insert mode
        LBEQ    GOINS
        CMPA    #'a             ; Append (insert after cursor)
        LBEQ    GOAPP
        CMPA    #':             ; Colon command
        LBEQ    COLONCMD
        LBRA    MAIN            ; Ignore other keys

; Insert mode handling
INSMODE_ CMPA   #ESC            ; Escape = back to command mode
        LBEQ    SETCMD_
        CMPA    #CR             ; Enter = newline
        LBEQ    DONEWLINE
        CMPA    #BS             ; Backspace
        LBEQ    DOBACKSP
        CMPA    #DEL            ; Delete key (some terminals)
        LBEQ    DOBACKSP
        CMPA    #$20            ; Printable?
        LBLO    MAIN            ; Ignore control chars
        CMPA    #$7E
        LBHI    MAIN

        ; Insert character at cursor
        LBSR    INSCHAR
        LBRA    MAIN

; Movement commands
MOVELEFT LBSR   MVLEFT
        LBSR    UPDCUR
        LBRA    MAIN

MOVERIGHT LBSR  MVRIGHT
        LBSR    UPDCUR
        LBRA    MAIN

MOVEUP  LBSR    MVUP
        LBSR    UPDCUR
        LBRA    MAIN

MOVEDOWN LBSR   MVDOWN
        LBSR    UPDCUR
        LBRA    MAIN

; Mode switching
SETCMD_ LBSR    SETCMD
        LBRA    MAIN

GOINS   LBSR    SETINS
        LBRA    MAIN

GOAPP   LBSR    MVRIGHT         ; Append = move right then insert
        LBSR    SETINS
        LBRA    MAIN

; =========================================
; Core I/O
; =========================================

; Get character from ACIA
GETCHR  PSHS    B
GETCH1  LDB     ACIACTL
        ANDB    #$01            ; RX ready?
        BEQ     GETCH1
        LDA     ACIADAT
        ANDA    #$7F            ; Strip parity
        PULS    B,PC

; Put character to ACIA
PUTCHR  PSHS    B
PUTCH1  LDB     ACIACTL
        ANDB    #$02            ; TX ready?
        BEQ     PUTCH1
        STA     ACIADAT
        PULS    B,PC

; Print null-terminated string (X = pointer)
PRINT   PSHS    A
PRLOOP  LDA     ,X+
        BEQ     PREND
        LBSR    PUTCHR
        BRA     PRLOOP
PREND   PULS    A,PC

; Print newline
NEWLINE PSHS    A
        LDA     #CR
        LBSR    PUTCHR
        LDA     #LF
        LBSR    PUTCHR
        PULS    A,PC

; =========================================
; Screen Functions
; =========================================

; Clear screen (ANSI ESC[2J ESC[H)
CLRSCR  LEAX    CLRSEQ,PCR
        LBSR    PRINT
        RTS

CLRSEQ  FCB     ESC,'[,'2,'J    ; Clear screen
        FCB     ESC,'[,'H       ; Home cursor
        FCB     0

; Update cursor position on screen (ANSI ESC[row;colH)
UPDCUR  PSHS    A,X
        LDA     #ESC
        LBSR    PUTCHR
        LDA     #'[
        LBSR    PUTCHR

        ; Row (Y + 1, since ANSI is 1-based)
        LDA     CURY
        INCA
        LBSR    PUTNUM

        LDA     #';
        LBSR    PUTCHR

        ; Column (X + 1)
        LDA     CURX
        INCA
        LBSR    PUTNUM

        LDA     #'H
        LBSR    PUTCHR

        PULS    X,A,PC

; Print number in A (0-255) as decimal
PUTNUM  PSHS    A,B,X
        LDX     #NUMBUF+3       ; Point to end of buffer
        CLR     ,X              ; Null terminate
        LEAX    -1,X

        ; Handle 0 specially
        CMPA    #0
        BNE     PUTN1
        LDA     #'0
        STA     ,X
        LBSR    PRINT
        PULS    X,B,A,PC

PUTN1   LDB     #10             ; Divisor
PUTN2   TSTB                    ; Check if A is 0
        BEQ     PUTN3
        CMPA    #0
        BEQ     PUTN3

        PSHS    A               ; Save quotient
        LDB     #10
        LBSR    DIVMOD          ; A = A/10, B = A%10
        PULS    A

        ADDB    #'0             ; Convert to ASCII
        STB     ,X
        LEAX    -1,X

        LDB     #10
        LBSR    DIVMOD          ; A = A / 10
        BRA     PUTN2

PUTN3   LEAX    1,X             ; Move to first digit
        LBSR    PRINT
        PULS    X,B,A,PC

; Divide A by 10, return quotient in A, remainder in B
DIVMOD  PSHS    X
        CLRB                    ; Quotient counter
DIVM1   CMPA    #10
        BLO     DIVM2
        SUBA    #10
        INCB                    ; Increment quotient
        BRA     DIVM1
DIVM2   PSHS    B               ; Save quotient
        TFR     A,B             ; Remainder to B
        PULS    A               ; Quotient to A
        PULS    X,PC

NUMBUF  RMB     4               ; Number buffer

; Redraw entire screen from buffer
REDRAW  PSHS    A,B,X,Y
        LBSR    CLRSCR

        LDY     #TEXTBUF        ; Start of text buffer
        CLRB                    ; Row counter

REDRAW1 LDA     #0
        STA     CURX            ; Start at column 0
        STB     CURY            ; Current row

        LDA     #COLS           ; Characters per row
        LDX     #0              ; Column counter

REDRAW2 LDA     ,Y+             ; Get character
        CMPA    #0              ; Null/empty?
        BEQ     REDRAW3
        LBSR    PUTCHR          ; Display it

REDRAW3 LEAX    1,X             ; Next column
        CMPX    #COLS
        BLO     REDRAW2

        LBSR    NEWLINE         ; End of row

        INCB                    ; Next row
        CMPB    #ROWS
        BLO     REDRAW1

        ; Reset cursor position
        CLR     CURX
        CLR     CURY

        PULS    Y,X,B,A,PC

; =========================================
; Buffer Functions
; =========================================

; Initialize text buffer (fill with spaces)
INITBUF PSHS    A,X
        LDX     #TEXTBUF
        LDA     #' '            ; Fill with spaces
INITB1  STA     ,X+
        CMPX    #BUFEND
        BLO     INITB1
        PULS    X,A,PC

; Load buffer from storage (stub for now - just clears)
LOADBUF RTS                     ; TODO: implement persistence

; Get buffer address for current cursor position
; Returns address in X
GETBUFPOS PSHS  A,B
        LDA     CURY
        LDB     #COLS
        MUL                     ; D = row offset
        ADDB    CURX            ; Add column
        ADCA    #0              ; Handle carry
        ADDD    #TEXTBUF        ; Add base address
        TFR     D,X
        PULS    B,A,PC

; =========================================
; Cursor Movement
; =========================================

; Move cursor left
MVLEFT  PSHS    A
        LDA     CURX
        BEQ     MVL1            ; Already at left edge
        DECA
        STA     CURX
MVL1    PULS    A,PC

; Move cursor right
MVRIGHT PSHS    A
        LDA     CURX
        CMPA    #COLS-1
        BHS     MVR1            ; Already at right edge
        INCA
        STA     CURX
MVR1    PULS    A,PC

; Move cursor up
MVUP    PSHS    A
        LDA     CURY
        BEQ     MVU1            ; Already at top
        DECA
        STA     CURY
MVU1    PULS    A,PC

; Move cursor down
MVDOWN  PSHS    A
        LDA     CURY
        CMPA    #ROWS-1
        BHS     MVD1            ; Already at bottom
        INCA
        STA     CURY
MVD1    PULS    A,PC

; =========================================
; Insert Mode Functions
; =========================================

; Set command mode
SETCMD  PSHS    A
        CLR     MODE
        PULS    A,PC

; Set insert mode
SETINS  PSHS    A
        LDA     #INSMODE
        STA     MODE
        PULS    A,PC

; Insert character at cursor position
INSCHAR PSHS    A,X,B
        LBSR    GETBUFPOS       ; X = buffer position
        STA     ,X              ; Store character

        ; Check if we're at the right edge (column 79)
        LDB     CURX
        CMPB    #COLS-1
        BHS     INSCH1          ; At edge - don't advance or echo

        ; Not at edge - echo and advance
        LBSR    PUTCHR          ; Echo to screen (cursor advances automatically)
        LBSR    MVRIGHT         ; Move cursor right in buffer
        PULS    B,X,A,PC

INSCH1  ; At right edge - overwrite but don't advance
        LBSR    PUTCHR          ; Echo character
        ; Send backspace to keep cursor at same position
        LDA     #BS
        LBSR    PUTCHR
        PULS    B,X,A,PC

; Handle newline in insert mode
DONEWLINE PSHS  A
        ; Move to start of next line
        CLR     CURX
        LBSR    MVDOWN
        ; Send CR/LF manually
        LDA     #CR
        LBSR    PUTCHR
        LDA     #LF
        LBSR    PUTCHR
        ; Flush any LF that might follow CR from terminal
        PULS    A
        LBRA    MAIN

; Handle backspace in insert mode
DOBACKSP PSHS   A,X
        LBSR    MVLEFT          ; Move cursor left in buffer
        LBSR    GETBUFPOS       ; Get buffer position
        LDA     #' '            ; Replace with space in buffer
        STA     ,X

        ; Erase character on screen: BS, space, BS
        LDA     #BS             ; Send backspace
        LBSR    PUTCHR
        LDA     #' '            ; Space
        LBSR    PUTCHR
        LDA     #BS             ; Backspace again
        LBSR    PUTCHR
        ; Terminal cursor is now in correct position - don't call UPDCUR

        PULS    X,A
        LBRA    MAIN            ; Go back to main loop

; =========================================
; Colon Commands
; =========================================

; Handle colon command
COLONCMD PSHS   A,B,X
        ; Display : at bottom of screen
        LDA     #':
        LBSR    PUTCHR

        ; Get command
        LDX     #CMDBUF
        CLRB

COLCMD1 LBSR    GETCHR

        ; Check for enter
        CMPA    #CR
        BEQ     COLCMD2

        ; Check for backspace
        CMPA    #BS
        BNE     COLCMD1A
        TSTB
        BEQ     COLCMD1
        DECB
        LEAX    -1,X
        LDA     #BS
        LBSR    PUTCHR
        LDA     #' '
        LBSR    PUTCHR
        LDA     #BS
        LBSR    PUTCHR
        BRA     COLCMD1

COLCMD1A ; Store character
        CMPB    #15             ; Max command length
        BHS     COLCMD1
        STA     ,X+
        INCB
        LBSR    PUTCHR
        BRA     COLCMD1

COLCMD2 CLR     ,X              ; Null terminate
        LBSR    NEWLINE

        ; Parse command
        LDX     #CMDBUF
        LDA     ,X+

        ; Check for 'w' (write)
        CMPA    #'w
        BEQ     CMDWRITE

        ; Check for 'q' (quit)
        CMPA    #'q
        BEQ     CMDQUIT

        ; Check for "wq" (write and quit)
        CMPA    #'w
        BNE     COLCMD3
        LDA     ,X
        CMPA    #'q
        BEQ     CMDWQ

COLCMD3 ; Unknown command - just redraw and continue
        LBSR    REDRAW
        LBSR    UPDCUR
        PULS    X,B,A,PC

CMDWRITE ; Write (save) - for now just show message
        LEAX    SAVEMSG,PCR
        LBSR    PRINT
        LBSR    GETCHR          ; Wait for keypress
        LBSR    REDRAW
        LBSR    UPDCUR
        PULS    X,B,A,PC

CMDWQ   ; Write and quit
        LEAX    SAVEMSG,PCR
        LBSR    PRINT
        LBSR    GETCHR
        ; Fall through to quit

CMDQUIT ; Quit to ASSIST09
        LDS     #$7000
        SWI
        FCB     8

SAVEMSG FCC     "File saved. Press any key..."
        FCB     0

; =========================================
; Data Section
; =========================================

        END
