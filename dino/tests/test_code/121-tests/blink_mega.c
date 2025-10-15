#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Pin definitions
#define A1_PIN         PE4   // Pin 2 - 74LS121 A1 input
#define A2_PIN         PE5   // Pin 3 - 74LS121 A2 input
#define PULSE_REQ_PIN  PH3   // Pin 6 - 74LS121 B input (trigger)
#define BUTTON_A1_PIN  PH4   // Pin 7 - Button for A1 trigger
#define BUTTON_A2_PIN  PH5   // Pin 8 - Button for A2 trigger

// Debounce delay
#define DEBOUNCE_MS 50

int main(void) {
    // Configure output pins
    DDRE |= (1 << A1_PIN);          // Pin 2 as output
    DDRE |= (1 << A2_PIN);          // Pin 3 as output
    DDRH |= (1 << PULSE_REQ_PIN);   // Pin 6 as output

    // Configure button inputs with pull-ups (buttons pull to ground to trigger)
    DDRH &= ~(1 << BUTTON_A1_PIN);  // Pin 7 as input
    PORTH |= (1 << BUTTON_A1_PIN);  // Enable pull-up resistor
    DDRH &= ~(1 << BUTTON_A2_PIN);  // Pin 8 as input
    PORTH |= (1 << BUTTON_A2_PIN);  // Enable pull-up resistor

    // Set idle state: A1=HIGH, A2=HIGH, PULSE_REQ=LOW
    PORTE |= (1 << A1_PIN);         // A1 HIGH
    PORTE |= (1 << A2_PIN);         // A2 HIGH
    PORTH &= ~(1 << PULSE_REQ_PIN); // PULSE_REQ LOW

    bool last_button_a1 = false;
    bool last_button_a2 = false;

    while(1) {
        // Read button states (active LOW with pull-up)
        bool button_a1 = (PINH & (1 << BUTTON_A1_PIN)) ? false : true;  // Inverted: LOW = pressed
        bool button_a2 = (PINH & (1 << BUTTON_A2_PIN)) ? false : true;  // Inverted: LOW = pressed

        // Detect A1 button press (pin 7 goes LOW)
        if (button_a1 && !last_button_a1) {
            // A1 button pressed - trigger A1 pulse
            // Set: A1=LOW, A2=HIGH (actively driven!), PULSE_REQ=HIGH
            PORTE &= ~(1 << A1_PIN);        // A1 LOW
            PORTE |= (1 << A2_PIN);         // A2 HIGH (ensure it's driven)
            PORTH |= (1 << PULSE_REQ_PIN);  // PULSE_REQ HIGH

            // Hold briefly for 74LS121 to see the trigger
            _delay_us(10);

            // Return to idle: A1=HIGH, A2=HIGH, PULSE_REQ=LOW
            PORTE |= (1 << A1_PIN);          // A1 HIGH
            PORTE |= (1 << A2_PIN);          // A2 HIGH (keep driven)
            PORTH &= ~(1 << PULSE_REQ_PIN);  // PULSE_REQ LOW

            // Debounce delay
            _delay_ms(DEBOUNCE_MS);
        }

        // Detect A2 button press (pin 8 goes LOW)
        if (button_a2 && !last_button_a2) {
            // A2 button pressed - trigger A2 pulse
            // Set: A1=HIGH (actively driven!), A2=LOW, PULSE_REQ=HIGH
            PORTE |= (1 << A1_PIN);         // A1 HIGH (ensure it's driven)
            PORTE &= ~(1 << A2_PIN);        // A2 LOW
            PORTH |= (1 << PULSE_REQ_PIN);  // PULSE_REQ HIGH

            // Hold briefly for 74LS121 to see the trigger
            _delay_us(10);

            // Return to idle: A1=HIGH, A2=HIGH, PULSE_REQ=LOW
            PORTE |= (1 << A1_PIN);          // A1 HIGH (keep driven)
            PORTE |= (1 << A2_PIN);          // A2 HIGH
            PORTH &= ~(1 << PULSE_REQ_PIN);  // PULSE_REQ LOW

            // Debounce delay
            _delay_ms(DEBOUNCE_MS);
        }

        last_button_a1 = button_a1;
        last_button_a2 = button_a2;
        _delay_ms(1);
    }

    return 0;
}
