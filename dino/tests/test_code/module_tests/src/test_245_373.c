/*
 * 74LS245 + 74LS373 COMBINED TEST
 * ================================
 * 
 * PURPOSE:
 * Tests a bus transceiver (245) working with a latch (373) as would be used
 * in a CPU design for buffered register operations.
 * 
 * THEORY OF OPERATION:
 * The 245 acts as a bidirectional buffer between the Arduino (simulating CPU)
 * and the 373 latch (simulating a register). Data flows:
 * - WRITE: Arduino -> 245 A-side -> 245 B-side -> 373 D inputs
 * - READ:  373 Q outputs -> 245 B-side -> 245 A-side -> Arduino
 * 
 * CRITICAL WIRING TABLE:
 * ====================================================================================
 * Arduino Pin | Signal Name | 245 Pin | 373 Pin | Function
 * ------------|-------------|---------|---------|------------------------------------
 * D1 (PD1)    | BUS_245_CE  | 19 (~OE)| ---     | 245 Output Enable (active LOW)
 * D4 (PD4)    | REG_373_LE  | ---     | 11 (~LE)| 373 Latch Enable (active LOW)
 * D5 (PD5)    | REG_OUT     | 1 (DIR) | 1 (~OE) | Shared: Direction + Output Enable
 * ====================================================================================
 * 
 * D5 SHARED SIGNAL LOGIC:
 * When D5 = HIGH: 245 DIR = A->B (write mode), 373 ~OE = HIGH (outputs disabled)
 * When D5 = LOW:  245 DIR = B->A (read mode),  373 ~OE = LOW (outputs enabled)
 * This works because we want 373 outputs OFF when writing, ON when reading
 * 
 * DATA BUS CONNECTIONS (REVERSED BIT ORDER):
 * ====================================================================================
 * Arduino | AVR Port | Bit # | 245 A-Side | 245 B-Side | 373 D Pin | 373 Q Pin
 * --------|----------|-------|------------|------------|-----------|------------
 * D13     | PB5      | Bit 0 | Pin 2 (A0) | Pin 18 (B0)| Pin 3     | Pin 2
 * D12     | PB4      | Bit 1 | Pin 3 (A1) | Pin 17 (B1)| Pin 4     | Pin 5
 * D11     | PB3      | Bit 2 | Pin 4 (A2) | Pin 16 (B2)| Pin 7     | Pin 6
 * D10     | PB2      | Bit 3 | Pin 5 (A3) | Pin 15 (B3)| Pin 8     | Pin 9
 * D9      | PB1      | Bit 4 | Pin 6 (A4) | Pin 14 (B4)| Pin 13    | Pin 12
 * D8      | PB0      | Bit 5 | Pin 7 (A5) | Pin 13 (B5)| Pin 14    | Pin 15
 * D7      | PD7      | Bit 6 | Pin 8 (A6) | Pin 12 (B6)| Pin 17    | Pin 16
 * D6      | PD6      | Bit 7 | Pin 9 (A7) | Pin 11 (B7)| Pin 18    | Pin 19
 * ====================================================================================
 * 
 * POWER CONNECTIONS:
 * - 245: VCC = Pin 20, GND = Pin 10
 * - 373: VCC = Pin 20, GND = Pin 10
 * - Add 0.1µF bypass capacitors between VCC and GND for each IC
 * 
 * COMMON WIRING MISTAKES TO CHECK:
 * 1. Arduino MUST connect to 245 A-side (pins 2-9), NOT B-side
 * 2. D5 MUST connect to BOTH 245 pin 1 AND 373 pin 1
 * 3. Each 245 B-side pin connects to BOTH the D and Q pins of the 373
 * 4. Bit order is REVERSED: D13 = bit 0, D6 = bit 7
 */

#include "test_245_373.h"
#include "test_common.h"
#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Control signal definitions with IC pin numbers for easy verification
#define BUS_245_CE      PD1  // D1 -> 245 pin 19 (~OE) - active LOW to enable 245
#define REG_373_LE      PD4  // D4 -> 373 pin 11 (LE) - HIGH=transparent, LOW=latched
#define REG_OUT         PD5  // D5 -> 245 pin 1 (DIR) AND 373 pin 1 (~OE)

