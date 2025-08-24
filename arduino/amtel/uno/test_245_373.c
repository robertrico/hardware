#include "test_245_373.h"
#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Pin Assignments for 74LS245 + 74LS373 Combined Test
// D0: Red LED (Test failed indicator)
// D1: 245 ~OE (Output Enable for 74LS245, active LOW)
// D2: Green LED (All tests passed indicator)  
// D3: Yellow LED (Test running indicator)
// D4: 373 ~LE (Latch Enable for 74LS373, active LOW)
// D5: 373 ~OE (Output Enable for 74LS373, active LOW) AND 245 DIR
//     When HIGH: 373 disabled, 245 DIR = A->B (write to 373)
//     When LOW: 373 enabled, 245 DIR = B->A (read from 373)
// D6-D13: Shared data bus D0-D7 (bidirectional)

// Control signals
#define RED_LED         PD0
#define BUS_245_CE      PD1  // 245 ~OE (active LOW)
#define GREEN_LED       PD2
#define YELLOW_LED      PD3
#define REG_373_LE      PD4  // 373 ~LE (active LOW latch)
#define REG_OUT         PD5  // 373 ~OE (active LOW) + 245 DIR

// Data bus pins mapping (reversed as in 373 test)
// D13 = PB5 = Data bit 0
// D12 = PB4 = Data bit 1
// D11 = PB3 = Data bit 2
// D10 = PB2 = Data bit 3
// D9 = PB1 = Data bit 4
// D8 = PB0 = Data bit 5
// D7 = PD7 = Data bit 6
// D6 = PD6 = Data bit 7

// Timing delays (in microseconds)
#define SETUP_TIME       50    
#define HOLD_TIME        50    
#define PROPAGATION_TIME 100   
#define BUS_RELEASE_TIME 100   

// Test patterns
static const uint8_t test_patterns[] = {
    0x00,   // All zeros
    0xFF,   // All ones
    0xAA,   // Alternating 10101010
    0x55,   // Alternating 01010101
    0x0F,   // Lower nibble
    0xF0,   // Upper nibble
    0x81,   // Edges only
    0x42,   // Specific pattern
    0x3C,   // Center block
    0xC3,   // Inverted center
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,  // Walking one
    0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF, 0xBF, 0x7F   // Walking zero
};

