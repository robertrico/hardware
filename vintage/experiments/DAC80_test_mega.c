#include <avr/io.h>
#include <util/delay.h>

// Simple test: Toggle all DAC pins to verify Arduino is working
// Connect an LED or scope to any pin to see if it's toggling

int main(void) {
    // Configure PORTA (8 MSBs) as outputs
    DDRA = 0xFF;

    // Configure PORTC lower 4 bits (4 LSBs) as outputs
    DDRC |= 0x0F;

    while(1) {
        // All HIGH
        PORTA = 0xFF;
        PORTC |= 0x0F;
        _delay_ms(500);

        // All LOW
        PORTA = 0x00;
        PORTC &= ~0x0F;
        _delay_ms(500);
    }

    return 0;
}
