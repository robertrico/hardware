; Simple test program to verify execution
        ORG     $0400

START   
        ; Just output a single character using ASSIST09 SWI
        LDA     #'X
        SWI
        FCB     1               ; OUTCH
        
        ; Return to ASSIST09
        SWI
        FCB     0               ; Return to monitor
        
        END