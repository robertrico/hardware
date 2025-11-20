; VI Screen Editor for 6809
; A simple visual editor with hjkl navigation
; ESC for command mode, i/a for insert mode
; :w to save, :q to quit

; =========================================
; Constants
; =========================================
; Memory Map (ASSIST09 System):
; $0000-$00FF  Zero page (ASSIST09 direct page when active)
; $0100-$01FF  Stack area (SP starts at $01FF, grows down)
; $0400-$0761  Program code (865 bytes)
; $0800-$0F7F  Text buffer (80x24 = 1920 bytes)
; $0F80-$0F90  Editor state (cursor, mode)
; $1200-$197D  Save buffer (2 + 1920 bytes with 'VI' marker)
; $6FD0-$6FDC  DISASSEMBLER variables (reserved)
; $6FE0-$6FFC  TRACE variables (reserved)
; $7000-$7051  ASSIST09 workspace (DO NOT USE)
; $F800-$FFFF  ASSIST09 ROM

STACK   EQU     $01FF           ; Safe stack area (grows down from $01FF to $0100)

; =========================================
; ASSIST09 SWI Functions
; =========================================
; These functions are called via: SWI / FCB <function_code>
; All I/O goes through ASSIST09 monitor for compatibility

INCHNP  EQU     0               ; Input character (no parity) -> A
OUTCH   EQU     1               ; Output character from A
MONITR  EQU     8               ; Return to ASSIST09 monitor

; ASCII codes
CR      EQU     $0D             ; Carriage return
LF      EQU     $0A             ; Line feed
BS      EQU     $08             ; Backspace
ESC     EQU     $1B             ; Escape character
DEL     EQU     $7F             ; Delete key

; Screen dimensions
COLS    EQU     80              ; Screen width
ROWS    EQU     23              ; Text rows (status at ANSI row 1, text at ANSI rows 2-24)

; Memory allocation in user RAM ($0179-$6FCF)
; Text buffer: 80 cols × 23 rows = 1840 bytes = $730
TEXTBUF EQU     $0800           ; Text buffer start (after program code)
BUFEND  EQU     $0F30           ; Text buffer end ($0800 + $0730)

; Editor state (after text buffer)
CURX    EQU     $0F80           ; Cursor X position (0-79)
CURY    EQU     $0F81           ; Cursor Y position (0-79)
MODE    EQU     $0F82           ; 0=command, 1=insert
CMDBUF  EQU     $0F90           ; Command buffer for : commands (16 bytes)

; Save buffer (after editor state) - includes 2-byte magic marker 'VI'
; Need 2 + 1840 = 1842 bytes
SAVEBUF EQU     $1200           ; Saved buffer: 2 + 1840 bytes ($1200-$192D)

; Modes
CMDMODE EQU     0               ; Command mode
INSMODE EQU     1               ; Insert mode

; =========================================
; Code Start
; =========================================
        ORG     $0400           ; ROM starts here

START   LDS     #STACK          ; Initialize stack pointer

        ; Initialize editor
        ; Check for saved file
        LDX     #SAVEBUF
        LDA     ,X+
        CMPA    #'V'
        BNE     INIT1           ; No marker - initialize buffer
        LDA     ,X
        CMPA    #'I'
        BNE     INIT1           ; No marker - initialize buffer

        ; Found 'VI' marker - load saved text
        LBSR    LOADBUF
        BRA     INIT2

