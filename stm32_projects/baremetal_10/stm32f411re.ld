/* Entry Point */
ENTRY(Reset_Handler)

/* Memory Areas */
MEMORY
{
    FLASH (rx ) : ORIGIN = 0x08000000, LENGTH = 512K
    SRAM  (rxw) : ORIGIN = 0x20000000, LENGTH = 128K
}

_estack = ORIGIN(SRAM) + LENGTH(SRAM);

/* Heap and Stack */
__max_heap_size = 0x200;
__max_stack_size = 0x400;

/* Section Definitions */
SECTIONS
{
    /* .text */
    .text :
    {
        . = ALIGN(4);
        *(.isr_vector) /* Interrupt Vector Table */
        *(.text)
        *(.rodata)
        . = ALIGN(4);
        _etext = .; /* End of text section */
    }>FLASH

    /* .data */
    .data :
    {
        . = ALIGN(4);
        _sdata = .; /* Start of data section */
        *(.data)
        . = ALIGN(4);
        _edata = .; /* End of data section */
    } >SRAM AT>FLASH

    /* .bss */
    .bss :
    {
        . = ALIGN(4);
        _sbss = .; /* Start of bss section */
        *(.bss)
        . = ALIGN(4);
        _ebss = .; /* End of bss section */
    } >SRAM
}