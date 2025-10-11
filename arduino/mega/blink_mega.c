#include <avr/io.h>
#include <util/delay.h>

#define LED_PIN PE4  // Pin 2 is PE4 on ATmega2560

int main(void) {
    // Set LED pin as output
    DDRE |= (1 << LED_PIN);

    while(1) {
        // Turn LED on
        PORTE |= (1 << LED_PIN);
        _delay_ms(50);

        // Turn LED off
        PORTE &= ~(1 << LED_PIN);
        _delay_ms(50);
    }

    return 0;
}