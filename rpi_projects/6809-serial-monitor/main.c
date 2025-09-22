#include <stdio.h>
#include <string.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"

// GPIO pin definitions for 6809 bus monitoring
// Note: GPIO 0-1 reserved for Picoprobe UART
// Note: GPIO 23-25 don't exist as GPIO on Pico W (used for wireless)

// Address bus A0-A7 (using GPIO 2-9)
const uint8_t ADDR_PINS_LOW[] = {2, 3, 4, 5, 6, 7, 8, 9};

// Address bus A8-A15 (using GPIO 10-17)
const uint8_t ADDR_PINS_HIGH[] = {10, 11, 12, 13, 14, 15, 16, 17};

// Data bus D0-D7 (using GPIO 18-22, 26-28)
const uint8_t DATA_PINS[] = {18, 19, 20, 21, 22, 26, 27, 28};

// ANSI escape codes for screen formatting
#define CLEAR_SCREEN "\033[2J"
#define CURSOR_HOME "\033[H"
#define BOLD "\033[1m"
#define NORMAL "\033[0m"

typedef struct {
    uint16_t address;
    uint8_t data;
} bus_state_t;

void gpio_init_bus_monitoring() {
    // Initialize address bus pins A0-A7 as inputs with pull-down
    for (int i = 0; i < 8; i++) {
        gpio_init(ADDR_PINS_LOW[i]);
        gpio_set_dir(ADDR_PINS_LOW[i], GPIO_IN);
        gpio_pull_down(ADDR_PINS_LOW[i]);
    }

    // Initialize address bus pins A8-A15 as inputs with pull-down
    for (int i = 0; i < 8; i++) {
        gpio_init(ADDR_PINS_HIGH[i]);
        gpio_set_dir(ADDR_PINS_HIGH[i], GPIO_IN);
        gpio_pull_down(ADDR_PINS_HIGH[i]);
    }

    // Initialize data bus pins as inputs with pull-down
    for (int i = 0; i < 8; i++) {
        gpio_init(DATA_PINS[i]);
        gpio_set_dir(DATA_PINS[i], GPIO_IN);
        gpio_pull_down(DATA_PINS[i]);
    }
}

uint16_t read_address_bus() {
    uint16_t address = 0;

    // Read A0-A7
    for (int i = 0; i < 8; i++) {
        if (gpio_get(ADDR_PINS_LOW[i])) {
            address |= (1 << i);
        }
    }

    // Read A8-A15
    for (int i = 0; i < 8; i++) {
        if (gpio_get(ADDR_PINS_HIGH[i])) {
            address |= (1 << (i + 8));
        }
    }

    return address;
}

uint8_t read_data_bus() {
    uint8_t data = 0;
    for (int i = 0; i < 8; i++) {
        if (gpio_get(DATA_PINS[i])) {
            data |= (1 << i);
        }
    }
    return data;
}

// Debug function to read data bus with raw pin states
void read_data_bus_debug(uint8_t *data, uint8_t *pin_states) {
    *data = 0;
    for (int i = 0; i < 8; i++) {
        pin_states[i] = gpio_get(DATA_PINS[i]);
        if (pin_states[i]) {
            *data |= (1 << i);
        }
    }
}

void print_header() {
    // Simple header without screen clearing
    printf("\n6809 Bus Monitor\n");
    printf("====================================\n");
    printf("%-20s %-12s\n", "Address", "Data");
    printf("------------------------------------\n");
}

void print_bus_state(bus_state_t *state) {
    // Just print a new line for each change - no cursor manipulation
    printf("0x%04X              0x%02X\n",
           state->address,
           state->data);
    fflush(stdout);
}

void print_gpio_diagnostics() {
    printf("\n=== GPIO Pin Diagnostics ===\n");
    printf("Address Bus Low (A0-A7):\n");
    for (int i = 0; i < 8; i++) {
        bool state = gpio_get(ADDR_PINS_LOW[i]);
        printf("  A%d (GPIO%d): %d\n", i, ADDR_PINS_LOW[i], state);
    }

    printf("\nAddress Bus High (A8-A15):\n");
    for (int i = 0; i < 8; i++) {
        bool state = gpio_get(ADDR_PINS_HIGH[i]);
        printf("  A%d (GPIO%d): %d\n", i + 8, ADDR_PINS_HIGH[i], state);
    }

    printf("\nData Bus (D0-D7):\n");
    for (int i = 0; i < 8; i++) {
        bool state = gpio_get(DATA_PINS[i]);
        printf("  D%d (GPIO%d): %d\n", i, DATA_PINS[i], state);
    }

    printf("\n");
    fflush(stdout);
}

// Buffer for capturing transitions
#define CAPTURE_BUFFER_SIZE 256
typedef struct {
    bus_state_t states[CAPTURE_BUFFER_SIZE];
    uint32_t write_idx;
    uint32_t read_idx;
    bool overflow;
} capture_buffer_t;

int main() {
    stdio_init_all();

    // Wait for serial connection
    sleep_ms(2000);

    // Initialize GPIO for bus monitoring
    gpio_init_bus_monitoring();

    // Print initial diagnostic to verify connections
    printf("\nInitializing 6809 Bus Monitor...\n");
    print_gpio_diagnostics();

    printf("Press any key to start monitoring...\n");
    getchar();

    // Print initial header
    print_header();

    bus_state_t current_state = {0};
    bus_state_t last_state = {0};
    capture_buffer_t capture = {0};

    uint32_t sample_count = 0;
    absolute_time_t last_display_time = get_absolute_time();

    printf("\nStarting continuous bus monitoring (capturing all transitions)...\n\n");

    while (true) {
        // Continuously read all bus signals independently - NO DELAY for maximum speed
        current_state.address = read_address_bus();
        current_state.data = read_data_bus();

        // Capture if ANY signal changed
        if ((current_state.address != last_state.address) ||
            (current_state.data != last_state.data)) {

            // Store in circular buffer
            capture.states[capture.write_idx] = current_state;
            capture.write_idx = (capture.write_idx + 1) % CAPTURE_BUFFER_SIZE;

            // Check for overflow
            if (capture.write_idx == capture.read_idx) {
                capture.overflow = true;
                capture.read_idx = (capture.read_idx + 1) % CAPTURE_BUFFER_SIZE;
            }

            last_state = current_state;
        }

        // Periodically dump the buffer
        sample_count++;
        if (sample_count > 100000) {  // About every 100k samples
            // Print any captured transitions
            while (capture.read_idx != capture.write_idx) {
                print_bus_state(&capture.states[capture.read_idx]);
                capture.read_idx = (capture.read_idx + 1) % CAPTURE_BUFFER_SIZE;
            }

            if (capture.overflow) {
                printf("[Buffer overflow - some transitions lost]\n");
                capture.overflow = false;
            }

            sample_count = 0;
        }

        // NO DELAY - run as fast as possible to catch 575kHz signals
        // The Pico runs at 125MHz by default, should easily keep up
    }

    return 0;
}