// Timing parameters (in microseconds) - based on 74LS series typical delays
// These are orders of magnitude larger than they need to be. 1 µs is 1,000 ns.
// Hold time for latch is only ~30ns
#define SETUP_TIME       1    // tsu: Setup time for data before latch
#define HOLD_TIME        1    // th: Hold time for data after latch
#define PROPAGATION_TIME 2   // tpd: Propagation delay through ICs
#define BUS_RELEASE_TIME 2   // Time to ensure bus is fully released

/*
 * TEST PATTERNS - Comprehensive set to detect all common failures:
 * - 0x00: All zeros - detects stuck-at-1 faults
 * - 0xFF: All ones - detects stuck-at-0 faults
 * - 0xAA/0x55: Alternating patterns - detects adjacent pin shorts
 * - Walking 1s: Each bit set individually - detects single bit failures
 * - Walking 0s: Each bit clear individually - detects single bit failures
 * - 0x0F/0xF0: Nibble patterns - detects nibble-wide issues
 */
static const uint8_t test_patterns[] = {
    0x00, 0xFF, 0xAA, 0x55, 0x0F, 0xF0, 0x81, 0x42, 0x3C, 0xC3,
    // Walking ones
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80,
    // Walking zeros
    0xFE, 0xFD, 0xFB, 0xF7, 0xEF, 0xDF, 0xBF, 0x7F
};

/*
 * init_pins() - Initialize all pins to prevent bus contention
 * 
 * Safe state ensures no two outputs drive the bus simultaneously:
 * - 373 in latched mode (LE = LOW)
 * - 373 outputs disabled (~OE = HIGH)  
 * - 245 disabled (~OE = HIGH)
 * - 245 direction set for write (DIR = HIGH)
 * - Arduino pins as inputs (high-Z)
 */
