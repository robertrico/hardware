#include "include.h"
#include "interrupts.h"

void vToggleLED(uint8_t payload) {
    ESP_LOGI("RX", "Payload: %d", payload);
}

void vSendSPI(char* payload) {
    esp_err_t errorStatus;
    static int interruptCount = 0;
    char sendBuffer[16] = {0};
    char receiveBuffer[16] = {0};
    spi_transaction_t spiTransaction;
    memset(&spiTransaction,0,sizeof(spiTransaction));

    int res = snprintf(
        sendBuffer,
        sizeof(sendBuffer),
        payload,
        interruptCount,
        receiveBuffer
    );
    ESP_LOGI("RX", "Sending: %d %s", ++interruptCount, sendBuffer);

    if (res >= sizeof(sendBuffer)) {
        ESP_LOGI("RX", "Data truncated");
    }

    spiTransaction.length = sizeof(sendBuffer) * 8;
    spiTransaction.tx_buffer = sendBuffer;
    spiTransaction.rx_buffer = receiveBuffer;

    ESP_LOGI("RX", "After Semaphore");
    errorStatus = spi_device_transmit(spiDeviceHandle, &spiTransaction);
    ESP_LOGI("RX", "Received: %d %d", interruptCount, receiveBuffer);
    if (interruptCount % 2 == 0) {
        gpio_set_level(GPIO_NUM_7, 1); // BLU OFF
    } else {
        gpio_set_level(GPIO_NUM_6, 1); // YLW ON
    }
    gpio_set_level(GPIO_NUM_7, 0);
    gpio_set_level(GPIO_NUM_6, 0);
}

void IRAM_ATTR vButtonReceive(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
    uint8_t payload[16]; // Adjust size as needed
    int copy_len = (len < (int)sizeof(payload) - 1) ? len : (int)sizeof(payload) - 1;
    memcpy(payload, data, copy_len);
    payload[copy_len] = '\0';

    ESP_LOGI("RX", "Received payload: %d", payload);
    BaseType_t xHigherPriorityTaskWoken = pdFALSE;
    xQueueSendFromISR(rdySem, &payload, &xHigherPriorityTaskWoken);
}
