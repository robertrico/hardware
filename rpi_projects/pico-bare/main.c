#include "pico/stdlib.h"

int main() {
    const uint32_t LED_PIN = 16; // GPIO pin 16

    // Initialize GPIO pin 16
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);

    while (true) {
        gpio_put(LED_PIN, 1); // Turn LED on
        sleep_ms(500);        // Delay for 500ms
        gpio_put(LED_PIN, 0); // Turn LED off
        sleep_ms(500);        // Delay for 500ms
    }

    return 0;
}