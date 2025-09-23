; 6809 Reset Vector Loop Program
; This simple program demonstrates the minimal boot code for a 6809 processor
; It jumps to itself in an infinite loop at the reset vector
; Generates a full 32KB ROM image for AT28C256 or similar EEPROM

        ORG     $8000           ; Start of 32KB ROM (mapped to CPU address $8000-$FFFF)

        ; Fill initial ROM space with zeros
        FILL    $00,$E000-$8000 ; Fill from $8000 to $E000 with zeros

        ORG     $E000           ; Our actual code starts here

RESET:  JMP     RESET           ; Infinite loop - jump to itself
                                ; JMP is a 3-byte instruction: opcode + 16-bit address

        ; Fill space between code and vectors with $FF
        FILL    $FF,$FFF0-*     ; Fill with $FF until interrupt vectors

        ; 6809 Interrupt and Reset Vectors (at top of memory)
        ORG     $FFF0
        FDB     RESET           ; Reserved
        FDB     RESET           ; SWI3
        FDB     RESET           ; SWI2  
        FDB     RESET           ; FIRQ
        FDB     RESET           ; IRQ
        FDB     RESET           ; SWI
        FDB     RESET           ; NMI
        FDB     RESET           ; RESET vector at $FFFE-$FFFF

        END