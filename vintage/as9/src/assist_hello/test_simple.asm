; Simple ACIA test - no ASSIST09 dependencies
; Writes directly to hardware to verify execution

        ORG     $0100

; ACIA addresses from ASSIST09 source (line 27: ACIA EQU $BE00)
ACIAS   EQU     $BE00           ; ACIA Status
ACIAD   EQU     $BE01           ; ACIA Data

START   LDA     #'!'            Test character
WAIT    LDB     ACIAS           ; Read status
        ANDB    #$02            ; Check TDRE (transmit data register empty)
        BEQ     WAIT            ; Wait until ready
        STA     ACIAD           ; Send character

DONE    SWI                     ; Return to ASSIST09 (plain SWI, no function code)

        END
