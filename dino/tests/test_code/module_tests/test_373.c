#include "test_373.h"
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
#define RED_LED         PD0
#define GREEN_LED       PD2
#define YELLOW_LED      PD3
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
    // Set control pins as outputs
    DDRD |= (1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED);
    DDRD |= (1 << LE_PIN) | (1 << OE_PIN);
    
    // Initialize control signals to safe state
    PORTD &= ~(1 << LE_PIN);    // LE LOW (latched mode)
    PORTD |= (1 << OE_PIN);      // OE HIGH (outputs disabled)
    
    // LEDs off initially
    PORTD &= ~((1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED));
    
    // Data bus pins start as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7 as inputs
    DDRB &= ~0x3F;                        // D8-D13 as inputs
    
    // Disable pull-ups on data bus
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

static void set_bus_as_output(void) {
    // Configure D6-D13 as outputs
    DDRD |= (1 << PD6) | (1 << PD7);  // D6-D7
    DDRB |= 0x3F;                      // D8-D13 (PB0-PB5)
}

static void set_bus_as_input(void) {
    // Configure D6-D13 as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7
    DDRB &= ~0x3F;                        // D8-D13
    
    // Enable weak pull-downs by keeping ports low
    // This helps detect disconnected lines (they'll read as 0)
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

static void set_bus_as_input_with_pullups(void) {
    // Configure D6-D13 as inputs
    DDRD &= ~((1 << PD6) | (1 << PD7));  // D6-D7
    DDRB &= ~0x3F;                        // D8-D13
    
    // Enable weak pull-ups - this will make disconnected lines read as 1
    PORTD |= (1 << PD6) | (1 << PD7);
    PORTB |= 0x3F;
}

static void write_to_bus(uint8_t data) {
    // Reversed bit mapping:
    // Bit 0 -> D13 (PB5)
    // Bit 1 -> D12 (PB4)
    // Bit 2 -> D11 (PB3)
    // Bit 3 -> D10 (PB2)
    // Bit 4 -> D9 (PB1)
    // Bit 5 -> D8 (PB0)
    // Bit 6 -> D7 (PD7)
    // Bit 7 -> D6 (PD6)
    
    // Write bits 0-5 to D13-D8 (PB5-PB0) in reverse order
    uint8_t portb_value = PORTB & 0xC0;  // Preserve PB6-PB7
    for (int i = 0; i < 6; i++) {
        if (data & (1 << i)) {
            portb_value |= (1 << (5 - i));  // PB5 is bit 0, PB0 is bit 5
        }
    }
    PORTB = portb_value;
    
    // Write bit 6-7 to D7-D6 (PD7-PD6) in reverse order
    if (data & 0x40) PORTD |= (1 << PD7); else PORTD &= ~(1 << PD7);  // Bit 6 -> D7
    if (data & 0x80) PORTD |= (1 << PD6); else PORTD &= ~(1 << PD6);  // Bit 7 -> D6
}

static uint8_t read_from_bus(void) {
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
    
    // Initial delay to let everything stabilize
    _delay_ms(500);
    
    // Startup sequence - triple flash to show we're starting
    for (int i = 0; i < 3; i++) {
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(100);
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(100);
    }
    
    // Turn on yellow LED to indicate test is running
    PORTD |= (1 << YELLOW_LED);
    
    // Small delay before starting tests
    _delay_ms(200);
    
    // Run all test patterns
    bool all_passed = true;
    uint8_t num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    for (uint8_t i = 0; i < num_patterns; i++) {
        // Flash yellow LED to show progress (test number)
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(50);
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(50);
        
        if (!test_latch_pattern(test_patterns[i])) {
            all_passed = false;
            // Don't break - continue testing all patterns
        }
        _delay_ms(10);  // Small delay between tests
    }
    
    // Turn off yellow LED - test complete
    PORTD &= ~(1 << YELLOW_LED);
    
    // Show final result
    if (all_passed) {
        // All tests passed - turn on green LED solid
        PORTD |= (1 << GREEN_LED);
        PORTD &= ~(1 << RED_LED);  // Ensure red is off
    } else {
        // At least one test failed - turn on red LED
        PORTD |= (1 << RED_LED);
        PORTD &= ~(1 << GREEN_LED);  // Ensure green is off
    }
    
    // Done - halt here (user will press reset to run again)
    while (1) {
        // Stay in this state until reset
        _delay_ms(100);
    }
}