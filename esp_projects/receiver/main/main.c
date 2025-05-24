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

void app_main(void) {

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

    spi_device_interface_config_t deviceConfig = {
        .command_bits = 0,
        .address_bits = 0,
        .dummy_bits = 0,
        .clock_speed_hz = 50000000U,
        .duty_cycle_pos = 128, // 50%
        .mode = 0,
        .spics_io_num = GPIO_CS,
        .cs_ena_posttrans = 3, // @see https://github.com/espressif/esp-idf/blob/27d68f57e6bdd3842cd263585c2c352698a9eda2/examples/peripherals/spi_slave/sender/main/app_main.c#L95
        .queue_size = 3
    };

    gpio_config_t handshakeConfig = {
        .intr_type = GPIO_INTR_POSEDGE,
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = 1,
        .pin_bit_mask = BIT64(GPIO_HANDSHAKE)
    };

    rdySem = xSemaphoreCreateBinary();

    gpio_config(&handshakeConfig);
    gpio_install_isr_service(0);
    gpio_set_intr_type(GPIO_HANDSHAKE, GPIO_INTR_POSEDGE);
    gpio_isr_handler_add(GPIO_HANDSHAKE, vHandshakeHandler, NULL);

    errorStatus = spi_bus_initialize(SENDER_HOST, &busConfig, SPI_DMA_CH_AUTO);
    assert(errorStatus == ESP_OK);
    errorStatus = spi_bus_add_device(SENDER_HOST, &deviceConfig, &spiDeviceHandle);
    assert(errorStatus == ESP_OK);

    xSemaphoreGive(rdySem);

    // SPI */ 
}