INIT1   ; No saved file - leave buffer as-is (don't wipe RAM)
        ; User can clear manually if needed
        ; LBSR    INITBUF       ; DISABLED: Don't auto-wipe potentially valid data
        ; But ensure SAVEBUF has valid 'VI' marker for future saves
        LBSR    AUTOSAVE

INIT2   LBSR    CLRSCR          ; Clear screen

        ; Position cursor at (0,0)
        CLR     CURX
        CLR     CURY

        ; Start in COMMAND mode
        CLR     MODE            ; 0 = command mode

        ; Draw status line
        LBSR    UPDSTATUS

        ; Position cursor in text area
        LBSR    UPDCUR

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
        CMPA    #'r             ; Redraw screen
        LBEQ    DOREDRAW
        CMPA    #'w             ; Write (save)
        LBEQ    CMDWRITE
        CMPA    #'q             ; Quit
        LBEQ    CMDQUIT
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
; Strategy: Get character at current position, erase echo, move, restore character
MOVELEFT PSHS   A,X
        ; Save character at current buffer position
        LBSR    GETBUFPOS
        LDA     ,X              ; Save the character that should be here
        PSHS    A               ; Push it to stack
        ; Erase echoed 'h'
        LDA     #BS
        LBSR    PUTCHR
        PULS    A               ; Get saved character
        LBSR    PUTCHR          ; Put it back
        LDA     #BS
        LBSR    PUTCHR
        ; Now move cursor
        LBSR    MVLEFT
        LBSR    UPDCUR
        PULS    X,A
        LBRA    MAIN

MOVERIGHT PSHS  A,X
        ; Save character at current buffer position
        LBSR    GETBUFPOS
        LDA     ,X              ; Save the character that should be here
        PSHS    A               ; Push it to stack
        ; Erase echoed 'l'
        LDA     #BS
        LBSR    PUTCHR
        PULS    A               ; Get saved character
        LBSR    PUTCHR          ; Put it back
        LDA     #BS
        LBSR    PUTCHR
        ; Now move cursor
        LBSR    MVRIGHT
        LBSR    UPDCUR
        PULS    X,A
        LBRA    MAIN

MOVEUP  PSHS    A,X
        ; Save character at current buffer position
        LBSR    GETBUFPOS
        LDA     ,X              ; Save the character that should be here
        PSHS    A               ; Push it to stack
        ; Erase echoed 'k'
        LDA     #BS
        LBSR    PUTCHR
        PULS    A               ; Get saved character
        LBSR    PUTCHR          ; Put it back
        LDA     #BS
        LBSR    PUTCHR
        ; Now move cursor
        LBSR    MVUP
        LBSR    UPDCUR
        PULS    X,A
        LBRA    MAIN

MOVEDOWN PSHS   A,X
        ; Save character at current buffer position
        LBSR    GETBUFPOS
        LDA     ,X              ; Save the character that should be here
        PSHS    A               ; Push it to stack
        ; Erase echoed 'j'
        LDA     #BS
        LBSR    PUTCHR
        PULS    A               ; Get saved character
        LBSR    PUTCHR          ; Put it back
        LDA     #BS
        LBSR    PUTCHR
        ; Now move cursor
        LBSR    MVDOWN
        LBSR    UPDCUR
        PULS    X,A
        LBRA    MAIN

; Mode switching
SETCMD_ LBSR    SETCMD
        LBRA    MAIN

GOINS   PSHS    A
        LDA     #BS             ; Erase echoed 'i'
        LBSR    PUTCHR
        PULS    A
        LBSR    SETINS
        LBRA    MAIN

GOAPP   PSHS    A
        LDA     #BS             ; Erase echoed 'a'
        LBSR    PUTCHR
        PULS    A
        LBSR    MVRIGHT         ; Append = move right then insert
        LBSR    SETINS
        LBRA    MAIN

DOREDRAW PSHS   A
        LDA     #BS             ; Erase echoed 'r'
        LBSR    PUTCHR
        PULS    A
        LBSR    REDRAW          ; Redraw screen
        LBSR    UPDCUR
        LBRA    MAIN

; =========================================
; Core I/O
; =========================================

; Get character via ASSIST09
GETCHR  SWI                     ; Call ASSIST09
        FCB     INCHNP          ; Function 0: Input char (no parity)
        RTS

; Put character via ASSIST09
PUTCHR  SWI                     ; Call ASSIST09
        FCB     OUTCH           ; Function 1: Output character
        RTS

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
; Row 1 is status line, so text starts at row 2 (CURY=0 -> screen row 2)
UPDCUR  PSHS    A,X
        LDA     #ESC
        LBSR    PUTCHR
        LDA     #'[
        LBSR    PUTCHR

        ; Row (Y + 2, since row 1 is status line and ANSI is 1-based)
        LDA     CURY
        ADDA    #2
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

; Show buffer content line-by-line (optimized for terminal redraw)
; Starts at row 2 (row 1 is status line)
SHOWBUF PSHS    A,B,X,Y
        ; Position cursor at row 2, column 1
        LDA     #ESC
        LBSR    PUTCHR
        LEAX    TEXTPOS,PCR
        LBSR    PRINT

        LDX     #TEXTBUF        ; Start of text buffer
        LDB     #ROWS           ; 23 rows to display
SHOWB1  LDY     #COLS           ; 80 columns per row
SHOWB2  LDA     ,X+             ; Get character
        LBSR    PUTCHR          ; Display it
        LEAY    -1,Y            ; Decrement column counter
        BNE     SHOWB2          ; Continue until end of row
        ; End of row - decrement counter and check if more rows remain
        DECB                    ; Decrement row counter
        BEQ     SHOWB3          ; Last row done - don't send CR/LF to avoid scroll
        ; Not last row - send CR/LF
        LDA     #CR
        LBSR    PUTCHR
        LDA     #LF
        LBSR    PUTCHR
        BRA     SHOWB1          ; Continue to next row
SHOWB3  PULS    Y,X,B,A,PC

TEXTPOS FCB     '[,'2,';,'1,'H,0        ; Position to row 2, col 1

; Redraw entire screen from buffer
REDRAW  PSHS    A,B,X,Y
        LBSR    CLRSCR
        LBSR    UPDSTATUS       ; Draw status line
        LBSR    SHOWBUF         ; Draw text
        ; Don't reset cursor - preserve current position
        PULS    Y,X,B,A,PC

; =========================================
; Buffer Functions
; =========================================

; Initialize text buffer (fill with spaces)
; NOTE: Disabled for performance - 1920 byte fill is slow on 1MHz 6809
; Text buffer will contain whatever RAM has at startup
; Use 'r' (redraw) command if display looks corrupted
INITBUF PSHS    A,X
        LDX     #TEXTBUF
        LDA     #' '            ; Fill with spaces
INITB1  STA     ,X+
        CMPX    #BUFEND
        BLO     INITB1
        PULS    X,A,PC

; Load buffer from storage
; Check for 'VI' marker, copy if found, else do nothing
LOADBUF PSHS    A,B,X,Y
        ; Check magic marker at save location
        LDX     #SAVEBUF        ; X = $1200
        LDA     ,X+             ; Read first byte, X now $1201
        CMPA    #'V'            ; Is it 'V'?
        BNE     LOADB1          ; No - skip load
        LDA     ,X+             ; Read second byte, X now $1202
        CMPA    #'I'            ; Is it 'I'?
        BNE     LOADB1          ; No - skip load

        ; Valid 'VI' marker found - copy 1840 bytes from X to TEXTBUF
        ; X is now at $1202 (first data byte after 'VI')
        LDY     #TEXTBUF        ; Y = $0800
        LDD     #1840           ; D = byte counter
LOADB2  LDA     ,X+             ; Copy byte from save area
        STA     ,Y+             ; To text buffer
        SUBD    #1              ; Decrement counter
        BNE     LOADB2          ; Continue until done

LOADB1  PULS    Y,X,B,A,PC

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
SETCMD  PSHS    A,X
        CLR     MODE
        ; ESC was echoed by ASSIST09, send BS to erase it
        LDA     #BS
        LBSR    PUTCHR
        ; Update status line
        LBSR    UPDSTATUS
        PULS    X,A,PC

; Set insert mode
SETINS  PSHS    A
        LDA     #INSMODE
        STA     MODE
        ; Update status line
        LBSR    UPDSTATUS
        PULS    A,PC

; Update status line (row 1)
UPDSTATUS PSHS  A,X
        ; Save current cursor position
        PSHS    A,B
        LDA     CURX
        LDB     CURY
        PSHS    A,B

        ; Position cursor at row 1, column 1 for status line
        LDA     #ESC
        LBSR    PUTCHR
        LEAX    STATPOS,PCR
        LBSR    PRINT

        ; Print mode
        LDB     MODE
        BNE     UPDST1
        ; Command mode
        LEAX    CMDMSG,PCR
        LBSR    PRINT
        BRA     UPDST2
UPDST1  ; Insert mode
        LEAX    INSMSG,PCR
        LBSR    PRINT

UPDST2  ; Restore cursor position
        PULS    B,A             ; Get saved CURY, CURX
        STB     CURY
        STA     CURX
        PULS    B,A
        LBSR    UPDCUR          ; Restore cursor to text area
        PULS    X,A,PC

STATPOS FCB     '[,'1,';,'1,'H,0        ; Position to row 1, col 1
CMDMSG  FCC     "-- COMMAND --"
        FCB     ESC,'[,'K,0             ; Clear to end of line
INSMSG  FCC     "-- INSERT --"
        FCB     ESC,'[,'K,0             ; Clear to end of line

; Insert character at cursor position
; Note: ASSIST09's INCHNP already echoes characters, so we don't echo here
INSCHAR PSHS    A,X,B
        LBSR    GETBUFPOS       ; X = buffer position
        STA     ,X              ; Store character

        ; Auto-save to SAVEBUF after every character
        LBSR    AUTOSAVE

        ; Check if we're at the right edge (column 79)
        LDB     CURX
        CMPB    #COLS-1
        BHS     INSCH1          ; At edge - don't advance

        ; Not at edge - just advance cursor
        LBSR    MVRIGHT         ; Move cursor right in buffer
        PULS    B,X,A,PC

INSCH1  ; At right edge - stay at same position
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
DOBACKSP PSHS   A,X,B
        ; Check if at (0,0) - can't backspace
        LDA     CURX
        BNE     DOBK1           ; Not at left edge
        LDA     CURY
        BEQ     DOBK2           ; At (0,0) - do nothing

DOBK1   ; Not at (0,0) - process backspace
        ; Check if at left edge of a line
        LDA     CURX
        BNE     DOBK3           ; Not at left edge - simple case

        ; At left edge - move to end of previous line
        LDA     #COLS-1
        STA     CURX
        LBSR    MVUP
        BRA     DOBK4

DOBK3   ; Simple case - just move left
        LBSR    MVLEFT

DOBK4   ; Erase character at current position
        LBSR    GETBUFPOS       ; Get buffer position
        LDA     #' '            ; Replace with space in buffer
        STA     ,X

        ; Auto-save after backspace
        LBSR    AUTOSAVE

        ; Erase character on screen: BS, space, BS
        LDA     #BS             ; Send backspace
        LBSR    PUTCHR
        LDA     #' '            ; Space
        LBSR    PUTCHR
        LDA     #BS             ; Backspace again
        LBSR    PUTCHR

DOBK2   PULS    B,X,A
        LBRA    MAIN            ; Go back to main loop

; =========================================
; Save/Quit Commands
; =========================================

; Auto-save buffer to SAVEBUF (silent, no user feedback)
; This runs after every character insert/delete to keep SAVEBUF current
AUTOSAVE PSHS   A,X,Y
        ; Write magic marker 'VI'
        LDY     #SAVEBUF
        LDA     #'V'
        STA     ,Y+
        LDA     #'I'
        STA     ,Y+

        ; Copy text buffer to save area
        LDX     #TEXTBUF
AUTOS1  LDA     ,X+
        STA     ,Y+
        CMPX    #BUFEND
        BLO     AUTOS1

        PULS    Y,X,A,PC

CMDWRITE ; Write (save) - copy text buffer to save area silently
        PSHS    A,X,Y

        ; Erase echoed 'w'
        LDA     #BS
        LBSR    PUTCHR

        ; Write magic marker 'VI'
        LDY     #SAVEBUF
        LDA     #'V'
        STA     ,Y+
        LDA     #'I'
        STA     ,Y+

        ; Copy text buffer to save area
        LDX     #TEXTBUF
CMDWR1  LDA     ,X+
        STA     ,Y+
        CMPX    #BUFEND
        BLO     CMDWR1

        PULS    Y,X,A
        LBRA    MAIN            ; Back to main loop

CMDQUIT ; Quit to ASSIST09
        LDA     #BS             ; Erase echoed 'q'
        LBSR    PUTCHR
        LBSR    CLRSCR          ; Clear screen and home cursor
        SWI                     ; Return to monitor
        FCB     MONITR          ; Function 8: Enter ASSIST09 monitor

; =========================================
; Data Section
; =========================================

        END
