; Intel 8008 Hello World I/O Program
;
; Purpose: Outputs "Hello, World!" to console via I/O ports
; Demonstrates 8008 I/O instructions (OUT)
;
; I/O Port Map:
;   Port 0: Console TX Data (write) - Write character to output
;   Port 1: Console TX Status (read) - Check if ready (always 1)
;
; Program Flow:
;   1. Initialize H:L pointer to string start (0x00C8)
;   2. Loop through string:
;      - Load character from [H:L]
;      - Check for null terminator (0x00)
;      - Output character to port 0
;      - Increment pointer
;   3. Halt when done
;

.8008

; Reset vector - jump to main program
.org 0x0000
        jmp MAIN            ; Jump to main program at 0x0100

; String data at 0x00C8 (200 decimal)
.org 0x00C8
HELLO_STR: .ascii "Hello, World!"
           .dc8 0x0A        ; Newline (LF)
           .dc8 0x00        ; Null terminator

; Main program
.org 0x0100
MAIN:
        ; Initialize H:L register pair to point to string
        mvi h, 0x00         ; LHI 0x00 - High byte of address
        mvi l, 0xC8         ; LLI 0xC8 - Low byte of address (200 decimal)

; Print loop: Output each character until null terminator
PRINT_LOOP:
        ; Load character from memory [H:L] into accumulator
        mov a, m            ; LAM - Load A from memory[H:L]

        ; Check for null terminator (0x00)
        cpi 0x00            ; CPI 0x00 - Compare immediate with 0
        jz DONE             ; JZ DONE - Jump if zero (found terminator)

        ; Output character to console (Port 8)
        ; Note: 8008 OUT instruction always outputs from accumulator
        ; RR field in opcode is part of port address, not source register
        ; Port 8 = RRMMM where RR=01, MMM=000 (first group of 8 OUT ports)
        out 8               ; OUT 8 - Output A to port 8 (maps to logical port 0)

        ; Increment pointer (L only, string is small)
        inr l               ; INR L - Increment L register

        ; Continue loop
        jmp PRINT_LOOP      ; JMP PRINT_LOOP - Jump back to loop

; Done: Halt the processor
DONE:
        hlt                 ; HLT - Halt processor

.end
