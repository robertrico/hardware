#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Pin definitions
#define A1_PIN        PE4   // Pin 2 - 74LS121 A1 input
#define A2_PIN        PE5   // Pin 3 - 74LS121 A2 input
#define PULSE_REQ_PIN PH3   // Pin 6 - 74LS121 B input (trigger)
#define BUTTON_PIN    PH4   // Pin 7 - Button input

// Debounce delay
#define DEBOUNCE_MS 50

int main(void) {
    // Configure output pins
    DDRE |= (1 << A1_PIN);          // Pin 2 as output
    DDRE |= (1 << A2_PIN);          // Pin 3 as output
    DDRH |= (1 << PULSE_REQ_PIN);   // Pin 6 as output

    // Configure button input with pull-up (button should pull to ground to trigger)
    DDRH &= ~(1 << BUTTON_PIN);     // Pin 7 as input
    PORTH |= (1 << BUTTON_PIN);     // Enable pull-up resistor

    // Set idle state: A1=HIGH, A2=HIGH, PULSE_REQ=LOW
    PORTE |= (1 << A1_PIN);         // A1 HIGH
    PORTE |= (1 << A2_PIN);         // A2 HIGH
    PORTH &= ~(1 << PULSE_REQ_PIN); // PULSE_REQ LOW

    bool last_button = false;

    while(1) {
        // Read button state (active LOW with pull-up)
        bool button = (PINH & (1 << BUTTON_PIN)) ? false : true;  // Inverted: LOW = pressed

        // Detect button press (pin goes LOW)
        if (button && !last_button) {
            // Button pressed - trigger A1 pulse
            // Set: A1=LOW, A2=HIGH, PULSE_REQ=HIGH
            PORTE &= ~(1 << A1_PIN);        // A1 LOW
            PORTH |= (1 << PULSE_REQ_PIN);  // PULSE_REQ HIGH

            // Hold briefly for 74LS121 to see the trigger
            _delay_us(10);

            // Return to idle: A1=HIGH, PULSE_REQ=LOW
            PORTE |= (1 << A1_PIN);          // A1 HIGH
            PORTH &= ~(1 << PULSE_REQ_PIN);  // PULSE_REQ LOW

            // Debounce delay
            _delay_ms(DEBOUNCE_MS);
        }

        last_button = button;
        _delay_ms(1);
    }

    return 0;
}
