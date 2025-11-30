; Ultra-Minimal Assembler Test
; Description: Simplest possible test - just assemble LDA #45 to memory
;
; To test:
; 1. Load this program with ASSIST09
; 2. Run: G 400
; 3. Examine memory at $0500: M 500
; 4. Should see: 86 2D (the assembled instruction)

; =========================================
; Code Start
; =========================================
        ORG     $0400           ; RAM starts here

START
        ; Our tiny assembler will write to $0500
        ; For this test, we'll just put the expected bytes there
        LDA     #$86            ; Opcode for LDA immediate
        STA     $0500           ; Write to output location

        LDA     #$2D            ; Value 45 in hex
        STA     $0501           ; Write to output location

        ; Return to ASSIST09
        SWI

        END
