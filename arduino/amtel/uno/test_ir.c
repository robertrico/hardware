/*
 * INSTRUCTION REGISTER TEST (74LS244 + 74LS373)
 * ==============================================
 * 
 * PURPOSE:
 * Tests an instruction register module that uses:
 * - 74LS244: Octal buffer used as reset mechanism (forces 0x00 onto bus)
 * - 74LS373: Octal latch that stores the instruction register value
 * 
 * THEORY OF OPERATION:
 * In a CPU, the instruction register (IR) holds the current instruction being executed.
 * This module provides two critical functions:
 * 1. NORMAL: Load instructions from data bus into the latch
 * 2. RESET: Force 0x00 (NOP) into the IR when RESET signal is active
 * 
 * The 244 has all inputs tied to GND, so when enabled it drives 0x00.
 * The RESET signal has priority - it overrides any data on the bus.
 * 
 * CRITICAL WIRING TABLE:
 * ====================================================================================
 * Arduino Pin | Signal Name | 244 Pin    | 373 Pin | Function
 * ------------|-------------|------------|---------|----------------------------------
 * D1 (PD1)    | RESET       | 1,19 (~OE) | ---     | Reset control (active LOW)
 * D4 (PD4)    | IR_LOAD     | ---        | 11 (~LE)| Latch Enable (active LOW)
 * D5 (PD5)    | IR_OE       | ---        | 1 (~OE) | Output Enable (active LOW)
 * ====================================================================================
 * 
 * 74LS244 CONNECTIONS (Reset Buffer):
 * ====================================================================================
 * 244 Pin | Connection     | Purpose
 * --------|----------------|--------------------------------------------------
 * 1       | Arduino D1     | ~1OE - First buffer output enable (active LOW)
 * 19      | Arduino D1     | ~2OE - Second buffer output enable (tie together)
 * 2       | GND            | 1A0 - Input tied to GND (outputs 0)
 * 4       | GND            | 1A1 - Input tied to GND (outputs 0)
 * 6       | GND            | 1A2 - Input tied to GND (outputs 0)
 * 8       | GND            | 1A3 - Input tied to GND (outputs 0)
 * 11      | GND            | 2A0 - Input tied to GND (outputs 0)
 * 13      | GND            | 2A1 - Input tied to GND (outputs 0)
 * 15      | GND            | 2A2 - Input tied to GND (outputs 0)
 * 17      | GND            | 2A3 - Input tied to GND (outputs 0)
 * 18      | Data Bus D0    | 1Y0 - Output to bus bit 0
 * 16      | Data Bus D1    | 1Y1 - Output to bus bit 1
 * 14      | Data Bus D2    | 1Y2 - Output to bus bit 2
 * 12      | Data Bus D3    | 1Y3 - Output to bus bit 3
 * 9       | Data Bus D4    | 2Y0 - Output to bus bit 4
 * 7       | Data Bus D5    | 2Y1 - Output to bus bit 5
 * 5       | Data Bus D6    | 2Y2 - Output to bus bit 6
 * 3       | Data Bus D7    | 2Y3 - Output to bus bit 7
 * 10      | GND            | Ground
 * 20      | 5V             | VCC
 * ====================================================================================
 * 
 * 74LS373 CONNECTIONS (Instruction Latch):
 * ====================================================================================
 * 373 Pin | Connection     | Purpose
 * --------|----------------|--------------------------------------------------
 * 1       | Arduino D5     | ~OE - Output Enable (active LOW for reading)
 * 11      | Arduino D4     | ~LE - Latch Enable (active LOW, latches on LOW->HIGH)
 * 3       | Data Bus D0    | D0 - Data input bit 0
 * 4       | Data Bus D1    | D1 - Data input bit 1
 * 7       | Data Bus D2    | D2 - Data input bit 2
 * 8       | Data Bus D3    | D3 - Data input bit 3
 * 13      | Data Bus D4    | D4 - Data input bit 4
 * 14      | Data Bus D5    | D5 - Data input bit 5
 * 17      | Data Bus D6    | D6 - Data input bit 6
 * 18      | Data Bus D7    | D7 - Data input bit 7
 * 2       | Data Bus D0    | Q0 - Output bit 0 (same net as D0)
 * 5       | Data Bus D1    | Q1 - Output bit 1 (same net as D1)
 * 6       | Data Bus D2    | Q2 - Output bit 2 (same net as D2)
 * 9       | Data Bus D3    | Q3 - Output bit 3 (same net as D3)
 * 12      | Data Bus D4    | Q4 - Output bit 4 (same net as D4)
 * 15      | Data Bus D5    | Q5 - Output bit 5 (same net as D5)
 * 16      | Data Bus D6    | Q6 - Output bit 6 (same net as D6)
 * 19      | Data Bus D7    | Q7 - Output bit 7 (same net as D7)
 * 10      | GND            | Ground
 * 20      | 5V             | VCC
 * ====================================================================================
 * 
 * DATA BUS MAPPING (REVERSED):
 * Arduino D13 = Bit 0, Arduino D6 = Bit 7
 * Same reversed mapping as other tests for consistency
 */

