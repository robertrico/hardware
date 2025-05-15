#include <stdio.h>
#include "gpio.h"
#include "tim.h"

int __io_putchar(int ch) {
    
    return ch;
}

int main(void)
{
    // Initialize the GPIO pins for the LEDs
    led_init();

    tim2_1hz_init(); // Initialize TIM2 for 1 Hz

    // Main loop
    while (1)
    {
        printf("Hello World\n"); // Print message to console
        led_toggle(); // Toggle LED
        while((TIM2->SR & SR_UIF) == 0); // Wait for update interrupt flag
        TIM2->SR &= ~SR_UIF; // Clear the update interrupt flag

        led_toggleb(); // Toggle LED
        while((TIM2->SR & SR_UIF) == 0); // Wait for update interrupt flag
        TIM2->SR &= ~SR_UIF; // Clear the update interrupt flag
    }
    
    return 0;
}