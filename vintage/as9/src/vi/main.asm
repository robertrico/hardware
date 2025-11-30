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
; $0200-$03FF  Reserved for future use (512 bytes)
; $0400-$0FFF  Program code (3KB max - currently ~1.3KB)
; $1000-$173F  Text buffer (1840 bytes = 80×23)
; $1740-$174F  Editor state variables (16 bytes)
; $1750-$1E7F  SAVEBUF slot 0 (1842 bytes with 'VI' marker)
; $1E80-$25AF  SAVEBUF slot 1 (1842 bytes)
; $25B0-$2CDF  SAVEBUF slot 2 (1842 bytes)
; $2CE0-$340F  SAVEBUF slot 3 (1842 bytes)
; $3410-$3B3F  SAVEBUF slot 4 (1842 bytes)
; $3B40-$426F  SAVEBUF slot 5 (1842 bytes)
; $4270-$499F  SAVEBUF slot 6 (1842 bytes)
; $49A0-$50CF  SAVEBUF slot 7 (1842 bytes)
; $50D0-$57FF  SAVEBUF slot 8 (1842 bytes)
; $5800-$5F2F  SAVEBUF slot 9 (1842 bytes)
; $5F30-$6FCF  Free space (4256 bytes)
; $6FD0-$6FDC  DISASSEMBLER variables (reserved by ASSIST09)
; $6FE0-$6FFC  TRACE variables (reserved by ASSIST09)
; $7000-$7051  ASSIST09 workspace (DO NOT USE)
; $F800-$FFFF  ASSIST09 ROM

STACK   EQU     $01FF           ; Stack pointer (grows down from $01FF to $0100)

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
BUFSIZ  EQU     1840            ; Text buffer size (COLS * ROWS)

; =========================================
; Memory Layout
; =========================================
; Text buffer (1840 bytes at page boundary for clean addressing)
TEXTBUF EQU     $1000           ; Text buffer start (80×23 = 1840 bytes)
BUFEND  EQU     $1730           ; Text buffer end ($1000 + $730)

; Editor state variables (20 bytes total, $1740-$1753)
CURX    EQU     $1740           ; Cursor X position (0-79)
CURY    EQU     $1741           ; Cursor Y position (0-79)
MODE    EQU     $1742           ; 0=command, 1=insert, 2=colon
BSKEY   EQU     $1743           ; Which key triggered backspace (BS or DEL)
CMDBUF  EQU     $1744           ; Command buffer for : commands (10 bytes)
CMDLEN  EQU     $174E           ; Length of command in buffer (1 byte)
NUMBUF  EQU     $174F           ; Number buffer for PUTNUM (4 bytes, ends at $1752)
        ; Gap: $1753 reserved for alignment

; File save slots (10 slots, each 1842 bytes with 2-byte 'VI' marker + 1840 data)
; Each slot is $732 bytes (1842 decimal)
SAVEBUF EQU     $1754           ; Save slot 0 ($1754-$1E85)
SLOT1   EQU     $1E86           ; Save slot 1 ($1E86-$25B7)
SLOT2   EQU     $25B8           ; Save slot 2 ($25B8-$2CE9)
SLOT3   EQU     $2CEA           ; Save slot 3 ($2CEA-$341B)
SLOT4   EQU     $341C           ; Save slot 4 ($341C-$3B4D)
SLOT5   EQU     $3B4E           ; Save slot 5 ($3B4E-$427F)
SLOT6   EQU     $4280           ; Save slot 6 ($4280-$49B1)
SLOT7   EQU     $49B2           ; Save slot 7 ($49B2-$50E3)
SLOT8   EQU     $50E4           ; Save slot 8 ($50E4-$5815)
SLOT9   EQU     $5816           ; Save slot 9 ($5816-$5F47)

; Modes
CMDMODE EQU     0               ; Command mode
INSMODE EQU     1               ; Insert mode
COLONMODE EQU   2               ; Colon command mode

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

