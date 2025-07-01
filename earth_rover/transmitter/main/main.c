#include "driver/gpio.h"
#include "esp_now.h"
#include "esp_rom_sys.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "esp_netif.h"
#include "esp_event.h"
#include "esp_wifi.h"
#include "esp_adc/adc_oneshot.h"
#include "esp_adc/adc_cali_scheme.h"

#define ESPNOW_CHANNEL 1

#define ADC_A ADC_CHANNEL_4  // GPIO4
#define ADC_B ADC_CHANNEL_3  // GPIO3
#define ADC_C ADC_CHANNEL_2  // GPIO2

#define C_SELECT_GPIO GPIO_NUM_6 
#define B_SELECT_GPIO GPIO_NUM_7 

static const char* TAG = "TX";

static void send_cb(const wifi_tx_info_t* /*info*/, esp_now_send_status_t status) {
    ESP_LOGI(TAG, "Send callback. Status: %s", status == ESP_NOW_SEND_SUCCESS ? "Success" : "Fail");
}

static void vWifiInit(void) {
    ESP_ERROR_CHECK(nvs_flash_init());
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_ERROR_CHECK(esp_wifi_set_channel(ESPNOW_CHANNEL, WIFI_SECOND_CHAN_NONE));
}

static void vESPNowInit(void) {
    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_send_cb(send_cb));
}

static void vPeerInit(esp_now_peer_info_t *peerInfo) {
    memset(peerInfo, 0, sizeof(*peerInfo));
    uint8_t peer_addr[6] = {0xA0, 0x85, 0xE3, 0x0D, 0x72, 0x68};  // Replace with actual MAC
    memcpy(peerInfo->peer_addr, peer_addr, 6);

    peerInfo->channel = ESPNOW_CHANNEL;
    peerInfo->ifidx = WIFI_IF_STA;
    peerInfo->encrypt = false;

    ESP_ERROR_CHECK(esp_now_add_peer(peerInfo));
}

void app_main(void) {
    vWifiInit();
    vESPNowInit();
    
    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);

    esp_now_peer_info_t peerInfo;
    vPeerInit(&peerInfo);

    gpio_config_t b_select_gpio_conf;
    memset(&b_select_gpio_conf, 0, sizeof(b_select_gpio_conf));
    b_select_gpio_conf.intr_type = GPIO_INTR_DISABLE;
    b_select_gpio_conf.mode = GPIO_MODE_OUTPUT;
    b_select_gpio_conf.pin_bit_mask = 1ULL << B_SELECT_GPIO;
    b_select_gpio_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&b_select_gpio_conf);

    // Setup ADC oneshot driver
    adc_oneshot_unit_handle_t adc_handle;
    adc_oneshot_unit_init_cfg_t init_cfg = {
        .unit_id = ADC_UNIT_1
    };
    adc_oneshot_new_unit(&init_cfg, &adc_handle);

    adc_oneshot_chan_cfg_t chan_cfg = {
        .bitwidth = ADC_BITWIDTH_DEFAULT,   // Default 12-bit
        .atten = ADC_ATTEN_DB_12           // for 0-3.3V input
    };
    adc_oneshot_config_channel(adc_handle, ADC_B, &chan_cfg);

    // Set High for First Read
    gpio_set_level(B_SELECT_GPIO, 1);

    while (1) {
        uint16_t val = 0x0000;
        int deadband = 0;
        esp_err_t result;

        adc_oneshot_read(adc_handle, ADC_B, (int*)&val);
        gpio_set_level(B_SELECT_GPIO, 0);
        esp_rom_delay_us(10);

        if (val > 2400 || val < 2000) {
            deadband++;
        }
        uint8_t adc_by_high = (val >> 8) & 0x0F;
        uint8_t adc_by_low = val & 0xFF;

        adc_oneshot_read(adc_handle, ADC_B, (int*)&val);
        gpio_set_level(B_SELECT_GPIO, 1);
        esp_rom_delay_us(10);

        if (val > 2400 || val < 2000) {
            deadband++;
        }

        uint8_t adc_bx_high = (val >> 8) & 0x0F;
        uint8_t adc_bx_low = val & 0xFF;

        uint8_t payload[16] = {adc_bx_low, adc_bx_high, adc_by_low, adc_by_high};

        if (deadband > 0) {
            result = esp_now_send(peerInfo.peer_addr, payload, sizeof(payload));
            if (result == ESP_OK) {
                ESP_LOGI(TAG, "Sent successfully");
                ESP_LOGI(TAG, "Payload: %02X %02X %02X %02X", 
                         payload[0], payload[1], payload[2], payload[3]);
            } else {
                ESP_LOGE(TAG, "Send failed: %s", esp_err_to_name(result));
            }
        }

        vTaskDelay(pdMS_TO_TICKS(100));
    }
}