/* Linker script for SAM3X8E (Arduino Due) */

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x00000000, LENGTH = 512K
    SRAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 96K
}

SECTIONS
{
    /* Vector table at start of flash */
    .text : {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
        . = ALIGN(4);
        _etext = .;
    } > FLASH

    /* Initialized data */
    .data : {
        _sdata = .;
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > SRAM AT > FLASH

    /* Uninitialized data */
    .bss : {
        _sbss = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > SRAM

    /* End of RAM */
    . = ALIGN(4);
    _end = .;
}