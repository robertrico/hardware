#include <avr/io.h>
#include <util/delay.h>

#define LED_PIN PD2  // Pin 2 is PD2 on ATmega328P

int main(void) {
    // Set LED pin as output
    DDRD |= (1 << LED_PIN);

    while(1) {
        // Turn LED on
        PORTD |= (1 << LED_PIN);
        _delay_ms(500);

        // Turn LED off
        PORTD &= ~(1 << LED_PIN);
        _delay_ms(500);
    }

    return 0;
}