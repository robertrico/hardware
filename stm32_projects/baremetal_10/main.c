#include "usart.h"
void _init(void) {}
void _fini(void) {}
int main(void)
{
    // Main loop
    usart1_init();

    while (1)
    {
        // Send a simple pattern for DSLogic to capture: 0x55, 0xAA, 0xFF, 0x00
        usart1_write('A');
        for (volatile int i = 0; i < 10000; ++i); // Simple delay
        usart1_write('U');
        for (volatile int i = 0; i < 10000; ++i); // Simple delay
    }
    
    return 0;
}
