; ACIA Direct Hardware Test
; Project: test_acia
; Description: Tests basic execution by writing directly to ACIA hardware

        ORG     $0100

ACIAS   EQU     $BE00
ACIAD   EQU     $BE01

START   LDA     #'!'
WAIT    LDB     ACIAS
        ANDB    #$02
        BEQ     WAIT
        STA     ACIAD
        SWI
        FCB     8               ; Function 8: Return to monitor

        END
