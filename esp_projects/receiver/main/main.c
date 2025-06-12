#include "include.h"
#include "interrupts.h"

/**
 * @brief Initializes Wi-Fi in station mode and sets the Wi-Fi channel for ESP-NOW communication.
 *
 * This function performs the following steps:
 * - Initializes NVS flash storage.
 * - Initializes the TCP/IP network interface.
 * - Creates the default event loop.
 * - Initializes the Wi-Fi driver with default configuration.
 * - Sets the Wi-Fi mode to station (STA).
 * - Starts the Wi-Fi driver.
 * - Sets the Wi-Fi channel to the value defined by ESPNOW_CHANNEL with no secondary channel.
 *
 * All steps use ESP_ERROR_CHECK to ensure proper error handling.
 */

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

/**
 * @brief Initializes ESP-NOW and registers the receive callback.
 *
 * This function performs the following steps:
 * - Initializes the ESP-NOW protocol stack.
 * - Registers the vButtonReceive function as the callback for receiving ESP-NOW data.
 *
 * Both steps use ESP_ERROR_CHECK to ensure proper error handling.
 */
static void vESPNowInit(void) {
    ESP_ERROR_CHECK(esp_now_init());
    ESP_ERROR_CHECK(esp_now_register_recv_cb(vButtonReceive));
}

#define EVENT_QUEUE_LENGTH 16
#define EVENT_ITEM_SIZE    16

QueueHandle_t rdySem = NULL; // This is the only definition
spi_device_handle_t spiDeviceHandle = NULL;

void app_main(void) {
    rdySem = xQueueCreate(EVENT_QUEUE_LENGTH, EVENT_ITEM_SIZE);

    vWifiInit();
    vESPNowInit();

    uint8_t mac[6];
    esp_wifi_get_mac(WIFI_IF_STA, mac);

    // @TODO - Make Component
    // Button Driven LED
    gpio_config_t io_conf;
    io_conf.pin_bit_mask = 1ULL << LED_GPIO;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.intr_type = GPIO_INTR_DISABLE;

    gpio_config(&io_conf);
    // Button Driven LED

    // SPI /*
    esp_err_t errorStatus;

    spi_bus_config_t busConfig = {
        .mosi_io_num = GPIO_MOSI,
        .miso_io_num = GPIO_MISO,
        .sclk_io_num = GPIO_SCLK,
        .quadwp_io_num = -1,
        .quadhd_io_num = -1
    };

    spi_device_interface_config_t deviceConfig;

    memset(&deviceConfig, 0, sizeof(deviceConfig));
    deviceConfig.command_bits = 0;
    deviceConfig.address_bits = 0;
    deviceConfig.dummy_bits = 0;
    deviceConfig.clock_speed_hz = 1000000;
    deviceConfig.duty_cycle_pos = 128; // 50%
    deviceConfig.mode = 0;
    deviceConfig.spics_io_num = GPIO_CS;
    deviceConfig.cs_ena_posttrans = 3;
    deviceConfig.queue_size = 16;

    errorStatus = spi_bus_initialize(SENDER_HOST, &busConfig, SPI_DMA_CH_AUTO);
    assert(errorStatus == ESP_OK);
    errorStatus = spi_bus_add_device(SENDER_HOST, &deviceConfig, &spiDeviceHandle);
    assert(errorStatus == ESP_OK);

    while(1) {
        char payload[16]; // Adjust size as needed
        if (xQueueReceive(rdySem, payload, portMAX_DELAY)) {
            uint16_t bx = payload[0] | (payload[1] << 8);
            uint16_t by = payload[2] | (payload[3] << 8);
            uint16_t bx_be = (bx >> 8) | ((bx & 0xFF) << 8);
            uint16_t by_be = (by >> 8) | ((by & 0xFF) << 8);
            ESP_LOGI("Payload - BY", "Received payload (big-endian): %d", by_be);
            ESP_LOGI("Payload - BX", "Received payload (big-endian): %d", bx_be);
            vSendSPI(bx, by);
        }
    }

    // SPI */ 
}
