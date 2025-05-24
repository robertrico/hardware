#include "include.h"
#include "interrupts.h"

void vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
    char payload[33]; // Adjust size as needed
    int copy_len = (len < (int)sizeof(payload) - 1) ? len : (int)sizeof(payload) - 1;
    memcpy(payload, data, copy_len);
    payload[copy_len] = '\0';

    ESP_LOGI("RX", "Payload: %s", payload);
    if (strcmp(payload, "LIGHT_ON") == 0) {
        gpio_set_level(LED_GPIO, 1);
        ESP_LOGI("RX", "LED turned ON");
        vTaskDelay(pdMS_TO_TICKS(120));
        gpio_set_level(LED_GPIO, 0);
        ESP_LOGI("RX", "LED turned OFF");
    } else {
        ESP_LOGI("RX", "Unknown Payload: %s", payload);
    }
}