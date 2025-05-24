#include "include.h"
#include "interrupts.h"

static void vToggleLED(char* payload) {
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

static void vSendSPI(char* payload) {
    esp_err_t errorStatus;

    static int interruptCount = 0;
    char sendBuffer[128] = {0};
    char receiveBuffer[128] = {0};
    spi_transaction_t spiTransaction;
    memset(&spiTransaction,0,sizeof(spiTransaction));

    int res = snprintf(
        sendBuffer,
        sizeof(sendBuffer),
        payload,
        interruptCount,
        receiveBuffer
    );

    if (res >= sizeof(sendBuffer)) {
        printf("Data truncated\n");
    }

    spiTransaction.length = sizeof(sendBuffer) * 8;
    spiTransaction.tx_buffer = sendBuffer;
    spiTransaction.rx_buffer = receiveBuffer;

    xSemaphoreTake(rdySem, portMAX_DELAY);
    errorStatus = spi_device_transmit(spiDeviceHandle, &spiTransaction);
    printf("Received: %d %s\n", ++interruptCount,receiveBuffer);
}

void IRAM_ATTR vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
    char payload[33]; // Adjust size as needed
    int copy_len = (len < (int)sizeof(payload) - 1) ? len : (int)sizeof(payload) - 1;
    memcpy(payload, data, copy_len);
    payload[copy_len] = '\0';
    vToggleLED(payload);
    vSendSPI(payload);
}

void IRAM_ATTR vHandshakeHandler(void* arg) {
    static uint32_t lastHandshakeTimeUS;
    uint32_t currentTimeUS = esp_timer_get_time();
    uint32_t timeDiff = currentTimeUS - lastHandshakeTimeUS;
    if (timeDiff < 1000U) {
        // @see https://github.com/espressif/esp-idf/blob/27d68f57e6bdd3842cd263585c2c352698a9eda2/examples/peripherals/spi_slave/sender/main/app_main.c#L53
        return;
    }

    lastHandshakeTimeUS = currentTimeUS;

    BaseType_t mustYield = false;
    xSemaphoreGiveFromISR(rdySem, &mustYield);
    if (mustYield) {
        portYIELD_FROM_ISR();
    }
}