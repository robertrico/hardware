; LED Blinker for 6809
; Toggles bit 0 of port $4000
; Perfect for testing your PCB!

        ORG     $C000           ; 16KB ROM starts at $C000

; Power-on initialization
START   LDS     #$0200          ; Set stack pointer to $0200
        LDA     #$01            ; Start with bit 0 set

; Main loop - toggle LED forever
BLINK   STA     $4000           ; Send to output port
        BSR     DELAY           ; Wait a bit
        EORA    #$01            ; Toggle bit 0
        BRA     BLINK           ; Do it again

; Delay subroutine (~65535 loops)
DELAY   PSHS    X               ; Save X
        LDX     #$FFFF          ; Max count
DLOOP   LEAX    -1,X            ; Decrement X
        BNE     DLOOP           ; Loop if not zero
        PULS    X               ; Restore X
        RTS                     ; Return

; 6809 Reset Vector - CPU reads this on power-up
        ORG     $FFFE           ; Reset vector location
        FDB     START           ; Jump to START when powered on

        END
