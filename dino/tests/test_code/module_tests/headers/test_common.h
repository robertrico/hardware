#ifndef TEST_COMMON_H
#define TEST_COMMON_H

#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>

// Standard LED pin definitions used across all tests
#define RED_LED    PD0  // D0 - Test failed indicator
#define GREEN_LED  PD2  // D2 - Test passed indicator
#define YELLOW_LED PD3  // D3 - Test running indicator

// Initialize LED pins to safe state
void init_leds(void);

// Show startup sequence: Yellow-Green-Red-Green-Yellow
void show_startup_sequence(void);

// Start test execution (yellow solid with delay)
void start_test_execution(void);

// Show test results
void show_test_result(bool passed);

// Turn off all LEDs
void leds_off(void);

#endif // TEST_COMMON_H