INIT1   ; No saved file - initialize with blank buffer
        LBSR    INITBUF         ; Clear text buffer with spaces
        LBSR    AUTOSAVE        ; Save the blank buffer

INIT2   LBSR    CLRSCR          ; Clear screen

        ; Position cursor at (0,0)
        CLR     CURX
        CLR     CURY

        ; Start in COMMAND mode
        CLR     MODE            ; 0 = command mode
        CLR     CMDLEN          ; Initialize command buffer length

        ; Draw status line
        LBSR    UPDSTATUS

        ; Position cursor in text area
        LBSR    UPDCUR

; Main editor loop
MAIN    LBSR    GETCHR          ; Get character

        LDB     MODE            ; Check mode
        LBEQ    CMDMODE_        ; Command mode?
        CMPB    #INSMODE
        LBEQ    INSMODE_        ; Insert mode?
        CMPB    #COLONMODE
        LBEQ    COLONMODE_      ; Colon command mode?
        LBRA    MAIN            ; Unknown mode - ignore

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
        CMPA    #':             ; Start colon command
        LBEQ    GOCOLON
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

; Enter colon command mode
GOCOLON PSHS    A
        ; Don't erase the ':', we want to see it
        ; Initialize command buffer
        CLR     CMDLEN
        LDA     #COLONMODE
        STA     MODE
        LBSR    UPDSTATUS       ; Show : in status line
        PULS    A
        LBRA    MAIN

; Colon mode handling
COLONMODE_ CMPA #ESC           ; Escape = cancel command
        LBEQ    CANCELCMD
        CMPA    #CR             ; Enter = execute command
        LBEQ    EXECCMD
        CMPA    #BS             ; Backspace
        LBEQ    COLONBS
        CMPA    #DEL            ; Delete key
        LBEQ    COLONBS
        CMPA    #$20            ; Printable?
        LBLO    MAIN            ; Ignore control chars
        CMPA    #$7E
        LBHI    MAIN

        ; Add character to command buffer
        LBSR    ADDCMDCHAR
        LBRA    MAIN

; Add character to command buffer
ADDCMDCHAR PSHS A,B,X
        LDB     CMDLEN
        CMPB    #15             ; Buffer full?
        BHS     ADDCMD1         ; Yes, ignore

        ; Store character in buffer
        LDX     #CMDBUF
        ABX                     ; X = CMDBUF + CMDLEN
        STA     ,X              ; Store character
        INC     CMDLEN          ; Increment length

        ; Update status line to show new character
        LBSR    UPDSTATUS

ADDCMD1 PULS    X,B,A,PC

; Handle backspace in colon mode
COLONBS PSHS    A
        LDA     CMDLEN
        BEQ     COLBS1          ; Empty buffer - ignore
        DEC     CMDLEN          ; Remove last character
        LBSR    UPDSTATUS       ; Update display
COLBS1  PULS    A
        LBRA    MAIN

; Cancel colon command (ESC pressed)
CANCELCMD PSHS  A
        LDA     #BS             ; Erase ESC
        LBSR    PUTCHR
        LBSR    SETCMD          ; Back to command mode
        PULS    A
        LBRA    MAIN

; Execute colon command (CR pressed)
EXECCMD PSHS    A,B,X
        ; Parse and execute command in CMDBUF
        LDA     CMDLEN
        BEQ     EXECMD3         ; Empty - just return to command mode

        ; Check first character
        LDX     #CMDBUF
        LDA     ,X+

        CMPA    #'w             ; Write command
        BNE     EXECMD1
        LBSR    CMDWRITE
        BRA     EXECMD4

EXECMD1 CMPA    #'q             ; Quit command
        BNE     EXECMD2
        ; Quit doesn't return - clean up stack first
        PULS    A,B,X           ; Clean up EXECCMD's stack frame
        LBRA    CMDQUIT         ; Jump to quit (never returns)

