
#include "include/bootloader.h"

#define LED_GRN 14
#define LED_RED 15
#define LED_YLW 16
#define LED_PIN 19 // Onboard LED pin for Raspberry Pi Pico
#define LED_PIN2 18 // Onboard LED pin for Raspberry Pi Pico

__attribute__((section(".boot_config")))
__attribute__((used))
const BootConfig boot_config_flash = {
        .mode = "BOOT",
        .version = "1.0.0",
        .padding = {0},
    };

int main() {
    // Initialize the LED pin
    stdio_init_all();
    // Warm up pico-sdk
    printf("Warming up...\n");
    sleep_ms(2000);
    

    gpio_init(LED_PIN);
    gpio_init(LED_PIN2);
    gpio_set_dir(LED_PIN, GPIO_OUT);
    gpio_set_dir(LED_PIN2, GPIO_OUT);

    gpio_init(LED_GRN);
    gpio_init(LED_RED);
    gpio_init(LED_YLW);
    gpio_set_dir(LED_GRN, GPIO_OUT);
    gpio_set_dir(LED_RED, GPIO_OUT);
    gpio_set_dir(LED_YLW, GPIO_OUT);


    gpio_put(LED_RED, 1); // Turn on red LED to indicate Wi-Fi connection attempt

    WiFiManager::init(); // Initialize Wi-Fi

    if (WiFiManager::connect())
    {
        printf("Wi-Fi connected!\n");
        gpio_put(LED_GRN, 1); // Turn on green LED to indicate successful connection
        gpio_put(LED_RED, 0); // Turn on red LED to indicate Wi-Fi connection attempt
        gpio_put(LED_YLW, 0); // Turn on red LED to indicate Wi-Fi connection attempt
    }
    else
    {
        printf("Wi-Fi connection failed!\n");
        for (int i = 0; i < 10; i++) {
            gpio_put(LED_YLW, 1); // Turn on yellow LED
            sleep_ms(250);
            gpio_put(LED_YLW, 0); // Turn off yellow LED
            sleep_ms(250);
        }
        return 1;
    }

    OTAManager::checkForUpdate(); // Check for OTA update

    while (true) {
        // Fun LED "dance" with two LEDs
        for (int i = 0; i < 3; i++) {
            gpio_put(LED_PIN, 1); gpio_put(LED_PIN2, 0); sleep_ms(100);
            gpio_put(LED_PIN, 0); gpio_put(LED_PIN2, 1); sleep_ms(100); // Alternate fast blink
        }
        gpio_put(LED_PIN, 1); gpio_put(LED_PIN2, 1); sleep_ms(500);
        gpio_put(LED_PIN, 0); gpio_put(LED_PIN2, 0); sleep_ms(500); // Both LEDs long blink
        for (int i = 0; i < 2; i++) {
            gpio_put(LED_PIN, 1); gpio_put(LED_PIN2, 0); sleep_ms(200);
            gpio_put(LED_PIN, 0); gpio_put(LED_PIN2, 1); sleep_ms(200); // Alternate medium blink
        }
        gpio_put(LED_PIN, 1); gpio_put(LED_PIN2, 1); sleep_ms(1000);
        gpio_put(LED_PIN, 0); gpio_put(LED_PIN2, 0); sleep_ms(1000); // Both LEDs very long blink
    }

    return 0;
}