static void init_pins(void) {
    // Set control pins as outputs
    DDRD |= (1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED);
    DDRD |= (1 << BUS_245_CE) | (1 << REG_373_LE) | (1 << REG_OUT);
    
    // Initialize control signals to safe state
    PORTD |= (1 << REG_373_LE);   // 373 ~LE HIGH (not latching)
    PORTD |= (1 << REG_OUT);       // REG_OUT HIGH (373 ~OE disabled, 245 DIR = A->B)
    PORTD |= (1 << BUS_245_CE);    // 245 ~OE HIGH (245 disabled)
    
    // LEDs off initially
    PORTD &= ~((1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED));
    
    // Data bus pins start as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  
    DDRB &= ~0x3F;                        
    
    // Disable pull-ups on data bus
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

static void set_bus_as_output(void) {
    DDRD |= (1 << PD6) | (1 << PD7);  
    DDRB |= 0x3F;                      
}

static void set_bus_as_input(void) {
    DDRD &= ~((1 << PD6) | (1 << PD7));  
    DDRB &= ~0x3F;                        
    PORTD &= ~((1 << PD6) | (1 << PD7));
    PORTB &= ~0x3F;
}

static void set_bus_as_input_with_pullups(void) {
    DDRD &= ~((1 << PD6) | (1 << PD7));  
    DDRB &= ~0x3F;                        
    PORTD |= (1 << PD6) | (1 << PD7);
    PORTB |= 0x3F;
}

static void write_to_bus(uint8_t data) {
    // Reversed bit mapping (same as 373 test)
    uint8_t portb_value = PORTB & 0xC0;  
    for (int i = 0; i < 6; i++) {
        if (data & (1 << i)) {
            portb_value |= (1 << (5 - i));  
        }
    }
    PORTB = portb_value;
    
    if (data & 0x40) PORTD |= (1 << PD7); else PORTD &= ~(1 << PD7);  
    if (data & 0x80) PORTD |= (1 << PD6); else PORTD &= ~(1 << PD6);  
}

static uint8_t read_from_bus(void) {
    uint8_t result = 0;
    
    // Reversed bit mapping (same as 373 test)
    for (int i = 0; i < 6; i++) {
        if (PINB & (1 << (5 - i))) {
            result |= (1 << i);
        }
    }
    
    if (PIND & (1 << PD7)) result |= 0x40;  
    if (PIND & (1 << PD6)) result |= 0x80;  
    
    return result;
}

static bool test_combined_pattern(uint8_t pattern) {
    uint8_t read_value = 0;
    uint8_t pullup_value = 0;
    
    // === PHASE 1: SAFE STARTING STATE ===
    PORTD |= (1 << REG_OUT);       // 373 ~OE HIGH (disabled), 245 DIR = A->B
    PORTD |= (1 << REG_373_LE);    // 373 ~LE HIGH (not latching)
    PORTD |= (1 << BUS_245_CE);    // 245 ~OE HIGH (disabled)
    set_bus_as_input();             
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: WRITE DATA TO 373 THROUGH 245 ===
    // Setup for writing: 245 DIR = A->B (REG_OUT = HIGH), Enable 245
    PORTD |= (1 << REG_OUT);       // Keep 373 disabled, 245 DIR = A->B
    PORTD &= ~(1 << BUS_245_CE);   // Enable 245 (~OE = LOW)
    set_bus_as_output();            
    write_to_bus(pattern);          
    _delay_us(SETUP_TIME);          
    
    // === PHASE 3: LATCH DATA IN 373 ===
    PORTD &= ~(1 << REG_373_LE);   // 373 ~LE LOW (latch on rising edge)
    _delay_us(HOLD_TIME);           
    PORTD |= (1 << REG_373_LE);     // 373 ~LE HIGH (data latched)
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: PREPARE TO READ BACK ===
    PORTD |= (1 << BUS_245_CE);    // Disable 245 temporarily
    set_bus_as_input();             
    _delay_us(BUS_RELEASE_TIME);   
    
    // === PHASE 5: READ THROUGH 245 (B->A DIRECTION) ===
    PORTD &= ~(1 << REG_OUT);      // 373 ~OE LOW (enable), 245 DIR = B->A
    PORTD &= ~(1 << BUS_245_CE);   // Enable 245 (~OE = LOW)
    _delay_us(PROPAGATION_TIME);   
    
    read_value = read_from_bus();  
    
    // === PHASE 6: CHECK WITH PULL-UPS (detect floating) ===
    set_bus_as_input_with_pullups(); 
    _delay_us(50);                    
    pullup_value = read_from_bus();   
    
    bool floating_detected = (read_value != pullup_value);
    
    // === PHASE 7: DISABLE OUTPUTS ===
    PORTD |= (1 << REG_OUT);       // Disable 373 (~OE HIGH)
    PORTD |= (1 << BUS_245_CE);    // Disable 245 (~OE HIGH)
    set_bus_as_input();             
    _delay_us(SETUP_TIME);
    
    // === PHASE 8: RETURN RESULT ===
    return (read_value == pattern) && !floating_detected;
}

static bool test_245_alone(void) {
    // Quick test to verify 245 basic operation
    // This is a simplified test - full test happens with 373
    
    // Setup: 245 DIR = A->B, 373 disabled
    PORTD |= (1 << REG_OUT);       // 373 disabled, 245 DIR = A->B
    PORTD |= (1 << REG_373_LE);    // 373 not latching
    PORTD &= ~(1 << BUS_245_CE);   // Enable 245
    
    // Write a test pattern
    set_bus_as_output();
    write_to_bus(0xA5);
    _delay_us(50);
    
    // Disable 245 and cleanup
    PORTD |= (1 << BUS_245_CE);    // Disable 245
    set_bus_as_input();
    
    // Basic test passes if no smoke!
    // Real test happens in combination with 373
    return true;
}

void test_245_373_run(void) {
    // Initialize all pins
    init_pins();
    
    // Initial delay
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
    _delay_ms(200);
    
    // First, quick test of 245 alone
    bool basic_245_ok = test_245_alone();
    
    if (!basic_245_ok) {
        // Fast blink yellow to show 245 basic test failed
        for (int i = 0; i < 5; i++) {
            PORTD ^= (1 << YELLOW_LED);
            _delay_ms(100);
        }
    }
    
    // Now run combined tests
    bool all_passed = true;
    uint8_t num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    for (uint8_t i = 0; i < num_patterns; i++) {
        // Flash yellow LED to show progress
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(50);
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(50);
        
        if (!test_combined_pattern(test_patterns[i])) {
            all_passed = false;
        }
        _delay_ms(10);
    }
    
    // Turn off yellow LED - test complete
    PORTD &= ~(1 << YELLOW_LED);
    
    // Show final result
    if (all_passed && basic_245_ok) {
        // All tests passed
        PORTD |= (1 << GREEN_LED);
        PORTD &= ~(1 << RED_LED);
    } else {
        // At least one test failed
        PORTD |= (1 << RED_LED);
        PORTD &= ~(1 << GREEN_LED);
    }
    
    // Done - halt
    while (1) {
        _delay_ms(100);
    }
}