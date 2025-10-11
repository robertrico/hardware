// Minimal startup code for SAM3X8E (Arduino Due)

#include <stdint.h>

// Stack pointer value - top of RAM for SAM3X8E (96KB SRAM)
#define STACK_TOP 0x20018000

// Forward declarations
void Reset_Handler(void);
void Default_Handler(void);
void SysTick_Handler(void);

// Main function declaration
extern int main(void);

// Vector table - must be at 0x80000 (start of flash)
__attribute__ ((section(".vectors")))
void (* const vectors[])(void) = {
    (void (*)(void))STACK_TOP,     // Initial stack pointer
    Reset_Handler,                  // Reset handler
    Default_Handler,                // NMI
    Default_Handler,                // HardFault
    Default_Handler,                // MemManage
    Default_Handler,                // BusFault
    Default_Handler,                // UsageFault
    0, 0, 0, 0,                    // Reserved
    Default_Handler,                // SVCall
    Default_Handler,                // Debug Monitor
    0,                             // Reserved
    Default_Handler,                // PendSV
    SysTick_Handler,                // SysTick
    // Add more interrupt handlers as needed
};

// External symbols from linker script
extern uint32_t _etext;
extern uint32_t _sdata;
extern uint32_t _edata;
extern uint32_t _sbss;
extern uint32_t _ebss;

// Reset handler - entry point
void Reset_Handler(void) {
    uint32_t *src, *dst;

    // Copy initialized data from flash to RAM
    src = &_etext;
    dst = &_sdata;
    while (dst < &_edata) {
        *dst++ = *src++;
    }

    // Zero out uninitialized data (bss)
    dst = &_sbss;
    while (dst < &_ebss) {
        *dst++ = 0;
    }

    // Jump to main
    main();

    // Hang if main returns
    while(1);
}

// Default handler for unused interrupts
void Default_Handler(void) {
    while(1);
}