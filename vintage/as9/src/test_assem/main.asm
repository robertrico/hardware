; 6809 Monitor Program - Direct Hardware Access
; Version: 1.0.0
; Description: Monitor with direct ACIA control

; =========================================
; Constants
; =========================================
STACK   EQU     $6FCF           ; Stack at top of user space
ACIA    EQU     $BE00           ; ACIA base address (correct for this system)
ACIACTL EQU     ACIA            ; Control/Status register
ACIADAT EQU     ACIA+1          ; Data register
CR      EQU     $0D             ; Carriage return
LF      EQU     $0A             ; Line feed
ESC     EQU     $1B             ; Escape character
BS      EQU     $08             ; Backspace
BUFLEN  EQU     80              ; Input buffer length

; Variables in RAM
INBUF   EQU     $0500           ; Input buffer location
BUFPTR  EQU     $0580           ; Buffer pointer

; =========================================
; Code Start
; =========================================
        ORG     $0400           ; ROM starts here

START   LDS     #STACK          ; Initialize stack pointer
        
        ; Test output first
        LDA     #'T
        LBSR    PUTCHR          ; Use long branch
        LDA     #'E
        LBSR    PUTCHR
        LDA     #'S
        LBSR    PUTCHR
        LDA     #'T
        LBSR    PUTCHR
        LBSR    NEWLINE
        
        LBSR    BANNER          ; Display banner
        
; =========================================
; Main Command Loop
; =========================================
MAIN    LBSR    PROMPT          ; Display prompt (use long branch)
        LBSR    GETLINE         ; Get complete line input
        LBSR    PARSE           ; Parse and execute command
        BRA     MAIN            ; Loop back

; =========================================
; Get Line Input
; =========================================
GETLINE PSHS    X,B
        LDX     #INBUF          ; Point to input buffer
        CLRB                    ; Character count = 0
        
GETLN1  LBSR    GETCHR          ; Get a character (use long branch)
        CMPA    #CR             ; Enter pressed?
        BEQ     GETLEND         ; Yes, done
        
        CMPA    #BS             ; Backspace?
        BNE     GETLN2
        TSTB                    ; Anything to delete?
        BEQ     GETLN1          ; No, ignore
        DECB                    ; Yes, decrement count
        LEAX    -1,X            ; Back up pointer
        LBSR    PUTCHR          ; Echo backspace
        LDA     #$20            ; Space to erase (use hex)
        LBSR    PUTCHR
        LDA     #BS             ; Another backspace
        LBSR    PUTCHR
        BRA     GETLN1
        
GETLN2  CMPB    #BUFLEN-1       ; Buffer full?
        BHS     GETLN1          ; Yes, ignore character
        
        CMPA    #$20            ; Control character?
        BLO     GETLN1          ; Yes, ignore
        
        STA     ,X+             ; Store in buffer
        INCB                    ; Increment count
        LBSR    PUTCHR          ; Echo character
        BRA     GETLN1
        
GETLEND CLR     ,X              ; Null terminate
        LBSR    NEWLINE         ; Output newline
        PULS    B,X
        RTS

; =========================================
; Parse Command
; =========================================
PARSE   PSHS    A,X
        LDX     #INBUF          ; Point to input buffer
        LDA     ,X              ; Get first character
        
        ; Skip if empty line
        BEQ     PARSEND
        
        ; Check commands
        CMPA    #'?             ; Help?
        BNE     PARSE1
        LBSR    HELP
        BRA     PARSEND
        
PARSE1  CMPA    #'Q             ; Quit?
        BNE     PARSE2
        BRA     QUIT            ; Use short branch
        
PARSE2  CMPA    #'q             ; Lowercase quit?
        BNE     PARSE3
        BRA     QUIT            ; Use short branch
        
PARSE3
        
        ; Unknown command
        LEAX    ERRMSG,PCR
        LBSR    PRINT
        
PARSEND PULS    X,A             ; Reverse order of PSHS A,X
        RTS

