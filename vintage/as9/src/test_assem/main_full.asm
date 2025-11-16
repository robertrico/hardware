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
MAIN    BSR     PROMPT          ; Display prompt
        BSR     GETCHR          ; Get character (our own routine)
        
        ; Echo the character
        BSR     PUTCHR
        
        ; Process commands  
        CMPA    #'?             ; Help command?
        BNE     NOTHELP
        BSR     HELP            ; Display help
        BRA     MAIN            ; Back to prompt
        
NOTHELP CMPA    #CR             ; Just Enter pressed?
        BNE     NOTCR
        LDA     #LF             ; Send line feed
        BSR     PUTCHR
        BRA     MAIN            ; Back to prompt
        
NOTCR   ; Check for valid command characters
        CMPA    #$20            ; Control character?
        BLO     MAIN            ; Ignore it
        
        ; Unknown command - show error
        BSR     NEWLINE
        LEAX    ERRMSG,PCR
        BSR     PRINT
        
        BRA     MAIN            ; Loop back

; =========================================
; Direct Hardware I/O Routines
; =========================================

; Get character from ACIA (blocking)
GETCHR  PSHS    B               ; Save B
GETCH1  LDB     ACIACTL         ; Check status
        ANDB    #$01            ; RX data ready?
        BEQ     GETCH1          ; No, keep waiting
        LDA     ACIADAT         ; Get the character
        ANDA    #$7F            ; Strip parity
        PULS    B,PC            ; Restore and return

; Put character to ACIA
PUTCHR  PSHS    B               ; Save B
PUTCH1  LDB     ACIACTL         ; Check status
        ANDB    #$02            ; TX ready?
        BEQ     PUTCH1          ; No, wait
        STA     ACIADAT         ; Send character
        PULS    B,PC            ; Restore and return

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
CLSEND  PULS    A,X,PC          ; Restore and return

; Display Banner
BANNER  PSHS    A,X             ; Save registers
        LEAX    BANMSG,PCR      ; Point to banner message
        BSR     PRINT           ; Print it
        PULS    A,X,PC          ; Restore and return

; Display Command Prompt
PROMPT  PSHS    A,X             ; Save registers
        LEAX    PRMMSG,PCR      ; Point to prompt
        BSR     PRINT           ; Print it
        PULS    A,X,PC          ; Restore and return

; Display Help
HELP    PSHS    A,X             ; Save registers
        LEAX    HLPMSG,PCR      ; Point to help message
        BSR     PRINT           ; Print it
        PULS    A,X,PC          ; Restore and return

; Print String (X points to string, null terminated)
PRINT   PSHS    A               ; Save A
PRLOOP  LDA     ,X+             ; Get character
        BEQ     PREND           ; Exit if null
        BSR     PUTCHR          ; Output character
        BRA     PRLOOP          ; Continue
PREND   PULS    A,PC            ; Restore and return

; Output newline
NEWLINE PSHS    A
        LDA     #$0D            ; CR
        BSR     PUTCHR
        LDA     #$0A            ; LF
        BSR     PUTCHR
        PULS    A,PC

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
        FCC     "  M - Memory examine/modify"
        FCB     CR,LF
        FCC     "  G - Go (execute)"
        FCB     CR,LF
        FCC     "  R - Register display"
        FCB     CR,LF,CR,LF
        FCB     0

; Error message
ERRMSG  FCC     "Unknown command. Type ? for help"
        FCB     CR,LF
        FCB     0

        END