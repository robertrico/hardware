; Hello World Data Example
; For ASSIST09 - loads into RAM

        ORG     $0100           ; Start in RAM (safe area after zero page)

; ASSIST09 SWI function codes
OUTCH   EQU     1               ; Output character from A register
PCRLF   EQU     6               ; Output CR/LF

START   LDX     #MSG            ; Point to message
LOOP    LDA     ,X+             ; Load character
        BEQ     DONE            ; If zero, done
        SWI                     ; Call ASSIST09
        FCB     OUTCH           ; Function: output character in A
        BRA     LOOP            ; Next char

DONE    SWI                     ; Call ASSIST09
        FCB     PCRLF           ; Output newline
        SWI                     ; Return to monitor
        FCB     8               ; Function 8: enter monitor

; Message data
MSG     FCC     "HELLO WORLD"
        FCB     0               ; Null terminator

        END
