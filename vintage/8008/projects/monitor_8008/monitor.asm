; Intel 8008 Monitor Program
; Interactive terminal monitor with command processing
;
; Commands:
;   H - Print "Hello, World!"
;   ? - Print help
;   Q - Quit (halt)
;
; This program demonstrates real interactive I/O where the 8008
; simulation WAITS for your input!

.8008

; Reset vector
.org 0x0000
        jmp MAIN

;=============================================================================
; Main Program
;=============================================================================
.org 0x0100
MAIN:
        ; Print banner
        mvi h, (BANNER >> 8) & 0xFF
        mvi l, BANNER & 0xFF
        call PRINT_STRING
        jmp MONITOR_LOOP ; Jump to correct monitor loop

; Note: Old MONITOR_LOOP code removed - was incomplete
; Jump directly to MONITOR_LOOP from MAIN

MONITOR_LOOP:
        ; Print prompt
        mvi h, (PROMPT >> 8) & 0xFF
        mvi l, PROMPT & 0xFF
        call PRINT_STRING

        ; Read command
        in 2                ; Port 2 - BLOCKS for input
        mov b, a            ; Save in B

        ; Filter out newlines/carriage returns - ignore and re-prompt
        cpi 0x0A            ; Check for LF (newline)
        jz MONITOR_LOOP
        cpi 0x0D            ; Check for CR (carriage return)
        jz MONITOR_LOOP

        ; Echo the actual command character
        out 8
        mvi a, 0x0D
        out 8
        mvi a, 0x0A
        out 8

        ; Process command (now in B)
        mov a, b

        ; Check for 'H' or 'h' (0x48 or 0x68)
        cpi 0x48
        jz CMD_HELLO
        cpi 0x68
        jz CMD_HELLO

        ; Check for '?' (0x3F)
        cpi 0x3F
        jz CMD_HELP

        ; Check for 'Q' or 'q' (0x51 or 0x71)
        cpi 0x51
        jz CMD_QUIT
        cpi 0x71
        jz CMD_QUIT

        ; Unknown command
        mvi h, (UNKNOWN >> 8) & 0xFF
        mvi l, UNKNOWN & 0xFF
        call PRINT_STRING
        jmp MONITOR_LOOP

CMD_HELLO:
        mvi h, (HELLO_MSG >> 8) & 0xFF
        mvi l, HELLO_MSG & 0xFF
        call PRINT_STRING
        jmp MONITOR_LOOP

CMD_HELP:
        mvi h, (HELP_MSG >> 8) & 0xFF
        mvi l, HELP_MSG & 0xFF
        call PRINT_STRING
        jmp MONITOR_LOOP

CMD_QUIT:
        mvi h, (GOODBYE >> 8) & 0xFF
        mvi l, GOODBYE & 0xFF
        call PRINT_STRING
        hlt

;=============================================================================
; Subroutine: Print null-terminated string
; Input: H:L = pointer to string
; Modifies: A, H:L
;=============================================================================
PRINT_STRING:
        mov a, m            ; Load character
        cpi 0x00            ; Check for null
        rz                  ; Return if null

        out 8               ; Output to port 0

        inr l               ; Increment pointer (low byte only)
        jnz PRINT_STRING    ; If didn't wrap, continue

        inr h               ; Increment high byte
        jmp PRINT_STRING

;=============================================================================
; String Data in ROM (placed after code to avoid overlap)
;=============================================================================
.org 0x0200
BANNER:     .ascii "8008 Monitor v1.0"
            .dc8 0x0D, 0x0A
            .ascii "Type ? for help"
            .dc8 0x0D, 0x0A, 0x00

PROMPT:     .ascii "8008> "
            .dc8 0x00

HELP_MSG:   .ascii "Commands:"
            .dc8 0x0D, 0x0A
            .ascii "  H - Hello World"
            .dc8 0x0D, 0x0A
            .ascii "  ? - Help"
            .dc8 0x0D, 0x0A
            .ascii "  Q - Quit"
            .dc8 0x0D, 0x0A, 0x00

HELLO_MSG:  .ascii "Hello, World!"
            .dc8 0x0D, 0x0A, 0x00

UNKNOWN:    .ascii "Unknown command"
            .dc8 0x0D, 0x0A, 0x00

GOODBYE:    .ascii "Goodbye!"
            .dc8 0x0D, 0x0A, 0x00

.end
