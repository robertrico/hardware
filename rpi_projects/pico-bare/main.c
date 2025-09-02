#include <stdio.h>
#include "pico/stdlib.h"

#define LED_PIN 25  // GPIO25 is the onboard LED on regular Pico (not Pico W)

int main() {
    // Initialize stdio for USB serial output
    stdio_init_all();
    
    // Initialize GPIO for LED
    gpio_init(LED_PIN);
    gpio_set_dir(LED_PIN, GPIO_OUT);
    
    // Wait a bit for USB serial to connect (optional but helpful for debugging)
    sleep_ms(2000);
    
    printf("Hello, World from Pico!\n");
    printf("Starting LED blink on GPIO %d...\n", LED_PIN);
    
    while (true) {
        // Turn on LED
        gpio_put(LED_PIN, 1);
        printf("LED ON\n");
        sleep_ms(500);
        
        // Turn off LED
        gpio_put(LED_PIN, 0);
        printf("LED OFF\n");
        sleep_ms(500);
    }
    
    return 0;
}