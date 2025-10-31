; Simple ADD test with RAM write
; Tests basic arithmetic and memory write operations
;
; Program: MVI A,5  MVI B,3  ADD B  MVI H,0x08  MVI L,0x00  MOV M,A  HLT
; Expected result: RAM[0x0800] = 0x08

.8008

.org 0x0000
        mvi a, 0x05         ; A = 5
        mvi b, 0x03         ; B = 3
        add b               ; A = A + B = 8
        mvi h, 0x08         ; H = 0x08
        mvi l, 0x00         ; L = 0x00 (HL = 0x0800)
        mov m, a            ; RAM[0x0800] = A (= 8)
        hlt                 ; Halt

.end
