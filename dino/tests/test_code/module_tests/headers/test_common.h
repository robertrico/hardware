#ifndef TEST_COMMON_H
#define TEST_COMMON_H

#include <avr/io.h>
#include <util/delay.h>
#include <stdbool.h>
#include <stdint.h>

// Standard LED pin definitions used across all tests
#define RED_LED    PD0  // D0 - Test failed indicator
#define GREEN_LED  PD2  // D2 - Test passed indicator
#define YELLOW_LED PD3  // D3 - Test running indicator

// LED functions
void init_leds(void);
void show_startup_sequence(void);
void start_test_execution(void);
void show_test_result(bool passed);
void leds_off(void);

// Bus operations used across all tests
// Data bus uses D6-D13 with reversed bit mapping:
// D13=bit0, D12=bit1, D11=bit2, D10=bit3, D9=bit4, D8=bit5, D7=bit6, D6=bit7
void set_bus_as_output(void);
void set_bus_as_input(void);
void set_bus_as_input_with_pullups(void);
void write_to_bus(uint8_t data);
uint8_t read_from_bus(void);

#endif // TEST_COMMON_H