; =========================================
; Quit to ASSIST09
; =========================================
QUIT    
        LEAX    QUITMSG,PCR
        LBSR    PRINT
        
        ; Clean setup before returning to ASSIST09
        ; Set stack to where ASSIST09 expects it
        LDS     #$7000          ; ASSIST09's stack area
        
        ; Clear all registers to known state
        CLRA
        CLRB
        TFR     D,X
        TFR     D,Y
        TFR     D,U
        TFR     A,DP            ; DP = 0
        
        ; Try monitor entry with clean state
        SWI                     
        FCB     8               ; MONITR function
        
        ; Last resort - direct jump
        JMP     $F800

; =========================================
; Direct Hardware I/O Routines
; =========================================

; Get character from ACIA (blocking)
GETCHR  PSHS    B               ; Save B
        ; Small delay to let ACIA stabilize
        NOP
        NOP
        
GETCH1  LDB     ACIACTL         ; Check status
        ANDB    #$01            ; RX data ready?
        BEQ     GETCH1          ; No, keep waiting
        LDA     ACIADAT         ; Get the character
        ANDA    #$7F            ; Strip parity
        PULS    B
        RTS

; Put character to ACIA
PUTCHR  PSHS    B               ; Save B
PUTCH1  LDB     ACIACTL         ; Check status
        ANDB    #$02            ; TX ready?
        BEQ     PUTCH1          ; No, wait
        STA     ACIADAT         ; Send character
        PULS    B
        RTS

; Print String (X points to string, null terminated) - MOVED HERE
PRINT   PSHS    A               ; Save A
PRLOOP  LDA     ,X+             ; Get character
        BEQ     PREND           ; Exit if null
        BSR     PUTCHR          ; Now close enough for BSR!
        BRA     PRLOOP          ; Continue
PREND   PULS    A
        RTS

; Output newline - MOVED HERE  
NEWLINE PSHS    A
        LDA     #$0D            ; CR
        BSR     PUTCHR
        LDA     #$0A            ; LF
        BSR     PUTCHR
        PULS    A
        RTS

; =========================================
; Subroutines
; =========================================

; Clear Screen
CLS     PSHS    A,X             ; Save registers
        LEAX    CLSSEQ,PCR      ; Point to clear screen sequence
CLSLP   LDA     ,X+             ; Get next character
        BEQ     CLSEND          ; Exit if null terminator
        BSR     PUTCHR          ; Output character
        BRA     CLSLP           ; Continue loop
CLSEND  PULS    A,X
        RTS

; Display Banner
BANNER  PSHS    A,X             ; Save registers
        LEAX    BANMSG,PCR      ; Point to banner message
        LBSR    PRINT           ; Use long branch
        PULS    A,X
        RTS

; Display Command Prompt
PROMPT  PSHS    A,X             ; Save registers
        LEAX    PRMMSG,PCR      ; Point to prompt
        LBSR    PRINT           ; Use long branch
        PULS    A,X
        RTS

; Display Help
HELP    PSHS    A,X             ; Save registers
        LEAX    HLPMSG,PCR      ; Point to help message
        LBSR    PRINT           ; Use long branch
        PULS    A,X
        RTS

; =========================================
; Data Section
; =========================================

; Clear screen sequence
CLSSEQ  FCB     ESC,'[,'2,'J    ; ANSI clear screen
        FCB     ESC,'[,'H       ; ANSI home cursor
        FCB     0               ; Null terminator

; Banner message
BANMSG  FCB     CR,LF
        FCC     "================================"
        FCB     CR,LF
        FCC     "  6809 Monitor v1.0.0 (Direct)"
        FCB     CR,LF
        FCC     "================================"
        FCB     CR,LF,CR,LF
        FCB     0

; Prompt message
PRMMSG  FCC     "6809> "
        FCB     0

; Help message
HLPMSG  FCB     CR,LF
        FCC     "Commands:"
        FCB     CR,LF
        FCC     "  ? - Display this help"
        FCB     CR,LF
        FCC     "  Q - Quit to ASSIST09"
        FCB     CR,LF
        FCC     "  M - Memory examine/modify (not implemented)"
        FCB     CR,LF
        FCC     "  G - Go/execute (not implemented)"
        FCB     CR,LF
        FCC     "  R - Register display (not implemented)"
        FCB     CR,LF,CR,LF
        FCB     0

; Error message
ERRMSG  FCC     "Unknown command. Type ? for help"
        FCB     CR,LF
        FCB     0

; Quit message
QUITMSG FCC     "Returning to ASSIST09..."
        FCB     CR,LF
        FCB     0

        END
