; Minimal 6809 ROM Template
; Start here for your own projects

        ORG     $C000           ; ROM start address

; Your initialization code
RESET   LDS     #$0200          ; Set up stack
        ; Add your init code here

; Your main program
MAIN    ; Your code here
        BRA     MAIN            ; Loop forever (or not!)

; Your subroutines go here

; Reset vector (required!)
        ORG     $FFFE
        FDB     RESET

        END