EXECMD2 CMPA    #'n             ; New file command
        BNE     EXECMD3
        LBSR    CMDNEW
        BRA     EXECMD4

EXECMD3 ; Unknown command - ignore

EXECMD4 ; Return to command mode (without erasing - no ESC was pressed)
        LBSR    SETCMD0
        PULS    A,B,X,PC

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

        PULS    A,X,PC

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
PUTN2   CMPA    #0              ; Check if A is 0
        BEQ     PUTN3

        LBSR    DIVMOD          ; A = A/10, B = A%10

        ADDB    #'0             ; Convert remainder to ASCII
        STB     ,X              ; Store digit
        LEAX    -1,X            ; Move buffer pointer back

        BRA     PUTN2           ; Continue with quotient in A

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
SHOWB3  PULS    A,B,X,Y,PC

TEXTPOS FCB     '[,'2,';,'1,'H,0        ; Position to row 2, col 1

; Redraw entire screen from buffer
REDRAW  PSHS    A,B,X,Y
        LBSR    CLRSCR
        LBSR    UPDSTATUS       ; Draw status line
        LBSR    SHOWBUF         ; Draw text
        ; Don't reset cursor - preserve current position
        PULS    A,B,X,Y,PC

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
        PULS    A,X,PC

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

LOADB1  PULS    A,B,X,Y,PC

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
; Set command mode (erases echoed ESC character)
SETCMD  PSHS    A,X
        CLR     MODE
        CLR     CMDLEN          ; Clear command buffer
        ; ESC was echoed by ASSIST09, send BS to erase it
        LDA     #BS
        LBSR    PUTCHR
        ; Update status line
        LBSR    UPDSTATUS
        PULS    A,X,PC

; Set command mode without erasing (for use after colon commands)
SETCMD0 PSHS    A,X
        CLR     MODE
        CLR     CMDLEN          ; Clear command buffer
        ; Update status line
        LBSR    UPDSTATUS
        PULS    A,X,PC

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
        BEQ     UPDST0          ; Command mode
        CMPB    #INSMODE
        BEQ     UPDST1          ; Insert mode
        CMPB    #COLONMODE
        BEQ     UPDST2          ; Colon mode
        BRA     UPDST9          ; Unknown mode

UPDST0  ; Command mode
        LEAX    CMDMSG,PCR
        LBSR    PRINT
        BRA     UPDST9

UPDST1  ; Insert mode
        LEAX    INSMSG,PCR
        LBSR    PRINT
        BRA     UPDST9

