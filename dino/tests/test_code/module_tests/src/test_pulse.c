/*
 * 74LS121 PULSE TEST
 * ==================
 * 
 * PURPOSE:
 * Tests the 74LS121 monostable multivibrator pulse generation for register control.
 * Validates that the 121 generates correct pulses based on control signal combinations.
 * 
 * THEORY OF OPERATION:
 * The 74LS121 monitors REG_A_LOAD and REG_B_LOAD signals (NANDed with PULSE_REQ)
 * to trigger a pulse when the appropriate register load condition is met.
 * - A1 input: REG_A_LOAD NAND PULSE_REQ
 * - A2 input: REG_B_LOAD NAND PULSE_REQ
 * - Q output: Pulse that is NANDed with both load signals
 * 
 * TEST MODES:
 * - Register A test: Triggers pulse for Register A load operation
 * - Register B test: Triggers pulse for Register B load operation
 * 
 * CONTROL SIGNALS:
 * - D1 (PD1): PULSE_REQ - Common pulse request signal
 * - D4 (PD4): REG_A_LOAD - Register A load signal
 * - D5 (PD5): REG_B_LOAD - Register B load signal
 * 
 * TEST PROCEDURE:
 * 1. Initialize all signals to idle state (all LOW)
 * 2. Based on selected register (A or B), set appropriate load signal
 * 3. Assert PULSE_REQ to trigger the 121
 * 4. Hold signals for observation period
 * 5. Return to idle state
 * 6. Light green LED to indicate test completion
 * 
 * OSCILLOSCOPE SETUP:
 * - Channel 1: 121 Q output
 * - Channel 2: Selected load signal (REG_A_LOAD or REG_B_LOAD)
 * - Trigger: Rising edge on Channel 1
 * - Time base: 1us/div recommended
 */

#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>
#include "test_pulse.h"
#include "test_common.h"

// Control signal definitions
#define PULSE_REQ   PD1  // D1 - Common pulse request
#define REG_A_LOAD  PD4  // D4 - Register A load signal  
#define REG_B_LOAD  PD5  // D5 - Register B load signal

// Timing constants
#define SETUP_DELAY_MS     10   // Delay after signal setup
#define PULSE_HOLD_MS      50   // Hold time for pulse observation
#define IDLE_DELAY_MS      100  // Delay in idle state between pulses

// Test configuration
typedef enum {
    TEST_REGISTER_A,
    TEST_REGISTER_B
} test_register_t;

// Get test configuration from compile flag
#ifdef PULSE_TEST_REG_B
    static const test_register_t test_register = TEST_REGISTER_B;
#else
    static const test_register_t test_register = TEST_REGISTER_A;  // Default to A
#endif

static void init_control_signals(void) {
    // Configure control pins as outputs
    DDRD |= (1 << PULSE_REQ) | (1 << REG_A_LOAD) | (1 << REG_B_LOAD);
    
    // Start with all signals LOW (idle state)
    PORTD &= ~((1 << PULSE_REQ) | (1 << REG_A_LOAD) | (1 << REG_B_LOAD));
}

static void set_idle_state(void) {
    // All control signals LOW
    PORTD &= ~((1 << PULSE_REQ) | (1 << REG_A_LOAD) | (1 << REG_B_LOAD));
}

static void trigger_pulse_for_register_a(void) {
    // Set REG_A_LOAD high
    PORTD |= (1 << REG_A_LOAD);
    _delay_ms(SETUP_DELAY_MS);
    
    // Assert PULSE_REQ to trigger 121
    PORTD |= (1 << PULSE_REQ);
    _delay_ms(PULSE_HOLD_MS);
    
    // Return to idle
    set_idle_state();
}

static void trigger_pulse_for_register_b(void) {
    // Set REG_B_LOAD high
    PORTD |= (1 << REG_B_LOAD);
    _delay_ms(SETUP_DELAY_MS);
    
    // Assert PULSE_REQ to trigger 121
    PORTD |= (1 << PULSE_REQ);
    _delay_ms(PULSE_HOLD_MS);
    
    // Return to idle
    set_idle_state();
}

void test_pulse_run(void) {
    // Initialize hardware
    init_leds();
    init_control_signals();
    
    // Show startup sequence
    show_startup_sequence();
    
    // Start test execution
    start_test_execution();
    
    // Initial idle state
    set_idle_state();
    _delay_ms(IDLE_DELAY_MS);
    
    // Execute pulse test based on selected register
    if (test_register == TEST_REGISTER_A) {
        // Test Register A pulse generation
        trigger_pulse_for_register_a();
    } else {
        // Test Register B pulse generation
        trigger_pulse_for_register_b();
    }
    
    // Wait for observation
    _delay_ms(IDLE_DELAY_MS);
    
    // Test complete - turn on green LED
    show_test_result(true);
    
    // Keep running to allow continued observation
    while (1) {
        _delay_ms(1000);
    }
}