#include "test_ir.h"
#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Control signal definitions
#define RED_LED         PD0  // D0 - Test failed indicator
#define RESET           PD1  // D1 -> 244 pins 1,19 (~OE) - active LOW for reset
#define GREEN_LED       PD2  // D2 - Test passed indicator
#define YELLOW_LED      PD3  // D3 - Test running indicator
#define IR_LOAD         PD4  // D4 -> 373 pin 11 (~LE) - active LOW to latch
#define IR_OE           PD5  // D5 -> 373 pin 1 (~OE) - active LOW to read IR

// Timing parameters
#define SETUP_TIME       50    
#define HOLD_TIME        50    
#define PROPAGATION_TIME 100   
#define RESET_TIME       200   // Extra time for reset signal to propagate

// Test patterns for instruction register
static const uint8_t test_instructions[] = {
    0x00,   // NOP instruction
    0xFF,   // All ones
    0xA5,   // Test pattern 10100101
    0x5A,   // Test pattern 01011010
    0x0F,   // Lower nibble only
    0xF0,   // Upper nibble only
    0x81,   // Edge bits set
    0x42,   // Specific instruction pattern
    // Walking bit tests
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
};

/*
 * init_pins() - Initialize for safe operation
 * 
 * Initial state:
 * - RESET inactive (HIGH) - 244 disabled, normal operation
 * - IR_LOAD inactive (HIGH) - 373 not latching
 * - IR_OE inactive (HIGH) - 373 outputs disabled
 * - Data bus high-Z
 */
