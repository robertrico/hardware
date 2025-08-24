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
 * IMPORTANT TEST NOTE:
 * This test is designed for LOGIC ANALYZER verification. The 373's Q outputs
 * go to the instruction decoder, NOT back to the data bus. Therefore, we cannot
 * read back values through the Arduino. Instead, connect your logic analyzer to
 * the 373 Q outputs to verify correct operation.
 * 
 * CRITICAL WIRING TABLE:
 * ====================================================================================
 * Arduino Pin | Signal Name | 244 Pin    | 373 Pin | Function
 * ------------|-------------|------------|---------|----------------------------------
 * D1 (PD1)    | RESET       | 1,19 (~OE) | ---     | Reset control (active LOW)
 * D4 (PD4)    | IR_LOAD     | ---        | 11 (LE)| Latch Enable (HIGH=transparent, LOW=latched)
 * GND         | ---         | ---        | 1 (~OE) | Output Enable (always enabled - tied to GND)
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
 * 1       | GND            | ~OE - Output Enable (always enabled)
 * 11      | Arduino D4     | LE - Latch Enable (HIGH=transparent, LOW=latched)
 * 3       | Data Bus D0    | D0 - Data input bit 0
 * 4       | Data Bus D1    | D1 - Data input bit 1
 * 7       | Data Bus D2    | D2 - Data input bit 2
 * 8       | Data Bus D3    | D3 - Data input bit 3
 * 13      | Data Bus D4    | D4 - Data input bit 4
 * 14      | Data Bus D5    | D5 - Data input bit 5
 * 17      | Data Bus D6    | D6 - Data input bit 6
 * 18      | Data Bus D7    | D7 - Data input bit 7
 * 2       | To Decoder     | Q0 - Output bit 0 (NOT connected to bus!)
 * 5       | To Decoder     | Q1 - Output bit 1 (NOT connected to bus!)
 * 6       | To Decoder     | Q2 - Output bit 2 (NOT connected to bus!)
 * 9       | To Decoder     | Q3 - Output bit 3 (NOT connected to bus!)
 * 12      | To Decoder     | Q4 - Output bit 4 (NOT connected to bus!)
 * 15      | To Decoder     | Q5 - Output bit 5 (NOT connected to bus!)
 * 16      | To Decoder     | Q6 - Output bit 6 (NOT connected to bus!)
 * 19      | To Decoder     | Q7 - Output bit 7 (NOT connected to bus!)
 * 10      | GND            | Ground
 * 20      | 5V             | VCC
 * ====================================================================================
 * 
 * DATA BUS MAPPING (REVERSED):
 * Arduino D13 = Bit 0, Arduino D6 = Bit 7
 * Same reversed mapping as other tests for consistency
 */

#include "test_ir.h"
#include "test_common.h"
#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Control signal definitions
#define RESET           PD1  // D1 -> 244 pins 1,19 (~OE) - active LOW for reset
#define IR_LOAD         PD4  // D4 -> 373 pin 11 (LE) - HIGH=transparent, LOW=latched
// Note: 373 ~OE is tied to GND, so outputs are always enabled

// Timing parameters
// These are orders of magnitude larger than they need to be. 1 µs is 1,000 ns.
// Hold time for latch is only ~30ns
#define SETUP_TIME       1    
#define HOLD_TIME        1    
#define PROPAGATION_TIME 2   
#define RESET_TIME       2   // Extra time for reset signal to propagate

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
 * - IR_LOAD inactive (LOW) - 373 in latched mode
 * - 373 ~OE tied to GND - outputs always enabled
 * - Data bus high-Z
 */
static void init_pins(void) {
    // Initialize LEDs using common function
    init_leds();
    
    // Configure control pins as outputs
    DDRD |= (1 << RESET) | (1 << IR_LOAD);
    
    // Safe initial state
    PORTD |= (1 << RESET);      // RESET HIGH (244 disabled)
    PORTD &= ~(1 << IR_LOAD);   // IR_LOAD LOW (373 in latched mode)
    
    // Data bus as inputs (high-Z)
    set_bus_as_input();
}

// Bus operations are now provided by test_common.h

/*
 * test_reset_for_analyzer() - Show RESET forcing 0x00 into IR
 * 
 * For logic analyzer verification:
 * 1. Activate RESET - 244 drives 0x00
 * 2. Latch it into 373
 * 3. Hold for 50ms to see on analyzer
 */
static void test_reset_for_analyzer(void) {
    // === PHASE 1: ACTIVATE RESET ===
    PORTD &= ~(1 << RESET);       // RESET LOW - 244 drives 0x00
    _delay_us(RESET_TIME);
    
    // === PHASE 2: LATCH THE RESET VALUE ===
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (transparent)
    _delay_us(HOLD_TIME);
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW (latched)
    
    // === PHASE 3: DEACTIVATE RESET ===
    PORTD |= (1 << RESET);        // RESET HIGH - 244 disabled
    set_bus_as_input();           // Release bus
    
    // Hold for exactly 50ms for logic analyzer
    _delay_ms(50);
}

/*
 * load_instruction_for_analyzer() - Load instruction and hold for 50ms
 * 
 * For logic analyzer verification:
 * 1. Write instruction to bus
 * 2. Pulse IR_LOAD to latch it
 * 3. Hold for exactly 50ms so it's visible on analyzer
 * 4. The 373 Q outputs (going to instruction decoder) will show the pattern
 */
