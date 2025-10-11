// Simple LED blink for Arduino Due (SAM3X8E)
// Blinks Arduino Due pin 2 (PB25) using SysTick timer

#include <stdint.h>

// Minimal register definitions for SAM3X8E
#define PIOB_BASE       0x400E1000
#define PMC_BASE        0x400E0600
#define WDT_BASE        0x400E1A50

// PIO registers
#define PIOB_PER        (*(volatile uint32_t*)(PIOB_BASE + 0x00))  // PIO Enable
#define PIOB_OER        (*(volatile uint32_t*)(PIOB_BASE + 0x10))  // Output Enable
#define PIOB_SODR       (*(volatile uint32_t*)(PIOB_BASE + 0x30))  // Set Output Data
#define PIOB_CODR       (*(volatile uint32_t*)(PIOB_BASE + 0x34))  // Clear Output Data

// PMC registers
#define PMC_PCER0       (*(volatile uint32_t*)(PMC_BASE + 0x10))   // Peripheral Clock Enable

// WDT registers
#define WDT_MR          (*(volatile uint32_t*)(WDT_BASE + 0x04))   // Mode Register
#define WDT_MR_WDDIS    (1 << 15)  // Watchdog Disable

// SysTick registers (ARMv7-M core peripheral)
#define SYST_CSR        (*(volatile uint32_t*)(0xE000E010))  // Control and Status
#define SYST_RVR        (*(volatile uint32_t*)(0xE000E014))  // Reload Value
#define SYST_CVR        (*(volatile uint32_t*)(0xE000E018))  // Current Value

// Peripheral IDs
#define ID_PIOB         12

// Global tick counter
volatile uint32_t systick_count = 0;

// SysTick interrupt handler
void SysTick_Handler(void) {
    systick_count++;
}

// Delay function using SysTick
void delay_ms(uint32_t ms) {
    uint32_t start = systick_count;
    while ((systick_count - start) < ms);
}

int main(void) {
    // Disable watchdog
    WDT_MR = WDT_MR_WDDIS;

    // Enable PIOB clock
    PMC_PCER0 = (1 << ID_PIOB);

    // Set PB25 (Arduino Due pin 2) as output
    PIOB_PER = (1 << 25);   // Enable PIO control
    PIOB_OER = (1 << 25);   // Set as output

    // Setup SysTick for 1ms ticks
    // Assuming default RC oscillator ~4MHz (conservative estimate)
    // Reload value for 1ms = 4000 - 1
    SYST_RVR = 3999;        // Reload value
    SYST_CVR = 0;           // Clear current value
    SYST_CSR = 0x07;        // Enable SysTick, enable interrupt, use processor clock

    while(1) {
        // Turn pin on
        PIOB_SODR = (1 << 25);
        delay_ms(75);  // 100ms on

        // Turn pin off
        PIOB_CODR = (1 << 25);
        delay_ms(75);  // 100ms off
    }

    return 0;
}