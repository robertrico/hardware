; ASSIST09 Hello World
; Project: assist_hello
; Description: Demonstrates proper ASSIST09 SWI function usage
;
; This program loads into RAM and uses ASSIST09's SWI-based I/O functions
; to output "HELLO WORLD" to the console.

; =========================================
; ASSIST09 SWI Function Codes
; =========================================
; These functions are called via: SWI / FCB <function_code>

INCHNP  EQU     0               ; Input character (no parity) -> A
OUTCH   EQU     1               ; Output character from A
PDATA1  EQU     2               ; Output string (no CR/LF)
PDATA   EQU     3               ; Output CR/LF then string
OUT2HS  EQU     4               ; Output 2 hex digits from A
OUT4HS  EQU     5               ; Output 4 hex digits from D
PCRLF   EQU     6               ; Output CR/LF
SPACE   EQU     7               ; Output space
MONITR  EQU     8               ; Return to monitor

; =========================================
; Code Start
; =========================================
        ORG     $0100           ; Load into RAM (safe area)

START   LDX     #MSG            ; Point X to message string

LOOP    LDA     ,X+             ; Load character, increment pointer
        BEQ     DONE            ; If zero, we're done
        SWI                     ; Call ASSIST09
        FCB     OUTCH           ; Function 1: output character
        BRA     LOOP            ; Next character

DONE    SWI                     ; Call ASSIST09
        FCB     PCRLF           ; Function 6: output newline
        LDA     #1              ; A=1: skip startup message
        SWI                     ; Return to monitor
        FCB     MONITR          ; Function 8: back to ASSIST09

; =========================================
; Data Section
; =========================================

MSG     FCC     "HELLO WORLD"
        FCB     0               ; Null terminator

        END
