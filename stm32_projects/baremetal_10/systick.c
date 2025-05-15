#include "systick.h"

#define CTRL_EN (1U << 0) // Enable SysTick
#define CTRL_CLCKSRC (1U << 2) // Use processor clock
#define CTRL_COUNTFLAG (1U << 16) // Enable SysTick interrupt

#define ONE_MSEC (16000U) // 1 ms in clock cycles (assuming 16 MHz clock)

void sleep_ms(uint32_t delay)
{
    SysTick->LOAD = ONE_MSEC - 1; // Load the SysTick counter value for 1 ms
    SysTick->VAL = 0; // Clear the current value
    SysTick->CTRL = CTRL_CLCKSRC;

    SysTick->CTRL |= CTRL_EN; // Enable SysTick
    for (uint32_t i = 0; i < delay; i++)
    {
        while ((SysTick->CTRL & CTRL_COUNTFLAG) == 0); // Wait for the COUNTFLAG to be set
    }
    
    SysTick->CTRL = 0; // Disable SysTick
}