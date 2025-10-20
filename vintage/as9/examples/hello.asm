; Hello World Data Example
; Demonstrates storing strings in ROM

        ORG     $C000

START   LDX     #MSG            ; Point to message
LOOP    LDA     ,X+             ; Load character
        BEQ     DONE            ; If zero, done
        JSR     PUTCHAR         ; Output it (placeholder)
        BRA     LOOP            ; Next char

DONE    SWI                     ; Stop

; Placeholder for character output
PUTCHAR RTS

; Message data in ROM
MSG     FCC     "HELLO WORLD"
        FCB     0               ; Null terminator

; Reset vector
        ORG     $FFFE
        FDB     START

        END