static void init_pins(void) {
    // Configure control pins as outputs
    DDRD |= (1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED);
    DDRD |= (1 << RESET) | (1 << IR_LOAD) | (1 << IR_OE);
    
    // Safe initial state
    PORTD |= (1 << RESET);      // RESET HIGH (244 disabled)
    PORTD |= (1 << IR_LOAD);    // IR_LOAD HIGH (373 not latching)
    PORTD |= (1 << IR_OE);      // IR_OE HIGH (373 outputs disabled)
    
    // LEDs off
    PORTD &= ~((1 << RED_LED) | (1 << GREEN_LED) | (1 << YELLOW_LED));
    
    // Data bus as inputs (high-Z)
    DDRD &= ~((1 << PD6) | (1 << PD7));  
    DDRB &= ~0x3F;
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

/*
 * write_to_bus() - Write with reversed bit mapping
 * Same as other tests: D13=bit0, D6=bit7
 */
static void write_to_bus(uint8_t data) {
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

/*
 * read_from_bus() - Read with reversed bit mapping
 */
static uint8_t read_from_bus(void) {
    uint8_t result = 0;
    
    for (int i = 0; i < 6; i++) {
        if (PINB & (1 << (5 - i))) {
            result |= (1 << i);
        }
    }
    
    if (PIND & (1 << PD7)) result |= 0x40;
    if (PIND & (1 << PD6)) result |= 0x80;
    
    return result;
}

/*
 * test_reset_function() - Verify RESET forces 0x00 into IR
 * 
 * SEQUENCE:
 * 1. Activate RESET (LOW) - 244 drives 0x00 onto bus
 * 2. Pulse IR_LOAD to latch the 0x00
 * 3. Deactivate RESET
 * 4. Read IR and verify it contains 0x00
 * 
 * This simulates a CPU reset where IR must be cleared to NOP
 */
static bool test_reset_function(void) {
    // === PHASE 1: ACTIVATE RESET ===
    // 244 outputs 0x00 onto bus when ~OE goes LOW
    PORTD &= ~(1 << RESET);       // RESET LOW - 244 drives 0x00
    _delay_us(RESET_TIME);         // Let signal propagate
    
    // === PHASE 2: LATCH THE RESET VALUE ===
    // While 244 is driving 0x00, latch it into 373
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW (transparent)
    _delay_us(HOLD_TIME);
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (latch on edge)
    _delay_us(SETUP_TIME);
    
    // === PHASE 3: DEACTIVATE RESET ===
    PORTD |= (1 << RESET);        // RESET HIGH - 244 disabled
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: READ AND VERIFY ===
    set_bus_as_input();           // Arduino releases bus
    PORTD &= ~(1 << IR_OE);       // Enable 373 outputs
    _delay_us(PROPAGATION_TIME);
    
    uint8_t read_value = read_from_bus();
    
    PORTD |= (1 << IR_OE);        // Disable 373 outputs
    
    // Should read 0x00 (NOP) after reset
    return (read_value == 0x00);
}

/*
 * test_load_instruction() - Test normal instruction loading
 * 
 * SEQUENCE:
 * 1. Ensure RESET is inactive (HIGH)
 * 2. Arduino writes instruction to bus
 * 3. Pulse IR_LOAD to latch instruction
 * 4. Release bus and read back
 * 5. Verify instruction was stored correctly
 * 6. Check for floating pins
 */
static bool test_load_instruction(uint8_t instruction) {
    // === PHASE 1: ENSURE NORMAL MODE ===
    PORTD |= (1 << RESET);        // RESET HIGH - 244 disabled
    PORTD |= (1 << IR_OE);        // 373 outputs off
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: WRITE INSTRUCTION ===
    set_bus_as_output();
    write_to_bus(instruction);
    _delay_us(SETUP_TIME);
    
    // === PHASE 3: LATCH INSTRUCTION ===
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW
    _delay_us(HOLD_TIME);
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (latched)
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: READ BACK ===
    set_bus_as_input();
    _delay_us(SETUP_TIME);
    
    PORTD &= ~(1 << IR_OE);       // Enable 373 outputs
    _delay_us(PROPAGATION_TIME);
    
    uint8_t read_value = read_from_bus();
    
    // === PHASE 5: CHECK FOR FLOATING PINS ===
    set_bus_as_input_with_pullups();
    _delay_us(50);
    uint8_t pullup_value = read_from_bus();
    
    PORTD |= (1 << IR_OE);        // Disable 373 outputs
    set_bus_as_input();
    
    bool floating_detected = (read_value != pullup_value);
    
    return (read_value == instruction) && !floating_detected;
}

/*
 * test_reset_overrides_data() - Verify RESET has priority
 * 
 * CRITICAL TEST: Even if Arduino tries to write data,
 * RESET forces 0x00. This ensures reset always works
 * regardless of bus state.
 * 
 * SEQUENCE:
 * 1. Arduino writes 0xFF to bus
 * 2. Activate RESET (should override with 0x00)
 * 3. Latch while RESET active
 * 4. Read and verify 0x00 was latched, not 0xFF
 */
static bool test_reset_overrides_data(void) {
    // === PHASE 1: TRY TO WRITE NON-ZERO ===
    set_bus_as_output();
    write_to_bus(0xFF);           // Try to write all ones
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: ACTIVATE RESET ===
    // 244 should force 0x00 despite Arduino driving 0xFF
    PORTD &= ~(1 << RESET);       // RESET LOW - 244 forces 0x00
    _delay_us(RESET_TIME);
    
    // === PHASE 3: LATCH WITH RESET ACTIVE ===
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW
    _delay_us(HOLD_TIME);
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: RELEASE AND VERIFY ===
    PORTD |= (1 << RESET);        // RESET HIGH
    set_bus_as_input();
    _delay_us(SETUP_TIME);
    
    PORTD &= ~(1 << IR_OE);       // Enable 373 outputs
    _delay_us(PROPAGATION_TIME);
    
    uint8_t read_value = read_from_bus();
    
    PORTD |= (1 << IR_OE);        // Disable 373 outputs
    
    // Should read 0x00 even though we tried to write 0xFF
    return (read_value == 0x00);
}

/*
 * test_ir_run() - Main test entry point
 * 
 * TEST SEQUENCE:
 * 1. Basic reset test - verify reset produces 0x00
 * 2. Reset override test - verify reset has priority
 * 3. Load instructions - verify normal operation
 * 4. Final reset test - verify reset still works
 * 
 * LED INDICATORS:
 * - Yellow flashes indicate test phase
 * - Green = all tests passed
 * - Red = at least one test failed
 */
void test_ir_run(void) {
    init_pins();
    _delay_ms(500);
    
    // Startup sequence - 3 yellow flashes
    for (int i = 0; i < 3; i++) {
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(100);
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(100);
    }
    
    PORTD |= (1 << YELLOW_LED);  // Yellow ON during tests
    _delay_ms(200);
    
    bool all_passed = true;
    
    // === TEST 1: BASIC RESET ===
    // Single flash = reset test
    PORTD &= ~(1 << YELLOW_LED);
    _delay_ms(50);
    PORTD |= (1 << YELLOW_LED);
    _delay_ms(50);
    
    if (!test_reset_function()) {
        all_passed = false;
    }
    _delay_ms(100);
    
    // === TEST 2: RESET OVERRIDE ===
    // Double flash = override test
    for (int i = 0; i < 2; i++) {
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(50);
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(50);
    }
    
    if (!test_reset_overrides_data()) {
        all_passed = false;
    }
    _delay_ms(100);
    
    // === TEST 3: LOAD INSTRUCTIONS ===
    uint8_t num_instructions = sizeof(test_instructions) / sizeof(test_instructions[0]);
    
    for (uint8_t i = 0; i < num_instructions; i++) {
        // Flash for each instruction
        PORTD &= ~(1 << YELLOW_LED);
        _delay_ms(50);
        PORTD |= (1 << YELLOW_LED);
        _delay_ms(50);
        
        if (!test_load_instruction(test_instructions[i])) {
            all_passed = false;
        }
        _delay_ms(10);
    }
    
    // === TEST 4: FINAL RESET ===
    // Verify reset still works after loading instructions
    PORTD &= ~(1 << YELLOW_LED);
    _delay_ms(50);
    PORTD |= (1 << YELLOW_LED);
    _delay_ms(50);
    
    if (!test_reset_function()) {
        all_passed = false;
    }
    
    // Test complete
    PORTD &= ~(1 << YELLOW_LED);
    
    // Show result
    if (all_passed) {
        PORTD |= (1 << GREEN_LED);
        PORTD &= ~(1 << RED_LED);
    } else {
        PORTD |= (1 << RED_LED);
        PORTD &= ~(1 << GREEN_LED);
    }
    
    // Halt
    while (1) {
        _delay_ms(100);
    }
}