static void init_pins(void) {
    // Initialize LEDs using common function
    init_leds();
    
    // Configure control pins as outputs
    DDRD |= (1 << BUS_245_CE) | (1 << REG_373_LE) | (1 << REG_OUT);
    
    // Set safe initial state - EVERYTHING DISABLED
    PORTD &= ~(1 << REG_373_LE);  // 373 LE LOW (latched mode)
    PORTD |= (1 << REG_OUT);       // HIGH: 373 ~OE disabled, 245 DIR = A->B
    PORTD |= (1 << BUS_245_CE);    // 245 ~OE HIGH (245 disabled)
    
    // Data bus as inputs (high-Z) - Arduino not driving bus
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
 * write_to_bus() - Write data with REVERSED bit mapping
 * Bit 0 -> D13 (PB5), Bit 7 -> D6 (PD6)
 */
static void write_to_bus(uint8_t data) {
    // Bits 0-5 map to D13-D8 (PB5-PB0) in REVERSE order
    uint8_t portb_value = PORTB & 0xC0;  // Preserve PB6-PB7
    for (int i = 0; i < 6; i++) {
        if (data & (1 << i)) {
            portb_value |= (1 << (5 - i));  // Bit 0 -> PB5, Bit 5 -> PB0
        }
    }
    PORTB = portb_value;
    
    // Bits 6-7 map to D7-D6 (PD7-PD6) in REVERSE order
    if (data & 0x40) {
        PORTD |= (1 << PD7); 
    } else {
        // Bit 6 -> D7
        PORTD &= ~(1 << PD7); 
    }

    if (data & 0x80) {
        PORTD |= (1 << PD6); 
    } else {
        // Bit 7 -> D6
        PORTD &= ~(1 << PD6);
    }

}

/*
 * read_from_bus() - Read data with REVERSED bit mapping
 */
static uint8_t read_from_bus(void) {
    uint8_t result = 0;
    
    // Read bits 0-5 from D13-D8 (PB5-PB0) in REVERSE order
    for (int i = 0; i < 6; i++) {
        if (PINB & (1 << (5 - i))) {
            result |= (1 << i);
        }
    }
    
    // Read bits 6-7 from D7-D6 (PD7-PD6) in REVERSE order
    if (PIND & (1 << PD7)) {
        result |= 0x40;  // D7 -> Bit 6
    }
    if (PIND & (1 << PD6)){
        result |= 0x80;  // D6 -> Bit 7
    }
    
    return result;
}

/*
 * test_combined_pattern() - Test one data pattern through 245+373
 * 
 * DETAILED SEQUENCE:
 * =================
 * 
 * 1. SAFE STATE: Disable all outputs to prevent contention
 * 2. WRITE PATH: Arduino -> 245(A->B) -> 373 inputs
 *    - Set 245 DIR=HIGH (A->B), 373 ~OE=HIGH (disabled)
 *    - Enable 245 (~OE=LOW)
 *    - Arduino drives pattern onto bus
 *    - Pattern flows through 245 to 373 D inputs
 * 3. LATCH: Capture data in 373
 *    - Pulse LE from LOW->HIGH->LOW
 *    - Data latches are level triggered. 
 * 4. TRANSITION: Prepare for read
 *    - Disable 245 briefly
 *    - Arduino releases bus (high-Z)
 * 5. READ PATH: 373 -> 245(B->A) -> Arduino
 *    - Set 245 DIR=LOW (B->A), 373 ~OE=LOW (enabled)
 *    - Re-enable 245 (~OE=LOW)
 *    - 373 drives latched data through 245 to Arduino
 * 6. VERIFY: Check pattern matches and no floating pins
 */
static bool test_combined_pattern(uint8_t pattern) {
    uint8_t read_value = 0;
    uint8_t pullup_value = 0;
    
    // === PHASE 1: SAFE STARTING STATE ===
    PORTD |= (1 << REG_OUT);       // 373 ~OE HIGH (disabled), 245 DIR = A->B
    PORTD &= ~((1 << REG_373_LE));    // 373 LE LOW (latching)

    PORTD |= (1 << BUS_245_CE);    // 245 ~OE HIGH (disabled)
    set_bus_as_input();             
    _delay_us(SETUP_TIME);
    
    // === PHASE 2: WRITE DATA TO 373 THROUGH 245 ===
    PORTD |= (1 << REG_OUT);       // Keep 373 disabled, 245 DIR = A->B
    PORTD &= ~(1 << BUS_245_CE);   // Enable 245 (~OE = LOW)
    set_bus_as_output();            
    write_to_bus(pattern);          
    _delay_us(SETUP_TIME);          
    
    // === PHASE 3: LATCH DATA IN 373 ===
    PORTD |= (1 << REG_373_LE);     // 373 LE HIGH (transparent)
    _delay_us(HOLD_TIME);           
    PORTD &= ~(1 << REG_373_LE);   // 373 LE LOW (latched)
    _delay_us(SETUP_TIME);
    
    // === PHASE 4: DISABLE 245 AND RELEASE BUS ===
    PORTD |= (1 << BUS_245_CE);    // Disable 245 to avoid contention
    set_bus_as_input();             // Arduino releases bus
    _delay_us(BUS_RELEASE_TIME);   
    
    // === PHASE 5: READ THROUGH 245 (B->A DIRECTION) ===
    PORTD &= ~(1 << REG_OUT);      // 373 ~OE LOW (enable), 245 DIR = B->A
    PORTD &= ~(1 << BUS_245_CE);   // Re-enable 245 (~OE = LOW)
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

/*
 * test_245_373_run() - Main test entry point
 * 
 * LED Status:
 * - Startup sequence: Yellow-Green-Red-Green-Yellow
 * - Yellow solid: Tests running
 * - Green solid: All patterns passed
 * - Red solid: One or more patterns failed
 */
void test_245_373_run(void) {
    init_pins();
    
    // Show startup sequence
    show_startup_sequence();
    
    // Start test execution (adds 500ms delay)
    start_test_execution();
    
    bool all_passed = true;
    uint8_t num_patterns = sizeof(test_patterns) / sizeof(test_patterns[0]);
    
    for (uint8_t i = 0; i < num_patterns; i++) {
        if (!test_combined_pattern(test_patterns[i])) {
            all_passed = false;
        }
        _delay_ms(10);
    }
    
    // Show final result
    show_test_result(all_passed);
    
    while (1) {
        _delay_ms(100);
    }
}