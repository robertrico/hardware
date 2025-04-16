#include "driver/gpio.h"
#include "esp_now.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include <string>
#include <cstring>

#define LED_GPIO GPIO_NUM_20  // D7
#define ESPNOW_CHANNEL 1

static const char* TAG = "RX";

void rx_cb(const esp_now_recv_info_t* info, const uint8_t* data, int len) {

    std::string payload(reinterpret_cast<const char*>(data), strnlen((const char*)data, len));
    ESP_LOGI(TAG, "Payload: %s", payload.c_str());
    if (payload == "LIGHT_ON") {
        gpio_set_level(LED_GPIO, 1);
        ESP_LOGI(TAG, "LED turned ON");
        vTaskDelay(pdMS_TO_TICKS(120));
        gpio_set_level(LED_GPIO, 0);
        ESP_LOGI(TAG, "LED turned OFF");
    } else {
        ESP_LOGI(TAG, "Unknown Payload: %s", payload.c_str());
    }
}

extern "C" void app_main() {
    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));

    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(rx_cb));

    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    ESP_LOGI("RX", "My MAC: %02X:%02X:%02X:%02X:%02X:%02X",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    gpio_config_t io_conf = {};
    io_conf.pin_bit_mask = 1ULL << LED_GPIO;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.intr_type = GPIO_INTR_DISABLE;
    
    gpio_config(&io_conf);
}
