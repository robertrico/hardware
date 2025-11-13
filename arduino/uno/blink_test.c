#include <avr/io.h>
#include <util/delay.h>

#define LED_PIN PB5  // Built-in LED on Arduino Uno (pin 13)

int main(void) {
    // Set LED pin as output
    DDRB |= (1 << LED_PIN);

    while(1) {
        // Turn LED on
        PORTB |= (1 << LED_PIN);
        _delay_ms(500);

        // Turn LED off
        PORTB &= ~(1 << LED_PIN);
        _delay_ms(500);
    }

    return 0;
}