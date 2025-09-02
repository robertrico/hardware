#include "test_common.h"
#include <avr/io.h>
#include <util/delay.h>

void init_leds(void) {
    // Configure LED pins as outputs
    DDRD |= (1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED);
    
    // Start with all LEDs off
    PORTD &= ~((1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED));
}

void show_startup_sequence(void) {
    // Initial stabilization delay
    _delay_ms(500);
    
    // Startup sequence: Yellow-Green-Red-Green-Yellow
    // Yellow
    PORTD |= (1 << YELLOW_LED);
    _delay_ms(200);
    PORTD &= ~(1 << YELLOW_LED);
    _delay_ms(100);
    
    // Green
    PORTD |= (1 << GREEN_LED);
    _delay_ms(200);
    PORTD &= ~(1 << GREEN_LED);
    _delay_ms(100);
    
    // Red
    PORTD |= (1 << RED_LED);
    _delay_ms(200);
    PORTD &= ~(1 << RED_LED);
    _delay_ms(100);
    
    // Green
    PORTD |= (1 << GREEN_LED);
    _delay_ms(200);
    PORTD &= ~(1 << GREEN_LED);
    _delay_ms(100);
    
    // Yellow
    PORTD |= (1 << YELLOW_LED);
    _delay_ms(200);
}

void start_test_execution(void) {
    // Yellow stays on from startup sequence
    // Add half second delay before tests start
    _delay_ms(500);
}

void show_test_result(bool passed) {
    // Turn off yellow LED (test complete)
    PORTD &= ~(1 << YELLOW_LED);
    
    if (passed) {
        // All tests passed - green LED solid
        PORTD |= (1 << GREEN_LED);
        PORTD &= ~(1 << RED_LED);
    } else {
        // At least one test failed - red LED solid
        PORTD |= (1 << RED_LED);
        PORTD &= ~(1 << GREEN_LED);
    }
}

void leds_off(void) {
    PORTD &= ~((1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED));
}

// Bus operations used across all tests
void set_bus_as_output(void) {
    // Configure D6-D13 as outputs
    DDRD |= (1 << PD6) | (1 << PD7);  // D6-D7
    DDRB |= 0x3F;                      // D8-D13 (PB0-PB5)
}

void set_bus_as_input(void) {
    // Configure D6-D13 as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7
    DDRB &= ~0x3F;                        // D8-D13
    
    // Disable pull-ups (keep ports low)
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

void set_bus_as_input_with_pullups(void) {
    // Configure D6-D13 as inputs
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7
    DDRB &= ~0x3F;                        // D8-D13
    
    // Enable weak pull-ups
    PORTD |= (1 << PD6) | (1 << PD7);
    PORTB |= 0x3F;
}

void write_to_bus(uint8_t data) {
    // Reversed bit mapping:
    // Bit 0 -> D13 (PB5)
    // Bit 1 -> D12 (PB4)
    // Bit 2 -> D11 (PB3)
    // Bit 3 -> D10 (PB2)
    // Bit 4 -> D9 (PB1)
    // Bit 5 -> D8 (PB0)
    // Bit 6 -> D7 (PD7)
    // Bit 7 -> D6 (PD6)
    
    // Prepare both port values FIRST, then write atomically
    
    // Prepare PORTB value (bits 0-5 to PB5-PB0 reversed)
    uint8_t portb_value = PORTB & 0xC0;  // Preserve PB6-PB7
    for (int i = 0; i < 6; i++) {
        if (data & (1 << i)) {
            portb_value |= (1 << (5 - i));  // PB5 is bit 0, PB0 is bit 5
        }
    }
    
    // Prepare PORTD value (bits 6-7 to PD7-PD6)
    uint8_t portd_value = PORTD & 0x3F;  // Preserve PD0-PD5
    if (data & 0x40) portd_value |= (1 << PD7);  // Bit 6 -> D7
    if (data & 0x80) portd_value |= (1 << PD6);  // Bit 7 -> D6
    
    // Write both ports as close together as possible
    // This minimizes the time window where data is inconsistent
    PORTB = portb_value;
    PORTD = portd_value;
}

uint8_t read_from_bus(void) {
    uint8_t result = 0;
    
    // Reversed bit mapping:
    // D13 (PB5) -> Bit 0
    // D12 (PB4) -> Bit 1
    // D11 (PB3) -> Bit 2
    // D10 (PB2) -> Bit 3
    // D9 (PB1) -> Bit 4
    // D8 (PB0) -> Bit 5
    // D7 (PD7) -> Bit 6
    // D6 (PD6) -> Bit 7
    
    // Read bits 0-5 from D13-D8 (PB5-PB0) in reverse order
    for (int i = 0; i < 6; i++) {
        if (PINB & (1 << (5 - i))) {
            result |= (1 << i);
        }
    }
    
    // Read bit 6-7 from D7-D6 (PD7-PD6) in reverse order
    if (PIND & (1 << PD7)) result |= 0x40;  // D7 -> Bit 6
    if (PIND & (1 << PD6)) result |= 0x80;  // D6 -> Bit 7
    
    return result;
}