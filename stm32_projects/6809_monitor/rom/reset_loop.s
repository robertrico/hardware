; 6809 Test Program with Register Operations
; This program performs visible register operations in a loop
; to help verify 6809 processor operation
; Generates a full 32KB ROM image for AT28C256 or similar EEPROM

        ORG     $8000           ; Start of 32KB ROM (mapped to CPU address $8000-$FFFF)

        ; Fill initial ROM space with zeros
        FILL    $00,$E000-$8000 ; Fill from $8000 to $E000 with zeros

        ORG     $E000           ; Our actual code starts here

RESET:  
        ; Initialize stack pointer (optional but good practice)
        LDS     #$7FFF          ; Set stack to top of RAM (adjust for your system)
        
MAIN:   
        ; Load easily identifiable values into registers
        LDA     #$AA            ; Load A register with 0xAA (10101010 binary)
        LDB     #$55            ; Load B register with 0x55 (01010101 binary)
        LDX     #$1234          ; Load X register with 0x1234
        LDY     #$ABCD          ; Load Y register with 0xABCD
        
        ; Perform some operations to see activity
        INCA                    ; Increment A (AA -> AB)
        DECB                    ; Decrement B (55 -> 54)
        LEAX    1,X             ; Add 1 to X (1234 -> 1235)
        LEAY    -1,Y            ; Subtract 1 from Y (ABCD -> ABCC)
        
        ; Transfer between registers for more bus activity
        TFR     A,B             ; Transfer A to B
        EXG     X,Y             ; Exchange X and Y
        
        ; Store and load from memory to create memory access patterns
        STA     $8100           ; Store A at a known location
        LDB     $8100           ; Load it back into B
        
        ; Jump back to main loop
        JMP     MAIN            ; Continue the loop
        
        ; Fill remaining space with zeros
        FILL    $00,$FFF0-*     ; Fill with zeros until interrupt vectors

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