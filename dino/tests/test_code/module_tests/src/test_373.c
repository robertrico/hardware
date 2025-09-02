#include "test_373.h"
#include "test_common.h"
#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Pin Assignments for 74LS373 Test
// D0: Red LED (Test failed indicator)
// D1: Reserved for UART TX
// D2: Green LED (All tests passed indicator)  
// D3: Yellow LED (Test running indicator)
// D4: LE (Latch Enable for 74LS373, active HIGH)
// D5: OE (Output Enable for 74LS373, active LOW)
// D6-D13: Shared data bus D0-D7 (bidirectional)

// Control signals
#define LE_PIN          PD4
#define OE_PIN          PD5

// Data bus pins mapping (reversed)
// D13 = PB5 = Data bit 0
// D12 = PB4 = Data bit 1
// D11 = PB3 = Data bit 2
// D10 = PB2 = Data bit 3
// D9 = PB1 = Data bit 4
// D8 = PB0 = Data bit 5
// D7 = PD7 = Data bit 6
// D6 = PD6 = Data bit 7

// Timing delays (in microseconds)
#define SETUP_TIME       50    // Time for signals to settle
#define HOLD_TIME        50    // Hold time for latch
#define PROPAGATION_TIME 100   // Time for 74LS373 outputs to stabilize
#define BUS_RELEASE_TIME 100   // Time after releasing bus

// Test patterns - comprehensive set to verify all bits
static const uint8_t test_patterns[] = {
    0x00,   // All zeros
    0xFF,   // All ones
    0xAA,   // Alternating 10101010
    0x55,   // Alternating 01010101
    0x0F,   // Lower nibble
    0xF0,   // Upper nibble
    0x81,   // Edges only
    0x18,   // Middle bits
    0x3C,   // Center block
    0xC3,   // Inverted center
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,  // Walking one
    0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF, 0xBF, 0x7F   // Walking zero
};

static void init_pins(void) {
    // Initialize LEDs using common function
    init_leds();
    
    // Set control pins as outputs
    DDRD |= (1 << LE_PIN) | (1 << OE_PIN);
    
    // Initialize control signals to safe state
    PORTD &= ~(1 << LE_PIN);    // LE LOW (latched mode)
    PORTD |= (1 << OE_PIN);      // OE HIGH (outputs disabled)
    
    // Data bus pins start as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7 as inputs
    DDRB &= ~0x3F;                        // D8-D13 as inputs
    
    // Disable pull-ups on data bus
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

// Bus operations are now provided by test_common.h

static bool test_latch_pattern(uint8_t pattern) {
    uint8_t read_value = 0;
    uint8_t pullup_value = 0;
    
    // === PHASE 1: ENSURE SAFE STARTING STATE ===
    PORTD |= (1 << OE_PIN);       // OE HIGH (373 outputs disabled)
    PORTD &= ~(1 << LE_PIN);      // LE LOW (latched mode)
    set_bus_as_input();            // Arduino pins high-Z
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: WRITE DATA TO 373 INPUTS ===
    set_bus_as_output();           // Arduino drives the bus
    write_to_bus(pattern);         // Put pattern on bus
    _delay_us(SETUP_TIME);         // Let signals settle
    
    // === PHASE 3: LATCH THE DATA ===
    PORTD |= (1 << LE_PIN);       // LE HIGH (transparent)
    _delay_us(HOLD_TIME);          // Hold for latch
    PORTD &= ~(1 << LE_PIN);      // LE LOW (data latched)
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: RELEASE BUS AND SWITCH TO INPUT ===
    set_bus_as_input();            // Arduino releases bus (high-Z)
    _delay_us(BUS_RELEASE_TIME);  // Wait for bus to stabilize
    
    // === PHASE 5: ENABLE 373 OUTPUTS AND READ ===
    PORTD &= ~(1 << OE_PIN);      // OE LOW (373 drives the bus)
    _delay_us(PROPAGATION_TIME);  // Wait for 373 outputs to stabilize
    
    read_value = read_from_bus();  // Read what 373 is outputting
    
    // === PHASE 6: CHECK WITH PULL-UPS (detects floating lines) ===
    set_bus_as_input_with_pullups(); // Enable pull-ups
    _delay_us(50);                    // Let pull-ups take effect
    pullup_value = read_from_bus();   // Read again with pull-ups
    
    // If values differ, we have floating/disconnected lines
    bool floating_detected = (read_value != pullup_value);
    
    // === PHASE 7: DISABLE 373 OUTPUTS ===
    PORTD |= (1 << OE_PIN);       // OE HIGH (373 releases bus)
    set_bus_as_input();            // Disable pull-ups
    _delay_us(SETUP_TIME);
    
    // === PHASE 8: RETURN RESULT ===
    // Fail if pattern doesn't match OR if floating lines detected
    return (read_value == pattern) && !floating_detected;
}

void test_373_run(void) {
    // Initialize all pins
    init_pins();
    
    // Show startup sequence
    show_startup_sequence();
    
    // Start test execution (adds 500ms delay)
    start_test_execution();
    
    // Run all test patterns
    bool all_passed = true;
    uint8_t num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    for (uint8_t i = 0; i < num_patterns; i++) {
        if (!test_latch_pattern(test_patterns[i])) {
            all_passed = false;
            // Don't break - continue testing all patterns
        }
        _delay_ms(10);  // Small delay between tests
    }
    
    // Show final result
    show_test_result(all_passed);
    
    // Done - halt here (user will press reset to run again)
    while (1) {
        // Stay in this state until reset
        _delay_ms(100);
    }
}