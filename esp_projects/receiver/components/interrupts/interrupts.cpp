#include "include.h"
#include "interrupts.h"
#include <string>

void vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {

    std::string payload(reinterpret_cast<const char*>(data), strnlen((const char*)data, len));
    ESP_LOGI("RX", "Payload: %s", payload.c_str());
    if (payload == "LIGHT_ON") {
        gpio_set_level(LED_GPIO, 1);
        ESP_LOGI("RX", "LED turned ON");
        vTaskDelay(pdMS_TO_TICKS(120));
        gpio_set_level(LED_GPIO, 0);
        ESP_LOGI("RX", "LED turned OFF");
    } else {
        ESP_LOGI("RX", "Unknown Payload: %s", payload.c_str());
    }
}