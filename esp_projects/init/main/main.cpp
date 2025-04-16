#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"

#define LED_PIN GPIO_NUM_3 // D3 pin

extern "C" void app_main() {
    // Configure the LED pin as output
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << LED_PIN);
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&io_conf);

    // Turn the LED on
    gpio_set_level(LED_PIN, 1);

    // Keep the task running indefinitely
    while (true) {
        vTaskDelay(pdMS_TO_TICKS(1000)); // Delay to prevent watchdog timer reset
    }
}