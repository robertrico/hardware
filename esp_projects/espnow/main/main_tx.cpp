#include "driver/gpio.h"
#include "esp_now.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_wifi.h"
#include <cstring>

#define BUTTON_GPIO GPIO_NUM_3  // D1
#define ESPNOW_CHANNEL 1

static const char* TAG = "RX";

extern "C" void app_main() {
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    ESP_ERROR_CHECK(nvs_flash_init());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));

    ESP_ERROR_CHECK(esp_now_init());

    ESP_ERROR_CHECK(esp_now_register_send_cb([](const wifi_tx_info_t* /*info*/, esp_now_send_status_t status) {
        ESP_LOGI(TAG, "Send callback. Status: %s", status == ESP_NOW_SEND_SUCCESS ? "Success" : "Fail");
    }));

    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);
    ESP_LOGI("TX", "My MAC: %02X:%02X:%02X:%02X:%02X:%02X",
            mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);

    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, (uint8_t[]){0xA0, 0x85, 0xE3, 0x0D, 0x72, 0x68}, 6);  // Replace with actual MAC

    peerInfo.channel = ESPNOW_CHANNEL;
    peerInfo.ifidx = WIFI_IF_STA;
    peerInfo.encrypt = false;

    ESP_ERROR_CHECK(esp_now_add_peer(&peerInfo));

    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_INPUT;
    io_conf.pin_bit_mask = 1ULL << BUTTON_GPIO;
    io_conf.pull_up_en = GPIO_PULLUP_ENABLE;
    gpio_config(&io_conf);

    uint8_t data[] = "LIGHT_ON";

    while (true) {
        if (gpio_get_level(BUTTON_GPIO) == 0) {
            ESP_LOGI(TAG, "Button pressed. Sending...");
            esp_err_t result = esp_now_send(peerInfo.peer_addr, data, sizeof(data));
            if (result == ESP_OK) {
                ESP_LOGI(TAG, "Sent successfully");
            } else {
                ESP_LOGE(TAG, "Send failed: %s", esp_err_to_name(result));
            }

            // debounce
            vTaskDelay(pdMS_TO_TICKS(500));
        }

        vTaskDelay(pdMS_TO_TICKS(10));
    }
}