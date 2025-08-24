#include "test_common.h"

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