static void load_instruction_for_analyzer(uint8_t instruction) {
    // === PHASE 1: ENSURE NORMAL MODE ===
    PORTD |= (1 << RESET);        // RESET HIGH - 244 disabled
    PORTD &= ~(1 << IR_LOAD);    // IR_LOAD LOW (373 in latched mode)
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: WRITE INSTRUCTION ===
    set_bus_as_output();
    write_to_bus(instruction);
    _delay_us(SETUP_TIME);
    
    // === PHASE 3: LATCH INSTRUCTION ===
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (transparent)
    _delay_us(HOLD_TIME);
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW (latched)
    
    // === PHASE 4: RELEASE BUS AND HOLD ===
    set_bus_as_input();           // Release bus
    
    // Hold pattern for exactly 50ms for logic analyzer
    _delay_ms(50);
}

/*
 * test_reset_override_for_analyzer() - Show RESET overriding data
 * 
 * For logic analyzer verification:
 * 1. Arduino writes 0xFF to bus
 * 2. Activate RESET (should override with 0x00)
 * 3. Latch and hold for 50ms
 */
static void test_reset_override_for_analyzer(void) {
    // === PHASE 1: TRY TO WRITE NON-ZERO ===
    set_bus_as_output();
    write_to_bus(0xFF);           // Try to write all ones
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: ACTIVATE RESET ===
    PORTD &= ~(1 << RESET);       // RESET LOW - 244 forces 0x00
    _delay_us(RESET_TIME);
    
    // === PHASE 3: LATCH WITH RESET ACTIVE ===
    PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (transparent)
    _delay_us(HOLD_TIME);
    PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW (latched)
    
    // === PHASE 4: RELEASE AND HOLD ===
    PORTD |= (1 << RESET);        // RESET HIGH
    set_bus_as_input();           // Release bus
    
    // Hold for exactly 50ms for logic analyzer
    _delay_ms(50);
}

/*
 * test_ir_run() - Main test entry point
 * 
 * LOGIC ANALYZER VERIFICATION TEST:
 * This test loads patterns into the IR for observation on a logic analyzer.
 * Since the 373 Q outputs go to the instruction decoder (not back to the bus),
 * verification must be done externally.
 * 
 * WHAT TO PROBE:
 * - Channel 0: RESET signal (D1) - Shows when 244 is active
 * - Channel 1: IR_LOAD signal (D4) - Shows when 373 latches
 * - Channels 2-9: 373 Q outputs (pins 2,5,6,9,12,15,16,19) - Shows latched values
 * 
 * EXPECTED SEQUENCE (50ms each):
 * 1. Basic reset: 0x00
 * 2. Reset override: 0x00 (despite trying to write 0xFF)
 * 3. Pattern sequence with deliberate reset activation:
 *    - Patterns load normally until indices 11 and 14
 *    - At these indices, RESET forces 0x00 instead of the pattern
 *    - This proves the 244 override mechanism works
 * 4. Final reset: 0x00
 * 
 * SUCCESS CRITERIA:
 * - When RESET = LOW, the 373 outputs should show 0x00
 * - When RESET = HIGH, patterns should load correctly
 * - The 244 must override Arduino data when both drive the bus
 */
void test_ir_run(void) {
    init_pins();
    
    // Show startup sequence
    show_startup_sequence();
    
    // Start test execution (adds 500ms delay)
    start_test_execution();
    
    // === TEST 1: BASIC RESET (0x00 for 50ms) ===
    test_reset_for_analyzer();
    
    // === TEST 2: RESET OVERRIDE (0xFF→0x00 for 50ms) ===
    test_reset_override_for_analyzer();
    
    // === TEST 3: LOAD ALL TEST PATTERNS ===
    uint8_t num_instructions = sizeof(test_instructions) / sizeof(test_instructions[0]);
    
    for (uint8_t i = 0; i < num_instructions; i++) {
        // On specific patterns, activate RESET to demonstrate override
        // This proves the 244 can force 0x00 even when Arduino writes data
        if (i == 11 || i == 14) {  // Indices 11 and 14 will show 0x00
            // Try to load the pattern but RESET will override
            set_bus_as_output();
            write_to_bus(test_instructions[i]);  // Try to write 0x81
            _delay_us(SETUP_TIME);
            
            // Activate RESET - this should force bus to 0x00
            PORTD &= ~(1 << RESET);       // RESET LOW - 244 forces 0x00
            _delay_us(RESET_TIME);
            
            // Latch while RESET is active (should latch 0x00, not 0x81)
            PORTD |= (1 << IR_LOAD);      // IR_LOAD HIGH (transparent)
            _delay_us(HOLD_TIME);
            PORTD &= ~(1 << IR_LOAD);     // IR_LOAD LOW (latched)
            
            // Release RESET after latching to allow next patterns
            PORTD |= (1 << RESET);  // RESET HIGH - return to normal
            set_bus_as_input();
            _delay_ms(50);  // Hold for analyzer
        } else {
            // Normal pattern loading
            load_instruction_for_analyzer(test_instructions[i]);
        }
    }
    
    // === TEST 4: FINAL RESET (0x00 for 50ms) ===
    test_reset_for_analyzer();
    
    // Test complete - show green LED
    show_test_result(true);
    
    // Halt
    while (1) {
        _delay_ms(100);
    }
}