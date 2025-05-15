#include "pico/stdlib.h"
#include "firmware.h"
#include "pico/stdlib.h"
#include "hardware/clocks.h"

#define LED_PIN 18
#define LED_PIN2 19

int main() {
    // Initialize the LED pin
    gpio_init(LED_PIN);
    gpio_init(LED_PIN2);
    gpio_set_dir(LED_PIN, GPIO_OUT);
    gpio_set_dir(LED_PIN2, GPIO_OUT);

    while (true) {
        for (int i = 0; i < 3; i++) {
            gpio_put(LED_PIN, 1);  // Turn LED1 on
            gpio_put(LED_PIN2, 0); // Turn LED2 off
            sleep_ms(200);         // Wait 200ms
            gpio_put(LED_PIN, 0);  // Turn LED1 off
            gpio_put(LED_PIN2, 1); // Turn LED2 on
            sleep_ms(200);         // Wait 200ms
        }

        sleep_ms(500); // Pause before next dance cycle

        for (int i = 0; i < 4; i++) {
            gpio_put(LED_PIN, 1);  // Turn LED1 on
            gpio_put(LED_PIN2, 1); // Turn LED2 on
            sleep_ms(150);         // Wait 150ms
            gpio_put(LED_PIN, 0);  // Turn LED1 off
            gpio_put(LED_PIN2, 0); // Turn LED2 off
            sleep_ms(150);         // Wait 150ms
        }

        sleep_ms(500); // Pause before repeating the dance
    }

    return 0;
}