UPDST2  ; Colon mode - show : and command buffer
        LDA     #':
        LBSR    PUTCHR

        ; Print command buffer (save B,X first since they're on stack)
        PSHS    B,X
        LDX     #CMDBUF
        LDB     CMDLEN
        BEQ     UPDST3          ; Empty buffer

UPDST2L LDA     ,X+
        LBSR    PUTCHR
        DECB
        BNE     UPDST2L

UPDST3  ; Clear to end of line
        PULS    B,X             ; Restore B,X (match PSHS order!)
        LDA     #ESC
        LBSR    PUTCHR
        LDA     #'[
        LBSR    PUTCHR
        LDA     #'K
        LBSR    PUTCHR

        ; In colon mode, leave cursor in status bar
        ; so ASSIST09 echoes go there, not to text area
        PULS    A,B             ; Get saved CURX, CURY (match PSHS order!)
        LDB     MODE
        CMPB    #COLONMODE
        BEQ     UPDST8          ; Stay in status bar for colon mode

        ; Not colon mode - restore cursor to text area
        STA     CURX
        STB     CURY
        PULS    A,B             ; Match PSHS A,B from line 649
        LBSR    UPDCUR          ; Restore cursor to text area
        PULS    A,X,PC          ; Match PSHS A,X from line 647

UPDST8  ; Colon mode - discard saved position and leave cursor in status bar
        PULS    A,B             ; Discard saved A,B (match PSHS order!)
        PULS    A,X,PC          ; Match PSHS A,X from line 647

UPDST9  ; Restore cursor position (for command/insert modes)
        PULS    A,B             ; Get saved CURX, CURY (match PSHS order!)
        STA     CURX
        STB     CURY
        PULS    A,B             ; Match PSHS A,B from line 649
        LBSR    UPDCUR          ; Restore cursor to text area
        PULS    A,X,PC          ; Match PSHS A,X from line 647

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

        ; Not at edge - advance cursor
        LBSR    MVRIGHT         ; Move cursor right in buffer
        LBSR    UPDCUR          ; Update screen cursor position
        PULS    B,X,A,PC

INSCH1  ; At right edge - stay at same position
        PULS    B,X,A,PC

; Handle newline in insert mode
DONEWLINE PSHS  A
        ; Move to start of next line in buffer
        CLR     CURX
        LBSR    MVDOWN

        ; Update screen cursor to match
        ; Note: ASSIST09 already echoed CR, so we just need to update position
        LBSR    UPDCUR

        PULS    A
        LBRA    MAIN

; Handle backspace in insert mode
DOBACKSP PSHS   A,X,B
        ; Save the keycode for later (to know if BS or DEL)
        STA     BSKEY           ; Save which key was pressed

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

        ; Handle screen update
        ; If DEL was pressed ($7F), ASSIST09 doesn't move cursor, so we need BS-space-BS
        ; If BS was pressed ($08), ASSIST09 moved cursor, so we need space-BS
        LDA     BSKEY           ; Get saved keycode
        CMPA    #DEL            ; Check what key was pressed
        BEQ     DOBK5           ; DEL needs full BS-space-BS

        ; BS key - ASSIST09 already moved cursor back
        LDA     #' '            ; Space to erase
        LBSR    PUTCHR
        LDA     #BS             ; Backspace to correct position
        LBSR    PUTCHR
        BRA     DOBK2

DOBK5   ; DEL key - ASSIST09 didn't move cursor
        LDA     #BS             ; Move cursor back
        LBSR    PUTCHR
        LDA     #' '            ; Space to erase
        LBSR    PUTCHR
        LDA     #BS             ; Backspace to correct position
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

        PULS    A,X,Y,PC

CMDWRITE ; Write (save) - copy text buffer to save area silently
        PSHS    A,X,Y

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

        PULS    A,X,Y,PC

CMDNEW  ; New file - clear text buffer with spaces
        PSHS    A,X
        LDX     #TEXTBUF
        LDA     #' '            ; Fill with spaces
CMDNEW1 STA     ,X+
        CMPX    #BUFEND
        BLO     CMDNEW1

        ; Reset cursor to (0,0)
        CLR     CURX
        CLR     CURY

        ; Auto-save the cleared buffer
        LBSR    AUTOSAVE

        ; NOTE: REDRAW disabled for debugging - use 'r' command to refresh screen
        ; LBSR    REDRAW
        ; LBSR    UPDCUR

        PULS    A,X,PC

CMDQUIT ; Quit to ASSIST09
        ; Clear screen and home cursor (fully inline to avoid any subroutine calls)
        LDA     #ESC
        SWI
        FCB     OUTCH
        LDA     #'[
        SWI
        FCB     OUTCH
        LDA     #'2
        SWI
        FCB     OUTCH
        LDA     #'J
        SWI
        FCB     OUTCH
        LDA     #ESC
        SWI
        FCB     OUTCH
        LDA     #'[
        SWI
        FCB     OUTCH
        LDA     #'H
        SWI
        FCB     OUTCH
        ; Return to ASSIST09
        SWI                     ; Return to monitor
        FCB     MONITR          ; Function 8: Enter ASSIST09 monitor

; =========================================
; Data Section
; =========================================

        END
