#include "pico/stdlib.h"

// LED GPIO pins
#define LED_BLU 18
#define LED_WHT 19

// Blink an LED `count` times
static void blink_led(uint gpio, int count, int delay_ms = 100) {
    for (int i = 0; i < count; ++i) {
        gpio_put(gpio, 1);
        sleep_ms(delay_ms);
        gpio_put(gpio, 0);
        sleep_ms(delay_ms);
    }
}

int main() {
    __asm volatile ("bkpt #43");

    gpio_init(LED_BLU);
    gpio_init(LED_WHT);
    gpio_set_dir(LED_BLU, GPIO_OUT);
    gpio_set_dir(LED_WHT, GPIO_OUT);

    while (true) {
        blink_led(LED_BLU, 10);
        blink_led(LED_WHT, 10);

        for (int i = 0; i < 10; ++i) {
            gpio_put(LED_BLU, 1);
            gpio_put(LED_WHT, 1);
            sleep_ms(100);
            gpio_put(LED_BLU, 0);
            gpio_put(LED_WHT, 0);
            sleep_ms(100);
        }
    }

    return 0;
}
