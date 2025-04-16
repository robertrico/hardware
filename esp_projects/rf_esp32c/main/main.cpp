#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"

#define LED_GPIO    GPIO_NUM_20  // D9
#define BUTTON_GPIO GPIO_NUM_4   // D1

extern "C" void app_main() {
    ESP_LOGI("INIT", "Configuring GPIOs");

    // Set up LED
    gpio_reset_pin(LED_GPIO);
    gpio_set_direction(LED_GPIO, GPIO_MODE_OUTPUT);

    // Set up button with internal pull-up
    gpio_reset_pin(BUTTON_GPIO);
    gpio_set_direction(BUTTON_GPIO, GPIO_MODE_INPUT);
    gpio_pullup_en(BUTTON_GPIO);
    gpio_pulldown_dis(BUTTON_GPIO);

    ESP_LOGI("INIT", "Button -> LED loop begins");

    while (true) {
        int pressed = !gpio_get_level(BUTTON_GPIO);  // Inverted: pressed = 1
        gpio_set_level(LED_GPIO, pressed);
        ESP_LOGI("STATE", "Button: %s", pressed ? "PRESSED" : "released");
        vTaskDelay(pdMS_TO_TICKS(50));
    }
}
