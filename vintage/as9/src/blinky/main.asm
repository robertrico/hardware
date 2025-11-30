* Minimal 6809 Template
* Project: blinky
* Description: [DESCRIBE YOUR PROJECT]

* =========================================
* Constants
* =========================================
STACK   equ     $0200           * Stack pointer location

* =========================================
* Peripheral Memory Map ($8000)
* =========================================
* The peripheral at $8000 is a read/write register:
*   Write: High nibble controls 4 outputs (accent colors)
*   Read:  Low nibble reads 4-position DIP switch
*
* Bit layout:
*   7   6   5   4   3   2   1   0
*   |   |   |   |   |   |   |   |
*   +---+---+---+---+---+---+---+---+
*   |OUT4|OUT3|OUT2|OUT1|SW4|SW3|SW2|SW1|
*   +---+---+---+---+---+---+---+---+
*   |<-- Write -->|  |<-- Read -->|
*
PERIPH  equ     $8000           * Peripheral base address

* Output enable bits (write to high nibble)
OUT1    equ     %00010000       * $10 - Enable output 1
OUT2    equ     %00100000       * $20 - Enable output 2
OUT3    equ     %01000000       * $40 - Enable output 3
OUT4    equ     %10000000       * $80 - Enable output 4

* DIP switch read masks (read from low nibble)
SW1     equ     %00000001       * $01 - DIP switch 1
SW2     equ     %00000010       * $02 - DIP switch 2
SW3     equ     %00000100       * $04 - DIP switch 3
SW4     equ     %00001000       * $08 - DIP switch 4
SWMASK  equ     %00001111       * $0F - Mask for all switches

* ASSIST09 SWI function codes
PCRLF   equ     6               * Print CR/LF
MONITR  equ     8               * Enter ASSIST09 monitor

* =========================================
* Code Start
* =========================================
        org     $0250           * ROM starts here

START   lds     #STACK          * Initialize stack pointer

* =========================================
* Your code goes here
* =========================================

* Mirror switches (low nibble) to outputs (high nibble)
* SW1->OUT1, SW2->OUT2, SW3->OUT3, SW4->OUT4
* Shift left 4 bits to move low nibble to high nibble

MAIN    lda     PERIPH          * Read peripheral (switches in low nibble)
        anda    #SWMASK         * Mask to get only switch bits
        lsla                    * Shift left 4 times
        lsla                    *   to move bits 0-3
        lsla                    *   into bits 4-7
        lsla                    *   (low nibble -> high nibble)

* Check if X=$FF, invert OUT4 if so
        cmpx    #$00FF          * Is X = $FF?
        bne     STORE           * No, skip inversion
        eora    #OUT4           * Invert OUT4 bit

STORE   sta     PERIPH          * Write to outputs

* Exit - return to monitor
        swi                     * Print newline
        fcb     PCRLF
        swi                     * Return to ASSIST09
        fcb     MONITR

* =========================================
* Subroutines
* =========================================

* Add your subroutines here

* =========================================
* Interrupt Vectors
* =========================================
        end
