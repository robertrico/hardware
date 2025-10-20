        org $400
        jmp start       ; Jump over subroutine

; Print string subroutine (like in test09.asm)
outs    ldb ,x+         ; Get character
        beq done1       ; If zero, done
        jsr 3           ; Call monitor putchar (address 3)
        bra outs        ; Loop
done1   rts

; Main program
start   ldx #message    ; Point to message
        bsr outs        ; Call print subroutine
        swi             ; Return to monitor

message fcc "Hello 6809!"
        fcb 13,10,0     ; CR, LF, null terminator